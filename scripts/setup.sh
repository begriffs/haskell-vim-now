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
  cmdpkg par par

  case $1 in
    BREW)
      cmdpkg make homebrew/dupes/make
      cmdpkg ctags ctags ;;
    PORT)
      cmdpkg make gmake
      cmdpkg ctags ctags ;;
    APT)
      cmdpkg make make
      cmdpkg ctags exuberant-ctags
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
