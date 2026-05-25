#!/usr/bin/env bash
set -euo pipefail

section "Installing Node.js 20 LTS"

if ! command -v node >/dev/null 2>&1; then
  echo "Configuring NodeSource for Node 20..."
  run_cmd "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  run_cmd "sudo apt-get install -y nodejs"
else
  echo "Node.js already installed"
fi
