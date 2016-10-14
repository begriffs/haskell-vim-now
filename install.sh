#!/usr/bin/env bash

PROGNAME=$(basename $0)
DEFAULT_REPO="https://github.com/begriffs/haskell-vim-now.git"

if which tput >/dev/null 2>&1; then
    ncolors=$(tput colors)
fi

if [ -t 1 ] && [ -n "${ncolors}" ] && [ "${ncolors}" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BOLD=""
  NORMAL=""
fi

msg() { echo -e "${GREEN}--- $@${NORMAL}" 1>&2; }
warn() { echo -e "${YELLOW}${BOLD}--> $@${NORMAL}" 1>&2; }
err() { echo -e "${RED}${BOLD}*** $@${NORMAL}" 1>&2; }

config_home() {
  local cfg_home
  if [ -z ${XDG_CONFIG_HOME+x} ]; then
    cfg_home="${HOME}/.config"
  else
    cfg_home=${XDG_CONFIG_HOME}
  fi
  echo ${cfg_home}
  return 0
}

update_pull() {
  local repo_path=$1
  cd ${repo_path} && git pull --rebase
  return $?
}

check_repo_change() {
  local REPO_PATH=$1
  local HVN_DEST=$2
  local orig_repo

  orig_repo=$(cd $HVN_DEST && git config --get remote.origin.url) || exit 1
  if test -z "$orig_repo" -o "$orig_repo" != $REPO_PATH
  then
    err "The source repository path [$REPO_PATH] does not match the"
    err "origin repository of the existing installation [$orig_repo]."
    err "Please remove the existing installation [$HVN_DEST] and try again."
    exit 1
  fi
}

install() {
  local REPO_PATH=$1
  local HVN_DEST=$2

  if [ -e ${HVN_DEST} ]; then
    warn "Existing Haskell-Vim-Now installation detected at ${HVN_DEST}."
  elif [ -e ${HOME}/.haskell-vim-now ]; then
    warn "Old Haskell-Vim-Now installation detected."
    msg "Migrating existing installation to ${HVN_DEST}..."
    mv -f ${HOME}/.haskell-vim-now ${HVN_DEST}
    mv -f ${HOME}/.vimrc.local ${HVN_DEST}/vimrc.local
    mv -f ${HOME}/.vimrc.local.pre ${HVN_DEST}/vimrc.local.pre
    sed -i.bak "s/Plugin '/Plug '/g" ${HOME}/.vim.local/bundles.vim
    mv -f ${HOME}/.vim.local/bundles.vim ${HVN_DEST}/plugins.vim
    rm -f ${HOME}/.vim.local/bundles.vim.bak
    rmdir ${HOME}/.vim.local >/dev/null
  else
    warn "No previous installations detected."
    msg "Installing Haskell-Vim-Now from ${REPO_PATH} ..."
    mkdir -p $(config_home)
    git clone ${REPO_PATH} ${HVN_DEST} || exit 1

    return 0
  fi

  check_repo_change ${REPO_PATH} ${HVN_DEST}
  # Quick update to make sure we execute correct update procedure
  msg "Syncing Haskell-Vim-Now with upstream..."
  if ! update_pull ${HVN_DEST} ; then
    err "Sync (git pull) failed. Aborting..."
    exit 1;
  fi
}

do_setup() {
  local HVN_DEST=$1
  local BASIC_ONLY=$2
  local setup_path=${HVN_DEST}/scripts/setup.sh

  . $setup_path || { \
    err "Failed to source ${setup_path}."
    err "Have you cloned from the correct repository?"
    exit 1
  }

  setup_tools
  setup_vim $HVN_DEST

  if test -z "$BASIC_ONLY"
  then
    setup_haskell $HVN_DEST
  fi

  setup_done $HVN_DEST
}

main() {
  local REPO_PATH=$1
  local BASIC_ONLY=$2
  local HVN_DEST="$(config_home)/haskell-vim-now"

  install $REPO_PATH $HVN_DEST
  do_setup $HVN_DEST $BASIC_ONLY
}

function usage() {
  echo "Usage: $PROGNAME [--basic] [--repo <path>]"
  echo ""
  echo "OPTIONS"
  echo "       --basic"
  echo "           Install only vim and plugins without haskell components."
  echo "       --repo <path>"
  echo "           Git repository to install from. The default is $DEFAULT_REPO."
  exit 1
}

# $1: envvar
check_boolean_var() {
  local var=$(eval "echo \$$1")
  if test -n "$var" -a "$var" != y
  then
    >&2 echo "Error: Boolean envvar [$1] can only be empty or 'y'"
    exit 1
  fi
  echo "ENV: [$1=$var]"
}

# command line args override env vars
HVN_REPO=${HVN_REPO:=$DEFAULT_REPO}
check_boolean_var HVN_INSTALL_BASIC

while test -n "$1"
do
  case $1 in
    --basic) shift; HVN_INSTALL_BASIC=y; continue;;
    --repo) shift; HVN_REPO=$1; shift; continue;;
    *) usage;;
  esac
done

test -n "$HVN_REPO" || usage
main $HVN_REPO $HVN_INSTALL_BASIC
