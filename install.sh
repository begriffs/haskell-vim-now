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


msg "Installing system package dependencies"
command -v brew >/dev/null
if [ $? -eq 0 ] ; then
  msg "homebrew detected"
  brew install git make vim ctags
fi
command -v apt-get >/dev/null
if [ $? -eq 0 ] ; then
  msg "apt-get detected"
  sudo apt-get install -y git make vim libcurl4-openssl-dev exuberant-ctags fonts-powerline
fi
command -v dnf >/dev/null
if [ $? -eq 0 ] ; then
  msg "dnf detected"
  sudo dnf install -y git make vim ctags libcurl-devel zlib-devel powerline
  DNF=1
fi
command -v yum >/dev/null
if [ $? -eq 0 ] && [ $DNF -ne 1 ] ; then
  msg "yum detected"
  sudo yum install -y git make vim ctags libcurl-devel zlib-devel powerline
fi

for i in ctags curl-config git make vim; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    msg "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')

if ! verlte '7.4' $VIM_VER ; then
  msg "Detected vim version \"$VIM_VER\""
  msg "However version 7.4 or later is required. Aborting."
  exit 1
fi

msg "Testing for broken Ruby interface in vim"
vim --version | grep -q +ruby
if [ $? -eq 0 ] ; then
  vim -T dumb --cmd "ruby puts RUBY_VERSION" --cmd qa!
  if [ $? -ne 0 ] ; then
    msg "The Ruby interface is broken on your installation of vim."
    msg "Reinstall or recompile vim."
    msg ""
    msg "If you're on OS X, try the following:"
    detail "rvm use system"
    detail "brew reinstall vim"
    msg ""
    msg "If nothing helped, please report at https://github.com/begriffs/haskell-vim-now/issues/new"
    exit 1
  fi
fi

if [ -z ${XDG_CONFIG_HOME+x} ]; then
  XDG_CONFIG_HOME="$HOME/.config"
  msg "XDG_CONFIG_HOME is not set, using $XDG_CONFIG_HOME"
else
  msg "XDG_CONFIG_HOME is set to $XDG_CONFIG_HOME"
fi
DESTINATION="$XDG_CONFIG_HOME/haskell-vim-now"

msg "Setting up GHC if needed"
stack setup --verbosity warning
STACK_BIN_PATH=$(stack --verbosity 0 path --local-bin-path)
STACK_GLOBAL=$(stack --verbosity 0 path --global-stack-root)

msg "Adding extra stack deps if needed"
DEPS_REGEX='s/extra-deps: \[\]/extra-deps: [cabal-helper-0.6.1.0, pure-cdb-0.1.1]/'
# upgrade from a previous installation
DEPS_UPGRADE_REGEX='s/cabal-helper-0.5.3.0/cabal-helper-0.6.1.0/g'
sed -i.bak "$DEPS_REGEX" $STACK_GLOBAL/global-project/stack.yaml || sed -i.bak "$DEPS_REGEX" $STACK_GLOBAL/global/stack.yaml
sed -i.bak "$DEPS_UPGRADE_REGEX" $STACK_GLOBAL/global-project/stack.yaml || sed -i.bak "$DEPS_UPGRADE_REGEX" $STACK_GLOBAL/global/stack.yaml
rm -f $STACK_GLOBAL/global/stack.yaml.bak $STACK_GLOBAL/global-project/stack.yaml.bak

msg "Installing helper binaries"
stack --resolver nightly install ghc-mod hdevtools hasktags codex hscope pointfree pointful hoogle stylish-haskell --verbosity warning

msg "Installing git-hscope"
cp $DESTINATION/git-hscope $STACK_BIN_PATH

msg "Building Hoogle database..."
$STACK_BIN_PATH/hoogle data

msg "Setting git to use fully-pathed vim for messages..."
git config --global core.editor $(which vim)

msg "Configuring codex to search in stack..."
cat > $HOME/.codex <<EOF
hackagePath: $STACK_GLOBAL/indices/Hackage/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF

## Vim configuration steps

if [ -e $HOME/.haskell-vim-now ]; then
  msg "Migrating existing installation to $DESTINATION"
  mv -fu $HOME/.haskell-vim-now $DESTINATION
  mv -fu $HOME/.vimrc.local $DESTINATION/vimrc.local
  mv -fu $HOME/.vimrc.local.pre $DESTINATION/vimrc.local.pre
  sed -i.bak "s/Plugin/Plug/g" $HOME/.vim.local/bundles.vim
  mv -fu $HOME/.vim.local/bundles.vim $DESTINATION/plugins.local
  rm -f $HOME/.vim.local/bundles.vim.bak
fi

if [ ! -e $DESTINATION/.git ]; then
  msg "Cloning begriffs/haskell-vim-now"
  git clone https://github.com/begriffs/haskell-vim-now.git $DESTINATION
else
  msg "Existing installation detected"
  msg "Updating from begriffs/haskell-vim-now"
  cd $DESTINATION && git pull
fi

if [ -e ~/.vim/colors ]; then
  msg "Preserving color scheme files"
  cp -R ~/.vim/colors $DESTINATION/colors
fi

today=`date +%Y%m%d_%H%M%S`
msg "Backing up current vim config using timestamp $today"
if [ ! -e $DESTINATION/backup ]; then
  mkdir $DESTINATION/backup
fi
for i in .vim .vimrc .gvimrc; do [ -e $HOME/$i ] && mv $HOME/$i $DESTINATION/backup/$i.$today && detail "$DESTINATION/backup/$i.$today"; done

if [ ! -e $DESTINATION/.vim/autoload/plug.vim ]; then
  msg "Installing vim-plug"
  curl -fLo $DESTINATION/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

msg "Creating symlinks"
detail "~/.vimrc -> $DESTINATION/.vimrc"
detail "~/.vim   -> $DESTINATION/.vim"
ln -sf $DESTINATION/.vimrc $HOME/.vimrc
ln -sf $DESTINATION/.vim $HOME/.vim

msg "Installing plugins using vim-plug..."
vim -T dumb -E -u $DESTINATION/.vimrc +PlugUpgrade +PlugUpdate +PlugClean! +qall

if [[ "$OSTYPE" =~ ^darwin ]]; then
  msg "NOTE FOR OS X USERS"
  msg ""
  msg "Configure your terminal to use a font that supports Powerline symbols:"
  msg "https://github.com/powerline/fonts"
fi
