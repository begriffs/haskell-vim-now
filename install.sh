#!/usr/bin/env bash

msg() { echo "--- $@" 1>&2; }
detail() { echo "	$@" 1>&2; }

for i in git ghc cabal make vim; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    msg "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

endpath="$HOME/.haskell-vim-now"

if [ ! -e $endpath/.git ]; then
  msg "Cloning begriffs/haskell-vim-now"
  git clone https://github.com/begriffs/haskell-vim-now.git $endpath
else
  msg "Existing installation detected"
  msg "Updating from begriffs/haskell-vim-now"
  cd $endpath && git pull
fi

if [ -e ~/.vim/colors ]; then
  msg "Preserving color scheme files"
  cp -R ~/.vim/colors $endpath/colors
fi

today=`date +%Y%m%d_%H%M%S`
msg "Backing up current vim config using timestamp $today"
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc; do [ -e $i ] && [ ! -L $i ] && mv $i $i.$today && detail "$i.$today"; done

msg "Creating symlinks"
detail "~/.vimrc -> $endpath/.vimrc"
detail "~/.vim   -> $endpath/.vim"
ln -sf $endpath/.vimrc $HOME/.vimrc
if [ ! -d $endpath/.vim/bundle ]; then
  mkdir -p $endpath/.vim/bundle
fi
ln -sf $endpath/.vim $HOME/.vim

if [ ! -e $HOME/.vim/bundle/vundle ]; then
  msg "Installing Vundle"
  git clone http://github.com/gmarik/vundle.git $HOME/.vim/bundle/vundle
fi

msg "Installing plugins using Vundle..."
vim -T dumb -Es -u $endpath/.vimrc +BundleInstall! +BundleClean! +qall

msg "Building vimproc.vim"
make -C $endpath/.vim/bundle/vimproc.vim

msg "Building YouCompleteMe"
cd $endpath/.vim/bundle/YouCompleteMe
./install.sh
cd -

msg "Updating cabal package list"
cabal update

msg "Installing ghc-mod for local user"
cabal install --user --reinstall ghc-mod

msg "Installing hasktags for local user"
cabal install --user --reinstall hasktags

msg "Installing codex for local user"
cabal install --user --reinstall codex
