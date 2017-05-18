#!/usr/bin/env stack
{- stack
  script
  --resolver lts-8.14
  --package aeson
  --package ansi-terminal
  --package directory
  --package foldl
  --package managed
  --package mtl
  --package process
  --package stache
  --package system-filepath
  --package text
  --package time
  --package transformers
  --package turtle
-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TupleSections #-}

import Control.Applicative ((<|>), empty, optional)
import Control.Exception (bracket_, throwIO)
import qualified Control.Foldl as Foldl
import Control.Monad (filterM, guard, mfilter, unless, void, when)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Managed (runManaged)
import Control.Monad.Reader (MonadReader, ask, asks, runReaderT)
import Control.Monad.Trans.Maybe (MaybeT(..), runMaybeT)
import Data.Aeson ((.=), object)
import Data.Foldable (forM_)
import Data.Functor (($>))
import Data.Maybe (isJust, isNothing, listToMaybe)
import Data.Monoid ((<>))
import qualified Data.Text
import Data.Text (Text)
import qualified Data.Text.IO
import Data.Text.Lazy (toStrict)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Data.Time.LocalTime (utcToLocalZonedTime)
import Filesystem.Path.CurrentOS (FilePath, (</>))
import qualified Filesystem.Path.CurrentOS as FS
import Prelude hiding (FilePath)
import qualified System.Console.ANSI as ANSI
import qualified System.Directory
import qualified System.Exit
import qualified System.IO
import System.IO.Error
       (catchIOError, isDoesNotExistError, isPermissionError)
import System.Info (os)
import qualified System.Process
import Text.Mustache (Template, renderMustache)
import Text.Mustache.Compile.TH (mustache)
import Turtle ((.||.))
import qualified Turtle

data HvnConfig = HvnConfig
  { hvnCfgBasic :: Bool
  , hvnCfgRepo :: Text
  , hvnCfgBranch :: Text
  , hvnCfgHome :: FilePath
  , hvnCfgDest :: FilePath
  , hvnCfgHoogleDb :: Bool
  } deriving (Show)

data HvnArgs = HvnArgs
  { hvnArgsBasic :: Bool
  , hvnArgsRepo :: Maybe Text
  , hvnArgsBranch :: Maybe Text
  , hvnArgsNoHoogleDb :: Bool
  } deriving (Show)

data HvnPackageManager
  = HvnPackageManager'Brew
  | HvnPackageManager'Dnf
  | HvnPackageManager'Yum
  | HvnPackageManager'Apt
  | HvnPackageManager'Port
  | HvnPackageManager'Chocolatey
  | HvnPackageManager'Other
  deriving (Show)

defaultRepo :: Text
defaultRepo = "https://github.com/jship/haskell-vim-now.git"

defaultBranch :: Text
defaultBranch = "HASKELLIFY" -- TODO change to master

cliParser :: Turtle.Parser HvnArgs
cliParser =
  HvnArgs <$>
  Turtle.switch
    "basic"
    'b'
    "Install only vim and plugins without haskell components." <*>
  optional
    (Turtle.optText
       "repo"
       'r'
       (pure . Turtle.HelpMessage $
        "Git repository to install from. The default is " <> defaultRepo <> ".")) <*>
  optional
    (Turtle.optText
       "target-branch"
       't'
       (pure . Turtle.HelpMessage $
        "Git branch to install from. The default is " <> defaultBranch <> ".")) <*>
  Turtle.switch "no-hoogle" 'g' "Disable Hoogle database generation."

consoleLog :: (MonadIO m) => System.IO.Handle -> [ANSI.SGR] -> Text -> m ()
consoleLog handle sgrs txt =
  liftIO $
  bracket_
    (ANSI.setSGR [ANSI.Reset] *> ANSI.setSGR sgrs)
    (ANSI.setSGR [ANSI.Reset])
    (Data.Text.IO.hPutStrLn handle txt)

msg :: (MonadIO m) => Text -> m ()
msg =
  consoleLog
    System.IO.stdout
    [ ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Green
    , ANSI.SetConsoleIntensity ANSI.NormalIntensity
    ]

warn :: (MonadIO m) => Text -> m ()
warn =
  consoleLog
    System.IO.stdout
    [ ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Yellow
    , ANSI.SetConsoleIntensity ANSI.BoldIntensity
    ]

err :: (MonadIO m) => Text -> m ()
err =
  consoleLog
    System.IO.stderr
    [ ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Red
    , ANSI.SetConsoleIntensity ANSI.BoldIntensity
    ]

detail :: (MonadIO m) => Text -> m ()
detail =
  consoleLog System.IO.stdout [ANSI.SetConsoleIntensity ANSI.BoldIntensity] .
  ("    " <>)

-- a.k.a. $(...)
commandSubstitution :: (MonadIO m) => Text -> m Text
commandSubstitution cmd = do
  mval <- Turtle.fold (Turtle.inshell cmd empty) Foldl.head
  pure $ maybe mempty Turtle.lineToText mval

packageManager :: (MonadIO m) => m HvnPackageManager
packageManager = do
  mPkgMgrPath <-
    runMaybeT $
    MaybeT (Turtle.which "brew") $> HvnPackageManager'Brew <|>
    MaybeT (Turtle.which "dnf") $> HvnPackageManager'Dnf <|>
    MaybeT (Turtle.which "yum") $> HvnPackageManager'Yum <|>
    MaybeT (Turtle.which "apt-get") $> HvnPackageManager'Apt <|>
    MaybeT (Turtle.which "port") $> HvnPackageManager'Port <|>
    MaybeT (Turtle.which "choco.exe") $> HvnPackageManager'Chocolatey
  maybe (pure HvnPackageManager'Other) pure mPkgMgrPath

rawPackageInstall :: (MonadIO m) => Text -> Text -> [Text] -> m Turtle.ExitCode
rawPackageInstall cmdName cmd pkgs = do
  msg $ "Installing with '" <> cmdName <> "'..."
  Turtle.shell (cmd <> " " <> Data.Text.unwords pkgs) empty .||.
    Turtle.exit (Turtle.ExitFailure 1)

packageInstall ::
     (MonadIO m) => HvnPackageManager -> [Text] -> m Turtle.ExitCode
packageInstall HvnPackageManager'Brew = rawPackageInstall "Brew" "brew install"
packageInstall HvnPackageManager'Dnf =
  rawPackageInstall "DNF" "sudo dnf install -yq"
packageInstall HvnPackageManager'Yum =
  rawPackageInstall "Yum" "sudo yum install -yq"
packageInstall HvnPackageManager'Apt =
  rawPackageInstall "Apt" "sudo apt-get install --no-upgrade -y"
packageInstall HvnPackageManager'Port = rawPackageInstall "Port" "port install"
packageInstall HvnPackageManager'Chocolatey =
  rawPackageInstall "Chocolatey" "choco install -y"
packageInstall HvnPackageManager'Other
  -- TODO Error message
 = const $ Turtle.exit (Turtle.ExitFailure 1)

missingPackages :: (MonadIO m) => [(FilePath, Text)] -> m [Text]
missingPackages cmdPkgs =
  map snd <$>
  (flip filterM cmdPkgs $ \(cmd, _) -> do
     mPkgPath <-
       runMaybeT $
       MaybeT (Turtle.which (FS.addExtension cmd "exe")) <|>
       MaybeT (Turtle.which cmd)
     return . isNothing $ mPkgPath)

packageList :: (MonadIO m) => HvnPackageManager -> m [Text]
packageList HvnPackageManager'Brew =
  missingPackages
    [("make", "homebrew/dupes/make"), ("ctags", "ctags"), ("par", "par")]
packageList HvnPackageManager'Dnf =
  missingPackages
    [ ("make", "make")
    , ("ctags", "ctags")
    , ("libcurl-devel", "libcurl-devel")
    , ("zlib-devel", "zlib-devel")
    , ("powerline", "powerline")
    ]
packageList HvnPackageManager'Yum =
  missingPackages
    [ ("make", "make")
    , ("ctags", "ctags")
    , ("libcurl-devel", "libcurl-devel")
    , ("zlib-devel", "zlib-devel")
    , ("powerline", "powerline")
    ]
packageList HvnPackageManager'Apt =
  missingPackages
    [ ("make", "make")
    , ("ctags", "exuberant-ctags")
    , ("par", "par")
    , ("curl", "curl")
    , ("libcurl4-openssl-dev", "libcurl4-openssl-dev")
    ]
packageList HvnPackageManager'Port =
  missingPackages [("make", "make"), ("ctags", "ctags"), ("par", "par")]
packageList HvnPackageManager'Chocolatey =
  missingPackages
    -- TODO Hacky way of installing x86 mingw
    [ ("mingw32-make", "mingw --x86")
    , ("make", "make")
    , ("ctags", "ctags")
    , ("curl", "curl")
    ] -- TODO Chocolatey does not have a 'par' package
packageList HvnPackageManager'Other
  -- TODO Do not use undefined!  Hack for now...
 = undefined

filePathToText :: FilePath -> Text
filePathToText = Turtle.format Turtle.fp

textToFilePath :: Text -> FilePath
textToFilePath = FS.fromText

hvnHomeDir :: (MonadIO m) => m FilePath
hvnHomeDir = do
  mXdgConfigHome <- Turtle.need "XDG_CONFIG_HOME"
  maybe
    (fmap ((</> ".config")) Turtle.home)
    (pure . textToFilePath)
    mXdgConfigHome

checkRepoChange :: (MonadIO m, MonadReader HvnConfig m) => m ()
checkRepoChange = do
  HvnConfig {..} <- ask
  Turtle.cd hvnCfgDest
  originRepo <- commandSubstitution "git config --get remote.origin.url"
  when (hvnCfgRepo /= originRepo) $ do
    err $ "The source repository path [" <> hvnCfgRepo <> "] does not match the"
    err $
      "origin repository of the existing installation [" <> originRepo <> "]."
    err $
      "Please remove the existing installation [" <> filePathToText hvnCfgDest <>
      "] and try again."
    Turtle.exit (Turtle.ExitFailure 1)

updatePull :: (MonadIO m, MonadReader HvnConfig m) => m Turtle.ExitCode
updatePull = do
  HvnConfig {..} <- ask
  Turtle.cd hvnCfgDest
  shortStatus <- commandSubstitution "git status -s"
  unless (Data.Text.null shortStatus) $
    -- Local repo has changes, prompt before overwriting them
   do
    warn
      "Would you like to force a sync? THIS WILL REMOVE ANY LOCAL CHANGES!  [y/N]: "
    void . runMaybeT $ do
      choice <- Data.Text.toLower . Turtle.lineToText <$> MaybeT Turtle.readline
      when (choice == "y" || choice == "yes") $
        void $
        Turtle.shell "git reset --hard" empty .||.
        Turtle.exit (Turtle.ExitFailure 1)
  Turtle.shell "git pull --rebase" empty

install :: (MonadIO m, MonadReader HvnConfig m) => m ()
install = do
  HvnConfig {..} <- ask
  msg $ "Config: " <> (Data.Text.pack . show $ HvnConfig {..})
  destDirExists <- Turtle.testdir hvnCfgDest
  when destDirExists $
    warn $
    "Existing Haskell-Vim-Now installation detected at " <>
    filePathToText hvnCfgDest <>
    "."
  oldInstallExists <- Turtle.testdir (hvnCfgHome </> ".haskell-vim-now")
  when oldInstallExists $ do
    warn "Old Haskell-Vim-Now installation detected."
    msg $
      "Migrating existing installation to " <> filePathToText hvnCfgDest <>
      "..."
    Turtle.mv (hvnCfgHome </> ".haskell-vim-now") hvnCfgDest
    Turtle.mv (hvnCfgHome </> ".vimrc.local") (hvnCfgDest </> ".vimrc.local")
    Turtle.mv
      (hvnCfgHome </> ".vimrc.local.pre")
      (hvnCfgDest </> ".vimrc.local.pre")
    Turtle.inplace
      ("Plgin '" *> pure "Plug '")
      (hvnCfgHome </> ".vim.local" </> "bundles.vim")
    Turtle.mv
      (hvnCfgHome </> ".vim.local" </> "bundles.vim")
      (hvnCfgDest </> "plugins.vim")
    bundleBackupExists <-
      Turtle.testfile (hvnCfgHome </> ".vim.local" </> "bundles.vim.bak")
    when bundleBackupExists $
      Turtle.rm (hvnCfgHome </> ".vim.local" </> "bundles.vim.bak")
    vimLocalExists <- Turtle.testdir (hvnCfgHome </> ".vim.local")
    when vimLocalExists $ Turtle.rmtree (hvnCfgHome </> ".vim.local")
  when (not destDirExists && not oldInstallExists) $ do
    warn "No previous installations detected."
    msg $ "Installing Haskell-Vim-Now from " <> hvnCfgRepo <> " ..."
    Turtle.mktree hvnCfgHome
    Turtle.shell
      ("git clone --single-branch -b " <> hvnCfgBranch <> " " <> hvnCfgRepo <>
       " " <>
       filePathToText hvnCfgDest)
      empty .||.
      Turtle.exit (Turtle.ExitFailure 1)
    return ()
  checkRepoChange
  msg "Syncing Haskell-Vim-Now with upstream..."
  repoUpdated <- (== Turtle.ExitSuccess) <$> updatePull
  unless repoUpdated $ do
    err "Sync (git pull) failed. Aborting..."
    Turtle.exit (Turtle.ExitFailure 1)

setupTools :: (MonadIO m) => m ()
setupTools = do
  pkgMgr <- packageManager
  pkgsToInstall <- packageList pkgMgr
  unless (null pkgsToInstall) $ void $ packageInstall pkgMgr pkgsToInstall
  msg "Checking ctags' exuberance..."
  isExuberant <-
    Data.Text.isInfixOf "Exuberant" <$> commandSubstitution "ctags --version"
  unless isExuberant $ do
    err
      "Requires exuberant-ctags, not just ctags. Please install and put it in your PATH."
    void $ Turtle.exit (Turtle.ExitFailure 1)
  msg "Setting git to use fully-pathed vim for messages..."
  mVimPathAndOpts <-
    runMaybeT $
    -- TODO This is opinionated and shouldn't be - assuming Windows users prefer gvim.exe
    -- TODO Somewhat hacky way to get vim options
    (, " -f -i NONE") <$> MaybeT (Turtle.which (FS.addExtension "gvim" "exe")) <|>
    (, "") <$> MaybeT (Turtle.which (FS.addExtension "vim" "exe")) <|>
    (, "") <$> MaybeT (Turtle.which "vim")
  case mVimPathAndOpts of
    Nothing -> do
      err "TODO"
    (Just (vimPath, vimOpts)) -> do
      let vimPathUnixStyle =
            "\"'" <> (Data.Text.replace "\\" "/" . filePathToText $ vimPath) <>
            "'" <>
            vimOpts <>
            "\""
      msg $ "Vim path is '" <> vimPathUnixStyle <> "'"
      Turtle.shell
        ("git config --global core.editor " <> vimPathUnixStyle)
        empty $>
        ()

vimVersionPattern :: Turtle.Pattern (Word, Word)
vimVersionPattern =
  Turtle.prefix $
  (,) <$> (Turtle.skip "VIM - Vi IMproved " *> Turtle.decimal) <*>
  (Turtle.skip "." *> Turtle.decimal)

checkVimVersion :: (MonadIO m) => m ()
checkVimVersion = do
  vimVersionString <- commandSubstitution "vim --version"
  let mVimVersion =
        listToMaybe . Turtle.match vimVersionPattern $ vimVersionString
  case mVimVersion of
    Nothing -> do
      err $
        "Could not parse Vim version from version string: " <> vimVersionString
      Turtle.exit (Turtle.ExitFailure 1)
    (Just vimVersion) -> do
      let vimVersionTooOld = vimVersion < (7, 4)
      when vimVersionTooOld $ do
        let vimVersionPretty =
              (Data.Text.pack . show $ fst vimVersion) <> "." <>
              (Data.Text.pack . show $ snd vimVersion)
        err $
          "Detected vim version \"" <> vimVersionPretty <>
          "\", however version 7.4 or later is required."
        Turtle.exit (Turtle.ExitFailure 1)
      unless vimVersionTooOld $ do
        hasRuby <-
          isJust <$>
          Turtle.fold
            (Turtle.grep
               (Turtle.contains "+ruby")
               (Turtle.inshell "vim --version" empty))
            Foldl.head
        unless hasRuby $ do
          err "Ruby is unavailable in your installation of vim."
          Turtle.exit (Turtle.ExitFailure 1)
        when hasRuby $ do
          msg "Testing for broken Ruby interface in vim..."
          -- TODO This Ruby check is pretty scary...  Also have no clue why I
          -- need to triple up the double quotes on the string match for
          -- "ruby_works". Went the route of forcing Vim to return error
          -- code if the string match fails because at least on Windows,
          -- the simpler ":ruby puts RUBY_VERSION" was always returning success.
          rubyIsWorking <-
            (== Turtle.ExitSuccess) <$>
            (nullShell $
             "vim -T dumb --cmd \"redir @a\" " <>
             "--cmd \"ruby puts :ruby_works\" " <>
             "--cmd \"redir END\" " <>
             "--cmd \"if getreg('a') =~ \"\"\"ruby_works\"\"\" | qall | else | cq | endif\"")
          unless rubyIsWorking $ do
            err "The Ruby interface is broken on your installation of vim."
            err "You may need to reinstall Ruby or reinstall/recompile vim."
            msg "If you're on OS X, try the following:"
            detail "rvm use system"
            detail "brew reinstall vim"
            warn
              "If nothing helped, please report at https://github.com/begriffs/haskell-vim-now/issues"
            Turtle.exit (Turtle.ExitFailure 1)
          when rubyIsWorking $ msg "Test passed. Ruby interface is OK."

vimInstallPlug :: (MonadIO m, MonadReader HvnConfig m) => m ()
vimInstallPlug = do
  HvnConfig {..} <- ask
  let vimPlugFilePath = hvnCfgDest </> ".vim" </> "autoload" </> "plug.vim"
  Turtle.mktree . FS.directory $ vimPlugFilePath
  plugExists <- Turtle.testfile vimPlugFilePath
  unless plugExists $ do
    installedVimPlug <-
      (== Turtle.ExitSuccess) <$>
      Turtle.shell
        ("curl -fLo " <> filePathToText vimPlugFilePath <>
         " --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim")
        empty
    unless installedVimPlug $ do
      err "Failed to install vim-plug."
      Turtle.exit (Turtle.ExitFailure 1)

vimInstallPlugins :: (MonadIO m, MonadReader HvnConfig m) => m ()
vimInstallPlugins = do
  HvnConfig {..} <- ask
  let vimRcFilePath = filePathToText $ hvnCfgDest </> ".vimrc"
  msg "Installing plugins using vim-plug..."
  void $
    -- TODO The Vim plugin install messes up the console write position on Windows
    -- and currently cannot see the status of the plugin install. Writing to nullShell
    -- on Windows, but would rather be able to see the vim plug output.
    if isWindows
      then nullShell
             ("vim -E -u " <> vimRcFilePath <>
              " +PlugUpgrade +PlugUpdate +PlugClean! +qall")
      else Turtle.shell
             ("vim -E -u " <> vimRcFilePath <>
              " +PlugUpgrade +PlugUpdate +PlugClean! +qall")
             empty

vimBackup :: (MonadIO m, MonadReader HvnConfig m) => m ()
vimBackup = do
  HvnConfig {..} <- ask
  homePath <- Turtle.home
  let colorSchemePaths =
        [homePath </> ".vim" </> "colors", homePath </> "vimfiles" </> "colors"]
  forM_ colorSchemePaths $ \fp -> do
    fpExists <- Turtle.testdir fp
    when fpExists $ do
      msg "Preserving color scheme files..."
      cptree' fp (hvnCfgDest </> "colors")
  curTime <- localTimeText
  msg $ "Backing up current vim config using timestamp " <> curTime <> "..."
  Turtle.mktree (hvnCfgDest </> "backup")
  let vimConfigPaths =
        [".vim", ".vimrc", ".gvimrc", "vimfiles", "_vimrc", "_gvimrc"]
  forM_ vimConfigPaths $ \fileName -> do
    let fpUnderHome = homePath </> textToFilePath fileName
        fpUnderBackup =
          hvnCfgDest </> "backup" </>
          (textToFilePath (fileName <> "_" <> curTime))
    pathExists <- Turtle.testpath fpUnderHome
    when pathExists $ do
      detail $ filePathToText fpUnderBackup
      Turtle.mv fpUnderHome fpUnderBackup

vimSetupLinks :: (MonadIO m, MonadReader HvnConfig m) => m ()
vimSetupLinks = do
  HvnConfig {..} <- ask
  homePath <- Turtle.home
  let vimRcUnderHvnDest = hvnCfgDest </> ".vimrc"
      vimUnderHvnDest = hvnCfgDest </> ".vim"
      vimRcUnderHome =
        if isWindows
          then homePath </> "_vimrc"
          else homePath </> ".vimrc"
      vimUnderHome =
        if isWindows
          then homePath </> "vimfiles"
          else homePath </> ".vim"
  msg "Creating vim config symlinks"
  mkLink vimRcUnderHvnDest vimRcUnderHome
  mkDirLink vimUnderHvnDest vimUnderHome

setupVim :: (MonadIO m, MonadReader HvnConfig m) => m ()
setupVim = do
  checkVimVersion
  vimInstallPlug
  vimBackup
  vimSetupLinks
  vimInstallPlugins

setupHaskell :: (MonadIO m, MonadReader HvnConfig m) => m ()
setupHaskell = do
  HvnConfig {..} <- ask
  hasStack <-
    isJust <$>
    runMaybeT
      (MaybeT (Turtle.which (FS.addExtension "stack" "exe")) <|>
       MaybeT (Turtle.which "stack"))
  unless hasStack $ do
    err "Installer requires Stack."
    msg
      "Installation instructions: http://docs.haskellstack.org/en/stable/README/#how-to-install"
  when hasStack $ do
    msg "Setting up GHC if needed..."
    stackSetupResult <- Turtle.shell "stack setup --verbosity warning" empty
    case stackSetupResult of
      (Turtle.ExitFailure retCode) -> do
        err $
          "Stack setup failed with error " <> (Data.Text.pack . show $ retCode)
        Turtle.exit (Turtle.ExitFailure 1)
      (Turtle.ExitSuccess) -> do
        stackBinPath <-
          commandSubstitution "stack --verbosity 0 path --local-bin"
        stackGlobalDir <-
          commandSubstitution "stack --verbosity 0 path --stack-root"
        stackGlobalConfig <-
          commandSubstitution "stack --verbosity 0 path --config-location"
        stackResolver <- stackResolverText . textToFilePath $ stackGlobalConfig
        detail $ "Stack bin path: " <> stackBinPath
        detail $ "Stack global path: " <> stackGlobalDir
        detail $ "Stack global config location: " <> stackGlobalConfig
        detail $ "Stack resolver: " <> stackResolver
        let emptyStackPath =
              any
                Data.Text.null
                [stackBinPath, stackGlobalDir, stackGlobalConfig]
        when emptyStackPath $ do
          err "Incorrect stack paths."
          Turtle.exit (Turtle.ExitFailure 1)
        let stackBinUnderCfgDest = hvnCfgDest </> ".stack-bin"
        mkDirLink (textToFilePath stackBinPath) stackBinUnderCfgDest
        msg "Installing helper binaries..."
        let hvnHelperBinDir = hvnCfgDest </> "hvn-helper-binaries"
        Turtle.mktree hvnHelperBinDir
        Turtle.cd hvnHelperBinDir
        stackYamlExists <- Turtle.testfile (hvnHelperBinDir </> "stack.yaml")
        unless stackYamlExists $
          -- Install ghc-mod via active stack resolver for maximum out-of-the-box compatibility.
         do
          stackInstall stackResolver "ghc-mod"
          -- Stack dependency solving requires cabal to be on the PATH.
          stackInstall stackResolver "cabal-install"
          -- Install hindent via pinned LTS to ensure we have version 5.
          stackInstall "lts-8.14" "hindent"
          let helperDependenciesCabalText =
                renderMustache helperDependenciesCabalTemplate $
                object ["dependencies" .= helperDependencies]
          liftIO
            (Turtle.writeTextFile
               "dependencies.cabal"
               (toStrict helperDependenciesCabalText))
          Turtle.stdout (Turtle.input "dependencies.cabal")
          let solverCommand = "stack init --solver --install-ghc"
          -- Solve the versions of all helper binaries listed in dependencies.cabal.
          solverResult <- Turtle.shell solverCommand empty
          case solverResult of
            (Turtle.ExitFailure retCode) -> do
              err $
                "\"" <> solverCommand <> "\" failed with error " <>
                (Data.Text.pack . show $ retCode)
              Turtle.exit (Turtle.ExitFailure 1)
            (Turtle.ExitSuccess) -> do
              Turtle.cp "stack.yaml" "stack.yaml.bak"
              Turtle.output
                "stack.yaml"
                (mfilter
                   ((> 1) . Data.Text.length . Turtle.lineToText)
                   (Turtle.sed
                      (Turtle.begins ("#" <|> "user-message" <|> "  ") *>
                       pure "")
                      (Turtle.input "stack.yaml.bak")))
          versionedHelperDeps <-
            fmap Turtle.lineToText <$>
            Turtle.fold
              (mfilter
                 (filterHelperDeps . Turtle.lineToText)
                 (Turtle.inshell ("stack list-dependencies --separator -") empty))
              Foldl.list
          helperDepStackResolver <-
            stackResolverText $ hvnHelperBinDir </> "stack.yaml"
          forM_ versionedHelperDeps $ \dep ->
            stackInstall helperDepStackResolver dep
        msg "Installing git-hscope..."
        -- TODO The 'git-hscope' file won't do much good on Windows as it's a bash script
        Turtle.cp
          (hvnCfgDest </> "git-hscope")
          (textToFilePath stackBinPath </> "git-hscope")
        when hvnCfgHoogleDb $ do
          msg "Building Hoogle database..."
          Turtle.sh
            (Turtle.shell
               (filePathToText (textToFilePath stackBinPath </> "hoogle") <>
                " generate")
               empty)
        msg "Configuring codex to search in stack..."
        let codexText =
              renderMustache codexTemplate $
              object
                [ "stackHackageIndicesDir" .=
                  filePathToText
                    (textToFilePath stackGlobalDir </> "indices" </> "Hackage")
                ]
        homePath <- Turtle.home
        liftIO
          (Turtle.writeTextFile (homePath </> ".codex") (toStrict codexText))

stackInstall :: (MonadIO m) => Text -> Text -> m ()
stackInstall resolver package = do
  let installCommand =
        "stack --resolver " <> resolver <> " install " <> package <>
        " --install-ghc --verbosity warning"
  installResult <- Turtle.shell installCommand empty
  case installResult of
    (Turtle.ExitFailure retCode) -> do
      err $
        "\"" <> installCommand <> "\" failed with error " <>
        (Data.Text.pack . show $ retCode)
      Turtle.exit (Turtle.ExitFailure 1)
    (Turtle.ExitSuccess) -> pure ()

stackResolverText :: (MonadIO m) => FilePath -> m Text
stackResolverText stackYamlPath = do
  let defaultResolver = "lts"
  mLine <-
    Turtle.fold
      (Turtle.grep stackResolverPattern (Turtle.input stackYamlPath))
      Foldl.head
  case mLine of
    Nothing -> pure defaultResolver
    (Just line) -> do
      let lineText = Turtle.lineToText line
      let mStackResolver =
            listToMaybe . Turtle.match stackResolverPattern $ lineText
      case mStackResolver of
        Nothing -> do
          err "Failed to determine stack resolver"
          pure defaultResolver
        (Just resolver) -> pure resolver

stackResolverPattern :: Turtle.Pattern Text
stackResolverPattern =
  Turtle.prefix $
  (Turtle.skip "resolver:" *> Turtle.skip Turtle.spaces *>
   Turtle.plus Turtle.dot)

filterHelperDeps :: Text -> Bool
filterHelperDeps dep =
  or (zipWith ($) (fmap Data.Text.isPrefixOf helperDependencies) (repeat dep))

helperDependencies :: [Text]
helperDependencies =
  [ "apply-refact"
  , "codex"
  , "hasktags"
  , "hlint"
  , "hoogle"
  , "hscope"
  , "pointfree"
  , "pointful"
  ]

helperDependenciesCabalTemplate :: Template
helperDependenciesCabalTemplate =
  [mustache|
name:                dependencies
version:             0.1.0.0
synopsis:            helper binaries for vim
homepage:            https://github.com/begriffs/haskell-vim-now
license:             MIT
author:              Joe Nelson
maintainer:          cred+github@begriffs.com
category:            Development
build-type:          Simple
cabal-version:       >=1.10

library
  build-depends:       base >=4.9 && <4.10
{{#dependencies}}
                     , {{.}}
{{/dependencies}}
  default-language:    Haskell2010
|]

codexTemplate :: Template
codexTemplate =
  [mustache|
hackagePath: {{stackHackageIndicesDir}}
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='$TAGS' '$SOURCES'
|]

setupDone :: (MonadIO m, MonadReader HvnConfig m) => m ()
setupDone = do
  HvnConfig {..} <- ask
  msg "<---- HASKELL VIM NOW installation successfully finished ---->"
  warn "If you are using NeoVim"
  detail $
    "Run " <> filePathToText (hvnCfgDest </> "scripts" </> "neovim.sh") <>
    " to backup your existing"
  detail "configuration and symlink the new one."
  warn "Note for a good-looking vim experience:"
  detail "Configure your terminal to use a font with Powerline symbols."
  detail
    "https://powerline.readthedocs.org/en/master/installation.html#fonts-installation"

setup :: (MonadIO m, MonadReader HvnConfig m) => m ()
setup = do
  HvnConfig {..} <- ask
  setupTools
  setupVim
  unless hvnCfgBasic setupHaskell
  setupDone

app :: (MonadIO m, MonadReader HvnConfig m) => m ()
app = install >> setup

main :: IO ()
main = do
  HvnArgs {..} <- Turtle.options "Haskell Vim Now Installer" cliParser
  print $ HvnArgs {..}
  hvnCfgHome <- hvnHomeDir
  let hvnCfgBasic = hvnArgsBasic
      hvnCfgRepo = maybe defaultRepo id hvnArgsRepo
      hvnCfgDest = hvnCfgHome </> "haskell-vim-now"
      hvnCfgBranch = maybe defaultBranch id hvnArgsBranch
      hvnCfgHoogleDb = not hvnArgsNoHoogleDb
  runReaderT app HvnConfig {..}
  Turtle.exit Turtle.ExitSuccess

------------------------------------------------------------------------------
-- Needed until https://github.com/Gabriel439/Haskell-Turtle-Library/commit/7e193ef2db7255640c2b059391d1e44d9cba93bb
-- is available in an official version, most like 1.3.4
cptree' :: MonadIO io => FilePath -> FilePath -> io ()
cptree' oldTree newTree =
  Turtle.sh
    (do oldPath <- Turtle.lstree oldTree
    -- The `system-filepath` library treats a path like "/tmp" as a file and not
    -- a directory and fails to strip it as a prefix from `/tmp/foo`.  Adding
    -- `(</> "")` to the end of the path makes clear that the path is a
    -- directory
        Just suffix <- return (FS.stripPrefix (oldTree </> "") oldPath)
        let newPath = newTree </> suffix
        isFile <- Turtle.testfile oldPath
        if isFile
          then Turtle.mktree (FS.directory newPath) >> Turtle.cp oldPath newPath
          else Turtle.mktree newPath)

-- writes stdout/stderr to null stream, cross platform
nullShell :: (MonadIO m) => Text -> m Turtle.ExitCode
nullShell cmd =
  Turtle.system
    ((System.Process.shell (Data.Text.unpack cmd))
     { System.Process.std_in = System.Process.NoStream
     , System.Process.std_out = System.Process.NoStream
     , System.Process.std_err = System.Process.NoStream
     })
    empty

localTimeText :: (MonadIO m) => m Text
localTimeText = do
  utcTime <- Turtle.date
  localTime <- liftIO (utcToLocalZonedTime utcTime)
  pure
    (Data.Text.pack . formatTime defaultTimeLocale "%Y%m%d_%H%M%S" $ localTime)

-- TODO Hacky - for unix, could use System.Posix.Files createSymbolicLink
mkLink :: (MonadIO m) => FilePath -> FilePath -> m ()
mkLink src dest =
  Turtle.sh
    (do detail $ filePathToText dest <> " -> " <> filePathToText src
        if isWindows
          then do
            Turtle.shell
              ("mklink " <> filePathToText dest <> " " <> filePathToText src)
              empty
          else do
            Turtle.shell
              ("ln -sf " <> filePathToText src <> " " <> filePathToText dest)
              empty)

-- TODO Hacky - for unix, could use System.Posix.Files createSymbolicLink
mkDirLink :: (MonadIO m) => FilePath -> FilePath -> m ()
mkDirLink src dest =
  Turtle.sh
    (do detail $ filePathToText dest <> " -> " <> filePathToText src
        if isWindows
          then do
            Turtle.shell
              ("mklink /d " <> filePathToText dest <> " " <> filePathToText src)
              empty
          else do
            Turtle.shell
              ("ln -sf " <> filePathToText src <> " " <> filePathToText dest)
              empty)

isWindows :: Bool
isWindows = os == "mingw32"
