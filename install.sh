#!/usr/bin/env bash

msg() { echo "--- $@" 1>&2; }
detail() { echo "	$@" 1>&2; }
verlte() {
  [ "$1" = `echo -e "$1\n$2" | sort -t '.' -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -n1` ]
}


command -v stack >/dev/null
if [ $? -ne 0 ] ; then
  msg "Installer requires Stack. Installation instructions:"
  msg "https://github.com/commercialhaskell/stack#how-to-install"
  exit 1
fi

for i in ctags git make vim curl-config; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    msg "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')

if ! verlte '7.4' $VIM_VER ; then
  msg "Vim version 7.4 or later is required. Aborting."
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

msg "Adding extra stack deps if needed"
sed -i .bak 's/extra-deps: \[\]/extra-deps: [cabal-helper-0.6.0.0, pure-cdb-0.1.1]/' ~/.stack/global/stack.yaml

msg "Installing helper binaries"
stack --resolver nightly install ghc-mod hasktags codex hscope pointfree pointful hoogle stylish-haskell

msg "Installing git-hscope"
cp $endpath/git-hscope ~/.local/bin

msg "Building Hoogle database..."
~/.local/bin/hoogle data

msg "Setting git to use fully-pathed vim for messages..."
git config --global core.editor $(which vim)

msg "Configuring codex to search in stack..."
cat > $HOME/.codex <<EOF
hackagePath: $HOME/.stack/indices/Hackage/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF
