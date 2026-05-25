#!/usr/bin/env bash
set -euo pipefail

ensure_apt_updated
section "Installing core utilities"

install_pkg curl
install_pkg wget
install_pkg unzip
install_pkg ca-certificates
install_pkg gnupg
install_pkg lsb-release
install_pkg software-properties-common
install_pkg p7zip-full
install_pkg p7zip-rar
