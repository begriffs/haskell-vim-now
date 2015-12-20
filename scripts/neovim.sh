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


  ## Neovim configuration steps

  today=`date +%Y%m%d_%H%M%S`
  msg "Backing up current nvim config using timestamp ${today}..."
  [ ! -e ${HVN_DEST}/backup ] && mkdir ${HVN_DEST}/backup

  [ -e ${HOME}/.config/nvim ] && mv ${HOME}/.config/nvim ${HVN_DEST}/backup/nvim.${today} && detail "${HVN_DEST}/backup/nvim.${today}"

  msg "Creating folder for Neovim"
  mkdir -p ${HOME}/.config/nvim

  msg "Creating symlinks"
  detail "~/.config/nvim/init.vim -> ${HVN_DEST}/.vimrc"
  ln -sf ${HVN_DEST}/.vimrc ${HOME}/.config/nvim/init.vim
  detail "~/.config/nvim/bundle -> ${HVN_DEST}/.vim/bundle"
  ln -sf ${HVN_DEST}/.vim/bundle ${HOME}/.config/nvim/bundle
  detail "~/.config/nvim/autoload -> ${HVN_DEST}/.vim/autoload"
  ln -sf ${HVN_DEST}/.vim/autoload ${HOME}/.config/nvim/autoload

  echo -e "\n"
  msg "<---- HASKELL VIM NOW Neovim setup successfully finished ---->"
  echo -e "\n"
}

main() {
  setup ${HVN_DEST}
}

main
