#!/usr/bin/env sh

for i in git cabal make vim; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    echo "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

endpath="$HOME/.haskell-vim-now"

if [ ! -e $endpath/.git ]; then
  echo "Cloning begriffs/haskell-vim-now"
  git clone https://github.com/begriffs/haskell-vim-now.git $endpath
else
  echo "Updating begriffs/haskell-vim-now"
  cd $endpath && git pull
fi

if [ -e ~/.vim/colors ]; then
  echo "Preserving color scheme files"
  cp -R ~/.vim/colors $endpath/colors
fi

echo "Backing up current vim config"
today=`date +%Y%m%d_%H%M%S`
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc; do [ -e $i ] && [ ! -L $i ] && mv $i $i.$today; done

echo "Creating symlinks"
ln -sf $endpath/.vimrc $HOME/.vimrc
if [ ! -d $endpath/.vim/bundle ]; then
  mkdir -p $endpath/.vim/bundle
fi
ln -sf $endpath/.vim $HOME/.vim

if [ ! -e $HOME/.vim/bundle/vundle ]; then
  echo "Installing Vundle"
  git clone http://github.com/gmarik/vundle.git $HOME/.vim/bundle/vundle
fi

echo "Installing plugins using Vundle"
system_shell=$SHELL
export SHELL="/bin/sh"
vim -u $endpath/.vimrc +BundleInstall! +BundleClean +qall
export SHELL=$system_shell

echo "Building C extension of ghcmod-vim"
cd $endpoint/bundle/ghcmod-vim
make
cd -
