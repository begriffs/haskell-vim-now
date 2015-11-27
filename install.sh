#!/usr/bin/env bash
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

install() {
  HVN_DEST="$(config_home)/haskell-vim-now"

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
    msg "Installing Haskell-Vim-Now..."
    git clone https://github.com/begriffs/haskell-vim-now.git ${HVN_DEST}

    return 0
  fi

  # Quick update to make sure we execute correct update procedure
  msg "Syncing Haskell-Vim-Now with upstream..."
  if ! update_pull ${HVN_DEST} ; then
    err "Sync (git pull) failed. Aborting..."
    exit 1;
  fi
}

main() {
  install
  . ${HVN_DEST}/scripts/setup.sh
  setup ${HVN_DEST}
}

main
