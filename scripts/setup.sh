#!/usr/bin/env bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${SCRIPT_DIR}/func.sh

stack_resolver() {
  local DEFAULT_RESOLVER=lts
  local CONFIGURED=$( sed -rn 's/^resolver:\s*(\S+).*$/\1/p' "$1" 2>/dev/null )
  if [ -z $CONFIGURED ]; then
    echo $DEFAULT_RESOLVER
  else
    echo $CONFIGURED
  fi
  return 0
}

setup_haskell() {
  local HVN_DEST=$1
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
  local STACK_LIST="ghc-mod hlint hasktags codex hscope pointfree pointful hoogle hindent apply-refact"
  stack --resolver ${STACK_RESOLVER} install ${STACK_LIST} --verbosity warning ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Binary installation failed with error ${RETCODE}."

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
}

setup_tools() {
  local SYSTEM_TYPE=$(system_type)
  local PACKAGE_MGR=$(package_manager)
  local CONFIG_HOME=$(config_home)

  local BREW_LIST="git homebrew/dupes/make vim ctags par"
  local APT_LIST="git make vim libcurl4-openssl-dev exuberant-ctags par"
  local YUM_LIST="git make vim ctags libcurl-devel zlib-devel powerline"

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
      exit_err_report "setup.sh is not configured to handle ${PACKAGE_MGR} manager."
  esac

  local NOT_INSTALLED=$(check_exist ctags curl-config git make vim par)
  [ ! -z ${NOT_INSTALLED} ] && exit_err "Installer requires '${NOT_INSTALLED}'. Please install and try again."

  msg "Checking ctags' exuberance..."
  local RETCODE
  ctags --version | grep -q Exuberant ; RETCODE=$?
  [ ${RETCODE} -ne 0 ] && exit_err "Requires exuberant-ctags, not just ctags."

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

vim_install_plugins() {
  local HVN_DEST=$1

  if [ ! -e ${HVN_DEST}/.vim/autoload/plug.vim ]; then
    msg "Installing vim-plug"
    curl -fLo ${HVN_DEST}/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
      || exit_err_report "Failed to install vim-plug."
  fi

  msg "Installing plugins using vim-plug..."
  vim -E -u ${HVN_DEST}/.vimrc +PlugUpgrade +PlugUpdate +PlugClean! +qall
}

setup_vim() {
  local HVN_DEST=$1

  vim_check_version
  vim_install_plugins $HVN_DEST

  # Point of no return; we cannot fail after this.
  # Backup old config and switch to new config
  vim_backup          $HVN_DEST
  vim_setup_links     $HVN_DEST
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
