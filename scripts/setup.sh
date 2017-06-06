#!/usr/bin/env bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${SCRIPT_DIR}/func.sh

stack_resolver() {
  local DEFAULT_RESOLVER=lts
  local CONFIGURED

  CONFIGURED=$(awk '{if ($1 == "resolver:") {print $2}}' "$1") \
    || err "Failed to determine stack resolver"
  if [ -z $CONFIGURED ]; then
    echo $DEFAULT_RESOLVER
  else
    echo $CONFIGURED
  fi
  return 0
}

setup_haskell() {
  local HVN_DEST=$1
  local GENERATE_HOOGLE_DB=$2
  local DRY_RUN=$3
  local RETCODE

  if ! check_exist stack >/dev/null ; then
    err "Installer requires Stack."
    msg "Installation instructions: http://docs.haskellstack.org/en/stable/README/#how-to-install"
    exit 1
  fi

  msg "Setting up GHC if needed..."
  stack setup --verbosity warning ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Stack setup failed with error ${RETCODE}."

  if [ $(stack --verbosity 0 path --local-bin 2> /dev/null) ]
  then
    local STACK_BIN_PATH=$(fix_path $(stack --verbosity 0 path --local-bin))
    local STACK_GLOBAL_DIR=$(fix_path $(stack --verbosity 0 path --stack-root))
    local STACK_GLOBAL_CONFIG=$(fix_path $(stack --verbosity 0 path --config-location))
  else
    local STACK_BIN_PATH=$(fix_path $(stack --verbosity 0 path --local-bin-path))
    local STACK_GLOBAL_DIR=$(fix_path $(stack --verbosity 0 path --global-stack-root))
    local STACK_GLOBAL_CONFIG=$(fix_path $(stack --verbosity 0 path --config-location))
  fi
  local STACK_RESOLVER=$(stack_resolver $STACK_GLOBAL_CONFIG)

  detail "Stack bin path: ${STACK_BIN_PATH}"
  detail "Stack global path: ${STACK_GLOBAL_DIR}"
  detail "Stack global config location: ${STACK_GLOBAL_CONFIG}"
  detail "Stack resolver: ${STACK_RESOLVER}"

  if [ -z ${STACK_BIN_PATH} ] || [ -z ${STACK_GLOBAL_DIR} ] || [ -z ${STACK_GLOBAL_CONFIG} ] ; then
    exit_err_report "Incorrect stack paths."
  fi

  detail "${HVN_DEST}/.stack-bin -> ${STACK_BIN_PATH}"
  ln -sf ${STACK_BIN_PATH} ${HVN_DEST}/.stack-bin

  msg "Installing helper binaries..."
  
  # Install ghc-mod via active stack resolver for maximum out-of-the-box compatibility.
  # Stack dependency solving requires cabal to be on the PATH.
  stack --resolver ${STACK_RESOLVER} install ghc-mod cabal-install --verbosity warning ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Installing ghc-mod/cabal-install failed with error ${RETCODE}."

  # Install hindent via pinned LTS to ensure we have version 5.
  if [ "$DRY_RUN" == false ]
  then
    stack --resolver lts-8.6 install hindent --install-ghc --verbosity warning ; RETCODE=$?
  else
    stack --resolver lts-8.6 install hindent --install-ghc --verbosity warning --dry-run ; RETCODE=$?
  fi
  [ ${RETCODE} -ne 0 ] && exit_err "Installing hindent failed with error ${RETCODE}."

  # Create a temporary directory for helper binary dependency solving.
  local HELPER_BINARIES_TEMP_DIR=$(mktemp -d)
  cp ${HVN_DEST}/dependencies.cabal $HELPER_BINARIES_TEMP_DIR
  pushd $HELPER_BINARIES_TEMP_DIR

  # Solve the versions of all helper binaries listed in dependencies.cabal.
  stack init --solver --install-ghc ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Solving dependencies for helper binaries failed with error ${RETCODE}."

  # Clean up the comments and blank lines from stack.yaml.
  sed -i.bak1 -e 's/^#.*$//' -e '/^$/d' stack.yaml
  
  # Remove warning message from generated stack.yaml.
  sed -i.bak2 -e '/user-message/,+3d' stack.yaml

  # Install all solved dependency versions for the helper binaries, while skipping local dependencies package and GHC.
  # Also skipping bogus 'invalid-cabal-flag-settings' dependency from base: https://github.com/commercialhaskell/stack/issues/2969
  local HELPER_BINARIES_DEPENDENCY_LIST=$(stack list-dependencies --separator - | grep -vE "^dependencies-|^ghc-[0-9]\.[0-9]\.[0-9]$|^invalid-cabal-flag-settings-|^rts-")

  for dep in $HELPER_BINARIES_DEPENDENCY_LIST
  do
    if [ "$DRY_RUN" == false ]
    then
      stack install $dep ; RETCODE=$?
    else
      stack install $dep --dry-run ; RETCODE=$?
    fi
    [ ${RETCODE} -ne 0 ] && exit_err "Installing helper binary dependency $dep failed with error ${RETCODE}."
  done

  # Clean up temporary directory.
  popd
  rm -rf $HELPER_BINARIES_TEMP_DIR

  msg "Installing git-hscope..."
  cp ${HVN_DEST}/git-hscope ${STACK_BIN_PATH}

  if [ "$GENERATE_HOOGLE_DB" == true ]
  then
    msg "Building Hoogle database..."
    ${STACK_BIN_PATH}/hoogle generate
  fi

  msg "Configuring codex to search in stack..."
  cat > $HOME/.codex <<EOF
hackagePath: $STACK_GLOBAL_DIR/indices/Hackage/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF
}

# Print package name to install if command is not found
# $1: command name
# $2: package name
cmdpkg() {
  test -n "$(which $1)" || echo "$2"
}

# $1: package manager
package_list() {
  cmdpkg git git
  cmdpkg vim vim

  case $1 in
    BREW)
      cmdpkg make homebrew/dupes/make
      cmdpkg ctags ctags
      cmdpkg par par ;;
    PORT)
      cmdpkg make gmake
      cmdpkg ctags ctags
      cmdpkg par par ;;
    APT)
      cmdpkg make make
      cmdpkg ctags exuberant-ctags
      cmdpkg par par
      cmdpkg curl curl
      echo libcurl4-openssl-dev ;;
    YUM|DNF)
      cmdpkg make make
      cmdpkg ctags ctags
      echo "libcurl-devel zlib-devel powerline" ;;
  esac
}

setup_tools() {
  # Installs _only if_ the command is not available
  local PACKAGE_MGR=$(package_manager)
  package_install ${PACKAGE_MGR} $(package_list ${PACKAGE_MGR})

  local NOT_INSTALLED=$(check_exist ctags curl curl-config git make vim par)
  [ ! -z "${NOT_INSTALLED}" ] && exit_err "Installer requires '${NOT_INSTALLED}'. Please install and try again."

  msg "Checking ctags' exuberance..."
  local RETCODE
  ctags --version | grep -q Exuberant ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Requires exuberant-ctags, not just ctags. Please install and put it in your PATH."

  msg "Setting git to use fully-pathed vim for messages..."
  git config --global core.editor $(which vim)
}

vim_check_version() {
  local VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')
  if ! verlte '7.4' ${VIM_VER} ; then
    exit_err "Detected vim version \"${VIM_VER}\", however version 7.4 or later is required."
  fi

  if vim --version | grep -q +ruby 2>&1 ; then
    msg "Testing for broken Ruby interface in vim..."
    vim -T dumb --cmd "ruby puts RUBY_VERSION" --cmd qa! 1>/dev/null 2>/dev/null
    if [ $? -eq 0 ] ; then
      msg "Test passed. Ruby interface is OK."
    else
      err "The Ruby interface is broken on your installation of vim."
      err "Reinstall or recompile vim."
      msg "If you're on OS X, try the following:"
      detail "rvm use system"
      detail "brew reinstall vim"
      warn "If nothing helped, please report at https://github.com/begriffs/haskell-vim-now/issues"
      exit 1
    fi
  fi
}

vim_backup () {
  local HVN_DEST=$1

  if [ -e ~/.vim/colors ]; then
    msg "Preserving color scheme files..."
    cp -R ~/.vim/colors ${HVN_DEST}/colors
  fi

  today=`date +%Y%m%d_%H%M%S`
  msg "Backing up current vim config using timestamp ${today}..."
  [ ! -e ${HVN_DEST}/backup ] && mkdir ${HVN_DEST}/backup

  for i in .vim .vimrc .gvimrc; do [ -e ${HOME}/${i} ] && mv ${HOME}/${i} ${HVN_DEST}/backup/${i}.${today} && detail "${HVN_DEST}/backup/${i}.${today}"; done
}

vim_setup_links() {
  local HVN_DEST=$1

  msg "Creating vim config symlinks"
  detail "~/.vimrc -> ${HVN_DEST}/.vimrc"
  ln -sf ${HVN_DEST}/.vimrc ${HOME}/.vimrc

  detail "~/.vim   -> ${HVN_DEST}/.vim"
  ln -sf ${HVN_DEST}/.vim ${HOME}/.vim
}

vim_install_plug() {
  local HVN_DEST=$1

  if [ ! -e ${HVN_DEST}/.vim/autoload/plug.vim ]; then
    msg "Installing vim-plug"
    curl -fLo ${HVN_DEST}/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
      || exit_err_report "Failed to install vim-plug."
  fi
}

vim_install_plugins() {
  msg "Installing plugins using vim-plug..."
  vim -E -u ${HVN_DEST}/.vimrc +PlugUpgrade +PlugUpdate +PlugClean! +qall
}

setup_vim() {
  local HVN_DEST=$1

  vim_check_version
  vim_install_plug $HVN_DEST

  # Point of no return; we cannot fail after this.
  # Backup old config and switch to new config
  vim_backup          $HVN_DEST
  vim_setup_links     $HVN_DEST
  vim_install_plugins $HVN_DEST
}

setup_done() {
  local HVN_DEST=$1

  echo -e "\n"
  msg "<---- HASKELL VIM NOW installation successfully finished ---->"
  echo -e "\n"

  warn "If you are using NeoVim"
  detail "Run ${HVN_DEST}/scripts/neovim.sh to backup your existing"
  detail "configuration and symlink the new one."

  warn "Note for a good-looking vim experience:"
  detail "Configure your terminal to use a font with Powerline symbols."
  detail "https://powerline.readthedocs.org/en/master/installation.html#fonts-installation"
}
