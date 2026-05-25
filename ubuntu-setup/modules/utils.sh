#!/usr/bin/env bash
set -euo pipefail

section() {
  echo ""
  echo "========== $1 =========="
  echo ""
}

run_cmd() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

install_pkg() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "$pkg already installed"
  else
    echo "Installing $pkg..."
    run_cmd "sudo apt-get install -y \"$pkg\""
  fi
}

ensure_apt_updated() {
  if [[ "${APT_UPDATED:-0}" -eq 0 ]]; then
    section "Updating system"
    run_cmd "sudo apt-get update -y"
    run_cmd "sudo apt-get upgrade -y"
    APT_UPDATED=1
  fi
}

export PATH="$HOME/.local/bin:$PATH"
