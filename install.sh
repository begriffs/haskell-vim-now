#!/usr/bin/env bash

msg() { echo "--- $@" 1>&2; }
detail() { echo "	$@" 1>&2; }
verlte() {
  [ "$1" = `echo -e "$1\n$2" | sort -t '.' -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -n1` ]
}

for i in ctags git ghc cabal make vim curl-config happy; do
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

if [ ! -e $HOME/.vim/bundle/Vundle.vim ]; then
  msg "Installing Vundle"
  git clone https://github.com/gmarik/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
fi

msg "Installing plugins using Vundle..."
vim -T dumb -E -u $endpath/.vimrc +PluginInstall! +PluginClean! +qall

msg "Building vimproc.vim"
make -C ~/.vim/bundle/vimproc.vim

msg "Updating cabal package list"
cabal update

msg "Installing git-hscope"
mkdir -p $endpath/bin
cp $endpath/git-hscope $endpath/bin

function create_stackage_sandbox {
  msg "Initializing stackage sandbox in $dir"
  dir=$1
  cd $dir
  cabal sandbox init

  if verlte '7.10' $GHC_VER ; then
    curl -L https://beta.stackage.org/nightly/cabal.config > cabal.config
  else
    curl -L https://www.stackage.org/lts/cabal.config > cabal.config
  fi

  cd -
}

function build_shared_binary {
  dir=$1
  pkg=$2
  constraint=$3

  if [ -e $endpath/bin/$pkg ]
  then
    msg "$pkg is already installed, skipping build"
    return
  fi

  msg "Building $pkg (in $dir)"
  cd $dir
  cabal install -j --reorder-goals --disable-documentation --datadir=$endpath/data --force-reinstalls "${constraint:-$pkg}"

  msg "Saving $pkg binaries"
  mv .cabal-sandbox/bin/* $endpath/bin
  cd -
}

sb=`mktemp -d ${TMPDIR:-/tmp}/build-XXXX`
create_stackage_sandbox $sb

for i in ghc-mod hasktags codex hscope pointfree pointful hoogle stylish-haskell; do
  build_shared_binary $sb $i
done

rm -fr $sb

msg "Building Hoogle database..."
$endpath/bin/hoogle data

msg "Setting git to use fully-pathed vim for messages..."
git config --global core.editor $(which vim)

msg "Configuring codex to search in sandboxes..."
cat > $HOME/.codex <<EOF
hackagePath: .cabal-sandbox/packages/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF
