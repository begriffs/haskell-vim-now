#!/usr/bin/env bash

# Text color
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
detail() { echo -e "	$@" 1>&2; }
verlte() {
  [ "$1" = `echo -e "$1\n$2" | sort -t '.' -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -n1` ]
}

system_type() {
  local platform
  case ${OSTYPE} in
    linux* ) platform="LINUX" ;;
    darwin* ) platform="OSX" ;;
    cygwin* ) platform="CYGWIN" ;;
    * ) platform="OTHER" ;;
  esac

  echo ${platform}
  return 0
}

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

package_manager() {
  local package_manager

  if command -v brew >/dev/null 2>&1 ; then
    package_manager="BREW"
  elif command -v dnf >/dev/null 2>&1 ; then
    package_manager="DNF"
  elif command -v yum >/dev/null 2>&1 ; then
    package_manager="YUM"
  elif command -v apt-get >/dev/null 2>&1 ; then
    package_manager="APT"
  elif command -v port >/dev/null 2>&1 ; then
    package_manager="PORT"
  else
    package_manager="OTHER"
  fi

  echo ${package_manager}
  return 0
}

# $1: package manager
# $2-: list of packages
package_install() {
  local pkgmgr=$1; shift
  msg "Installing system packages [$*] using [$pkgmgr]..."
  case ${pkgmgr} in
    BREW )
      msg "Installing with homebrew..."
      brew install $*
      ;;
    PORT )
      msg "Installing with port..."
      port install $*
      ;;
    APT )
      msg "Installing with apt-get..."
      sudo apt-get install --no-upgrade -y $*
      ;;
    DNF )
      msg "Installing with DNF..."
      sudo dnf install -yq $* # yum and dnf use same repos
      ;;
    YUM )
      msg "Installing with YUM..."
      sudo yum install -yq $*
      ;;
    OTHER )
      warn "No package manager detected. You may need to install required packages manually."
      ;;
    * )
      exit_err_report "setup.sh is not configured to handle ${pkgmgr} manager."
  esac
}

fix_path() {
  # $1 - path
  local return_path
  case $(system_type) in
    CYGWIN )
      return_path=$(cygpath -u "${1}" | tr -d '\r')
      ;;
    * )
      return_path=${1}
  esac

  echo ${return_path}
  return 0
}

check_exist() {
  local not_exist=()
  for prg; do
    if ! command -v ${prg} >/dev/null 2>&1; then
      not_exist+=("${prg}")
    fi
  done
  echo ${not_exist[@]}
  return ${#not_exist[@]}
}

exit_err() {
  err ${1}
  err "Aborting..."
  exit 1
}

exit_err_report() {
  err ${1}
  err "Please report at https://github.com/begriffs/haskell-vim-now/issues"
  err "Aborting..."
  exit 1
}

