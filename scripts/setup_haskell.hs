#!/usr/bin/env stack
{- stack
  script
  --resolver lts-8.14
  --package aeson
  --package ansi-terminal
  --package foldl
  --package mtl
  --package stache
  --package system-filepath
  --package text
  --package transformers
  --package turtle
-}

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

import Control.Applicative ((<|>), empty)
import Control.Exception (bracket_)
import qualified Control.Foldl as Foldl
import Control.Monad (mfilter, unless, when)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader (MonadReader, ask, runReaderT)
import Control.Monad.Trans.Maybe (MaybeT(..), runMaybeT)
import Data.Aeson ((.=), object)
import Data.Foldable (forM_)
import Data.Maybe (isJust, listToMaybe)
import Data.Monoid ((<>))
import qualified Data.Text as Text
import Data.Text (Text)
import qualified Data.Text.IO as Text.IO
import Data.Text.Lazy (toStrict)
import Filesystem.Path.CurrentOS (FilePath, (</>))
import qualified Filesystem.Path.CurrentOS as FS
import Prelude hiding (FilePath)
import qualified System.Console.ANSI as ANSI
import qualified System.IO
import System.Info (os)
import Text.Mustache (Template, renderMustache)
import Text.Mustache.Compile.TH (mustache)
import qualified Turtle

data HvnConfig = HvnConfig
  { hvnCfgHome           :: FilePath
  , hvnCfgDest           :: FilePath
  , hvnCfgHoogleDb       :: Bool
  , hvnCfgHelperBinaries :: Bool
  } deriving (Show)

data HvnArgs = HvnArgs
  { hvnArgsNoHoogleDb       :: Bool
  , hvnArgsNoHelperBinaries :: Bool
  } deriving (Show)

main :: IO ()
main = do
  HvnArgs {hvnArgsNoHoogleDb, hvnArgsNoHelperBinaries} <-
    Turtle.options "Haskell Vim Now - setup Haskell specifics" cliParser
  print HvnArgs {hvnArgsNoHoogleDb, hvnArgsNoHelperBinaries}
  hvnCfgHome <- hvnHomeDir
  let hvnCfgDest = hvnCfgHome </> "haskell-vim-now"
      hvnCfgHoogleDb = not hvnArgsNoHoogleDb
      hvnCfgHelperBinaries = not hvnArgsNoHelperBinaries
  runReaderT setup HvnConfig { hvnCfgHome
                             , hvnCfgDest
                             , hvnCfgHoogleDb
                             , hvnCfgHelperBinaries
                             }
  Turtle.exit Turtle.ExitSuccess

cliParser :: Turtle.Parser HvnArgs
cliParser = HvnArgs
        <$> Turtle.switch "no-hoogle" 'g'
              "Disable Hoogle database generation."
        <*> Turtle.switch "no-helper-bins" 'b'
              "Disable install of helper binaries (mainly for CI)."

hvnHomeDir :: (MonadIO m) => m FilePath
hvnHomeDir = do
  mXdgConfigHome <- Turtle.need "XDG_CONFIG_HOME"
  maybe
    (fmap (</> ".config") Turtle.home)
    (pure . textToFilePath)
    mXdgConfigHome

setup :: (MonadIO m, MonadReader HvnConfig m) => m ()
setup = do
  setupHaskell
  msg "HASKELL VIM NOW install of Haskell specifics successfully finished"

setupHaskell :: (MonadIO m, MonadReader HvnConfig m) => m ()
setupHaskell = do
  HvnConfig {hvnCfgDest, hvnCfgHoogleDb, hvnCfgHelperBinaries} <- ask
  msg "Setting up GHC if needed..."
  stackSetupResult <- Turtle.shell "stack setup --verbosity warning" empty
  case stackSetupResult of
    (Turtle.ExitFailure retCode) -> do
      err $ "Stack setup failed with error " <> (Text.pack . show $ retCode)
      Turtle.exit (Turtle.ExitFailure 1)
    Turtle.ExitSuccess -> do
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
      let emptyStackPath = any Text.null
                             [ stackBinPath
                             , stackGlobalDir
                             , stackGlobalConfig
                             ]
      when emptyStackPath $ do
        err "Incorrect stack paths."
        Turtle.exit (Turtle.ExitFailure 1)
      let stackBinUnderCfgDest = hvnCfgDest </> ".stack-bin"
      mkDirLink (textToFilePath stackBinPath) stackBinUnderCfgDest
      when hvnCfgHelperBinaries $ do
        msg "Installing helper binaries..."
        let hvnHelperBinDir = hvnCfgDest </> "hvn-helper-binaries"
        Turtle.mktree hvnHelperBinDir
        Turtle.cd hvnHelperBinDir
        stackYamlExists <- Turtle.testfile (hvnHelperBinDir </> "stack.yaml")
        unless stackYamlExists $ do
          -- Install ghc-mod via active stack resolver for maximum
          -- out-of-the-box compatibility.
          stackInstall stackResolver "ghc-mod"
          -- Stack dependency solving requires cabal to be on the PATH.
          stackInstall stackResolver "cabal-install"
          -- Install hindent via pinned LTS to ensure we have version 5.
          stackInstall "lts-8.14" "hindent"
          let helperDependenciesCabalText =
                renderMustache helperDependenciesCabalTemplate $
                object ["dependencies" .= helperDependencies]
          liftIO $
            Turtle.writeTextFile
              "dependencies.cabal"
              (toStrict helperDependenciesCabalText)
          Turtle.stdout (Turtle.input "dependencies.cabal")
          let solverCommand = "stack init --solver --install-ghc"
          -- Solve the versions of all helper binaries listed in
          -- dependencies.cabal.
          solverResult <- Turtle.shell solverCommand empty
          case solverResult of
            (Turtle.ExitFailure retCode) -> do
              err $
                "\"" <> solverCommand <> "\" failed with error " <>
                (Text.pack . show $ retCode)
              Turtle.exit (Turtle.ExitFailure 1)
            Turtle.ExitSuccess -> do
              Turtle.cp "stack.yaml" "stack.yaml.bak"
              Turtle.output
                "stack.yaml"
                (mfilter
                   ((> 1) . Text.length . Turtle.lineToText)
                   (Turtle.sed
                      (Turtle.begins ("#" <|> "user-message" <|> "  ") *>
                       pure "")
                      (Turtle.input "stack.yaml.bak")))
          versionedHelperDeps <-
            fmap Turtle.lineToText <$>
            Turtle.fold
              (mfilter
                (filterHelperDeps . Turtle.lineToText)
                (Turtle.inshell "stack list-dependencies --separator -"
                  empty))
              Foldl.list
          helperDepStackResolver <- stackResolverText $
                                      hvnHelperBinDir </> "stack.yaml"
          forM_ versionedHelperDeps $ \dep ->
            stackInstall helperDepStackResolver dep
        msg "Installing git-hscope..."
        -- TODO: The 'git-hscope' file won't do much good on Windows as it
        -- is a bash script.
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
              object [ "stackHackageIndicesDir" .=
                         filePathToText (textToFilePath stackGlobalDir
                           </> "indices" </> "Hackage") ]
        homePath <- Turtle.home
        liftIO
          (Turtle.writeTextFile (homePath </> ".codex") (toStrict codexText))

stackResolverText :: (MonadIO m) => FilePath -> m Text
stackResolverText stackYamlPath = do
  let defaultResolver = "lts"
  mLine <- Turtle.fold
             (Turtle.grep stackResolverPattern (Turtle.input stackYamlPath))
             Foldl.head
  case mLine of
    Nothing -> pure defaultResolver
    (Just line) -> do
      let lineText = Turtle.lineToText line
      let mStackResolver = listToMaybe
                         . Turtle.match stackResolverPattern
                         $ lineText
      case mStackResolver of
        Nothing -> do
          err "Failed to determine stack resolver"
          pure defaultResolver
        (Just resolver) -> pure resolver

stackResolverPattern :: Turtle.Pattern Text
stackResolverPattern = Turtle.prefix
  (Turtle.skip "resolver:" *> Turtle.skip Turtle.spaces *>
   Turtle.plus Turtle.dot)

stackInstall :: (MonadIO m) => Text -> Text -> m ()
stackInstall resolver package = do
  let installCommand =
        "stack --resolver " <> resolver <> " install " <> package <>
        " --install-ghc --verbosity warning"
  detail installCommand
  installResult <- Turtle.shell installCommand empty
  case installResult of
    (Turtle.ExitFailure retCode) -> do
      err $
        "\"" <> installCommand <> "\" failed with error " <>
        (Text.pack . show $ retCode)
      Turtle.exit (Turtle.ExitFailure 1)
    Turtle.ExitSuccess -> pure ()

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

filterHelperDeps :: Text -> Bool
filterHelperDeps dep =
  any ($ dep) (fmap Text.isPrefixOf helperDependencies)

helperDependenciesCabalTemplate :: Template
helperDependenciesCabalTemplate = [mustache|name:                dependencies
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
codexTemplate = [mustache|hackagePath: {{stackHackageIndicesDir}}
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output="$TAGS" "$SOURCES"
|]

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
detail txt =
  consoleLog
    System.IO.stdout
    [ ANSI.SetConsoleIntensity ANSI.BoldIntensity ]
    ("    " <> txt)

consoleLog :: (MonadIO m) => System.IO.Handle -> [ANSI.SGR] -> Text -> m ()
consoleLog handle sgrs txt = liftIO $
  bracket_
    (ANSI.setSGR [ANSI.Reset] *> ANSI.setSGR sgrs)
    (ANSI.setSGR [ANSI.Reset])
    (Text.IO.hPutStrLn handle txt)

-- a.k.a. $(...)
commandSubstitution :: (MonadIO m) => Text -> m Text
commandSubstitution cmd = do
  mval <- Turtle.fold (Turtle.inshell cmd empty) Foldl.head
  pure $ maybe mempty Turtle.lineToText mval

-- For Unix, could use System.Posix.Files createSymbolicLink instead of raw
-- shell.
mkDirLink :: (MonadIO m) => FilePath -> FilePath -> m ()
mkDirLink src dest =
  Turtle.sh $ do
    detail $ filePathToText dest <> " -> " <> filePathToText src
    if isWindows
    then Turtle.shell
           ("mklink /d " <> filePathToText dest <> " " <> filePathToText src)
           empty
    else Turtle.shell
           ("ln -sf " <> filePathToText src <> " " <> filePathToText dest)
           empty

isWindows :: Bool
isWindows = os == "mingw32"

filePathToText :: FilePath -> Text
filePathToText = Turtle.format Turtle.fp

textToFilePath :: Text -> FilePath
textToFilePath = FS.fromText
