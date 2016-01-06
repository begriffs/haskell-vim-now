#!/usr/bin/env bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${SCRIPT_DIR}/func.sh

setup() {
  # $1 - optional - path to haskell-vim-now installation
  #      If not set, script will use default location.
  unset HVN_DEST
  if [ -z $1 ] ; then
    # No argument provided, using default path
    HVN_DEST="$(config_home)/haskell-vim-now"
  else
    HVN_DEST=$1
  fi
  [ ! -e ${HVN_DEST} ] && exit_err "${HVN_DEST} doesn't exist! Install Haskell-Vim-Now first!"

  SYSTEM_TYPE=$(system_type)
  PACKAGE_MGR=$(package_manager)
  CONFIG_HOME=$(config_home)

  BREW_LIST="git homebrew/dupes/make vim ctags"
  APT_LIST="git make vim libcurl4-openssl-dev exuberant-ctags fonts-powerline"
  YUM_LIST="git make vim ctags libcurl-devel zlib-devel powerline"


  if ! check_exist stack >/dev/null ; then
    err "Installer requires Stack."
    msg "Installation instructions: https://github.com/commercialhaskell/stack#how-to-install"
    exit 1
  fi

  msg "Installing system package dependencies..."
  case ${PACKAGE_MGR} in
    BREW )
      msg "Installing with homebrew..."
      brew install ${BREW_LIST}
      ;;
    APT )
      msg "Installing with apt-get..."
      sudo apt-get install -y ${APT_LIST}
      ;;
    DNF )
      msg "Installing with DNF..."
      sudo dnf install -yq ${YUM_LIST} # yum and dnf use same repos
      ;;
    YUM )
      msg "Installing with YUM..."
      sudo yum install -yq ${YUM_LIST}
      ;;
    OTHER )
      warn "No package manager detected. You may need to install required packages manually."
      ;;
    * )
      err "setup.sh is not configured to handle ${PACKAGE_MGR} manager! Aborting..."
      exit 1
  esac

  NOT_INSTALLED=$(check_exist ctags curl-config git make vim)
  [ ! -z ${NOT_INSTALLED} ] && exit_err "Installer requires '${NOT_INSTALLED}'. Please install and try again."

  VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')
  if ! verlte '7.4' ${VIM_VER} ; then
    warn "Detected vim version \"${VIM_VER}\""
    err "However version 7.4 or later is required. Aborting."
    exit 1
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

  msg "Checking ctags' exuberance..."
  ctags --version | grep -q Exuberant ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Requires exuberant-ctags, not just ctags."

  msg "Setting up GHC if needed..."
  stack setup --verbosity warning ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Stack setup failed with error ${RETCODE}. Aborting..."

  STACK_BIN_PATH=$(fix_path $(stack --verbosity 0 path --local-bin-path))
  STACK_GLOBAL_DIR=$(fix_path $(stack --verbosity 0 path --global-stack-root))
  STACK_GLOBAL_CONFIG=$(fix_path $(stack --verbosity 0 path --config-location))

  detail "Stack bin path: ${STACK_BIN_PATH}"
  detail "Stack global path: ${STACK_GLOBAL_DIR}"
  detail "Stack global config location: ${STACK_GLOBAL_CONFIG}"

  if [ -z ${STACK_BIN_PATH} ] || [ -z ${STACK_GLOBAL_DIR} ] || [ -z ${STACK_GLOBAL_CONFIG} ] ; then
    err "Incorrect stack paths."
    err "Please report at https://github.com/begriffs/haskell-vim-now/issues"
    err "Aborting..."
    exit 1
  fi

  msg "Adding extra stack deps if needed..."
  DEPS_REGEX='s/extra-deps: \[\]/extra-deps: [cabal-helper-0.6.1.0, pure-cdb-0.1.1]/'
  # upgrade from a previous installation
  DEPS_UPGRADE_REGEX='s/cabal-helper-0.5.3.0/cabal-helper-0.6.1.0/g'
  sed -i.bak "${DEPS_REGEX}" ${STACK_GLOBAL_CONFIG}
  sed -i.bak "${DEPS_UPGRADE_REGEX}" ${STACK_GLOBAL_CONFIG}
  rm -f ${STACK_GLOBAL_CONFIG}.bak

  msg "Installing helper binaries..."
  stack --resolver nightly-2015-12-08 install ghc-mod hdevtools hlint hasktags codex hscope pointfree-1.1 pointful-1.0.6 hoogle stylish-haskell --verbosity warning ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && err "Binary installation failed with error ${RETCODE}. Aborting..."

  msg "Installing git-hscope..."
  cp ${HVN_DEST}/git-hscope ${STACK_BIN_PATH}

  msg "Building Hoogle database..."
  ${STACK_BIN_PATH}/hoogle data

  msg "Configuring codex to search in stack..."
  cat > $HOME/.codex <<EOF
hackagePath: $STACK_GLOBAL_DIR/indices/Hackage/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF

  ## Vim configuration steps

  if [ -e ~/.vim/colors ]; then
    msg "Preserving color scheme files..."
    cp -R ~/.vim/colors ${HVN_DEST}/colors
  fi

  today=`date +%Y%m%d_%H%M%S`
  msg "Backing up current vim config using timestamp ${today}..."
  [ ! -e ${HVN_DEST}/backup ] && mkdir ${HVN_DEST}/backup

  for i in .vim .vimrc .gvimrc; do [ -e ${HOME}/${i} ] && mv ${HOME}/${i} ${HVN_DEST}/backup/${i}.${today} && detail "${HVN_DEST}/backup/${i}.${today}"; done

  msg "Creating symlinks"
  detail "~/.vimrc -> ${HVN_DEST}/.vimrc"
  ln -sf ${HVN_DEST}/.vimrc ${HOME}/.vimrc
  detail "~/.vim   -> ${HVN_DEST}/.vim"
  ln -sf ${HVN_DEST}/.vim ${HOME}/.vim
  detail "${HVN_DEST}/.stack-bin -> ${STACK_BIN_PATH}"
  ln -sf ${STACK_BIN_PATH} ${HVN_DEST}/.stack-bin

  if [ ! -e ${HVN_DEST}/.vim/autoload/plug.vim ]; then
    msg "Installing vim-plug"
    curl -fLo ${HVN_DEST}/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi

  msg "Installing plugins using vim-plug..."
  vim -E -u ${HVN_DEST}/.vimrc +PlugUpgrade +PlugUpdate +PlugClean! +qall

  msg "Setting git to use fully-pathed vim for messages..."
  git config --global core.editor $(which vim)

  echo -e "\n"
  msg "<---- HASKELL VIM NOW installation successfully finished ---->"
  echo -e "\n"

  warn "If you are using NeoVim"
  detail "Run ${HOME}/${HVN_DEST}/scripts/neovim.sh to backup your existing"
  detail "configuration and symlink the new one."

  warn "Note for a good-looking vim experience:"
  detail "Configure your terminal to use a font with Powerline symbols."
  detail "https://powerline.readthedocs.org/en/master/installation.html#fonts-installation"
}
