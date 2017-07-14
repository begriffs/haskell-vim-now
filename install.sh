#!/usr/bin/env bash

PROGNAME=$(basename $0)
DEFAULT_REPO="https://github.com/begriffs/haskell-vim-now.git"
DEFAULT_GENERATE_HOOGLE_DB=true
DEFAULT_HVN_FULL_INSTALL=true
DEFAULT_DRY_RUN=false

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
  cd ${repo_path}
  if [ "$(git status -s)" ]; then
    ## Local repo has changes, prompt before overwriting them:
    read -p "Would you like to force a sync? THIS WILL REMOVE ANY LOCAL CHANGES!  [y/N]: " response
    case $response in
      [yY][eE][sS]|[yY])
        git reset --hard
      ;;
    esac
  fi
  git pull --rebase
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
  local FULL_INSTALL=$2
  local GENERATE_HOOGLE_DB=$3
  local DRY_RUN=$4
  local setup_path=${HVN_DEST}/scripts/setup.sh
  local setup_haskell_path=${HVN_DEST}/scripts/setup_haskell.hs

  . $setup_path || { \
    err "Failed to source ${setup_path}."
    err "Have you cloned from the correct repository?"
    exit 1
  }

  setup_tools
  setup_vim $HVN_DEST

  if [ "$FULL_INSTALL" == true ]
  then
    local ARG_NO_HOOGLE_DB="--no-hoogle"
    local ARG_NO_HELPER_BINS="--no-helper-bins"

    if [ "$GENERATE_HOOGLE_DB" == true ]
    then
      ARG_NO_HOOGLE_DB=
    fi

    if [ "$DRY_RUN" == false ]
    then
      ARG_NO_HELPER_BINS=
    fi

    if ! check_exist stack >/dev/null ; then
      err "Installer requires Stack."
      msg "Installation instructions: http://docs.haskellstack.org/en/stable/README/#how-to-install"
      exit 1
    fi

    local STACK_VER=$(stack --version | sed 's/^Version \([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/')
    if ! verlte '1.4.0' ${STACK_VER} ; then
      exit_err "Detected stack version \"${STACK_VER}\", however version 1.4.0 or later is required."
    fi

    stack $setup_haskell_path $ARG_NO_HOOGLE_DB $ARG_NO_HELPER_BINS ; RETCODE=$?
    [ ${RETCODE} -ne 0 ] && exit_err "setup_haskell.hs failed with error ${RETCODE}."
  fi

  setup_done $HVN_DEST
}

main() {
  local REPO_PATH=$1
  local FULL_INSTALL=$2
  local GENERATE_HOOGLE_DB=$3
  local DRY_RUN=$4
  local HVN_DEST="$(config_home)/haskell-vim-now"
  local HVN_DEPENDENCIES_DEST="$(config_home)/haskell-vim-now"

  install $REPO_PATH $HVN_DEST
  do_setup $HVN_DEST $FULL_INSTALL $GENERATE_HOOGLE_DB $DRY_RUN
}

function usage() {
  echo "Usage: $PROGNAME [--basic] [--repo <path>] [--no-hoogle]"
  echo ""
  echo "OPTIONS"
  echo "       --basic"
  echo "           Install only vim and plugins without haskell components."
  echo "       --repo <path>"
  echo "           Git repository to install from. The default is $DEFAULT_REPO."
  echo "       --no-hoogle"
  echo "           Disable Hoogle database generation. The default is $DEFAULT_GENERATE_HOOGLE_DB."
  echo "       --dry-run"
  echo "           Perform a dry run for the stack installs.  Primarily intended for testing."
  exit 1
}

# command line args override env vars
HVN_REPO=${HVN_REPO:=$DEFAULT_REPO}
HVN_GENERATE_HOOGLE_DB=${HVN_GENERATE_HOOGLE_DB:=$DEFAULT_GENERATE_HOOGLE_DB}
HVN_FULL_INSTALL=${HVN_FULL_INSTALL:=$DEFAULT_HVN_FULL_INSTALL}
HVN_DRY_RUN=${HVN_DRY_RUN:=$DEFAULT_DRY_RUN}

while test -n "$1"
do
  case $1 in
    --basic) shift; HVN_FULL_INSTALL=false; continue;;
    --repo) shift; HVN_REPO=$1; shift; continue;;
    --no-hoogle) shift; HVN_GENERATE_HOOGLE_DB=false; continue;;
    --dry-run) shift; HVN_DRY_RUN=true; continue;;
    *) usage;;
  esac
done

test -n "$HVN_REPO" || usage
main $HVN_REPO $HVN_FULL_INSTALL $HVN_GENERATE_HOOGLE_DB $HVN_DRY_RUN
