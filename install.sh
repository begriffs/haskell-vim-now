#!/usr/bin/env bash

msg() { echo "--- $@" 1>&2; }
detail() { echo "	$@" 1>&2; }
verlte() {
  [ "$1" = `echo -e "$1\n$2" | sort -g -t '.' | head -n1` ]
}

for i in ctags git ghc cabal make vim curl-config; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    msg "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

CABAL_VER=$(cabal --numeric-version)
VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')
GHC_VER=$(ghc --numeric-version)

if ! verlte '7.4' $VIM_VER ; then
  msg "Vim version 7.4 or later is required. Aborting."
  exit 1
fi

if ! verlte '1.18' $CABAL_VER ; then
  msg "Cabal version 1.18 or later is required. Aborting."
  exit 1
fi

if ! verlte '7.6.3' $GHC_VER ; then
  msg "GHC version 7.6.3 or later is required. Aborting."
  exit 1
fi

if ! ctags --version | grep -q "Exuberant" ; then
  msg "Requires exuberant ctags, not just ctags. Aborting."
  exit 1
fi

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
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc; do [ -e $i ] && mv $i $i.$today && detail "$i.$today"; done

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
vim -T dumb -E -u $endpath/.vimrc +BundleInstall! +BundleClean! +qall

msg "Building vimproc.vim"
make -C ~/.vim/bundle/vimproc.vim

msg "Updating cabal package list"
cabal update

msg "Installing git-hscope"
mkdir -p $endpath/bin
cp $endpath/git-hscope $endpath/bin

function build_shared_binary {
  pkg=$1

  if [ -e $endpath/bin/$pkg ]
  then
    msg "$pkg is already installed, skipping build"
    return
  fi

  dir=`mktemp -d /tmp/build-XXXX`

  msg "Building $pkg (in $dir)"
  cd $dir
  cabal sandbox init
  cabal install -j --reorder-goals --disable-documentation --datadir=$endpath/data --force-reinstalls $pkg

  msg "Saving $pkg binaries"
  cp .cabal-sandbox/bin/* $endpath/bin

  msg "Cleaning up"
  cd -
  rm -fr $dir
}

build_shared_binary "ghc-mod"
build_shared_binary "hasktags"
build_shared_binary "codex"
build_shared_binary "hscope"
build_shared_binary "pointfree"
build_shared_binary "pointful"
build_shared_binary "hoogle"

msg "Building Hoogle database..."
$endpath/bin/hoogle data

msg "Setting git to use fully-pathed vim for messages..."
git config --global core.editor $(which vim)
