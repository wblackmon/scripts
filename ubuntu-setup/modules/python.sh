#!/usr/bin/env bash
set -euo pipefail

section "Installing Python toolchain"

# System Python (safe, apt-managed)
install_pkg python3
install_pkg python3-full
install_pkg python3-venv
install_pkg python3-pip

# pipx (Ubuntu 24.04 native package)
if ! command -v pipx >/dev/null 2>&1; then
  echo "Installing pipx (apt)..."
  run_cmd "sudo apt install -y pipx"
  run_cmd "pipx ensurepath || true"
else
  echo "pipx already installed"
fi

# Modern Python package manager (fast, venv-safe)
if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  run_cmd "curl -fsSL https://astral.sh/uv/install.sh | sh"
else
  echo "uv already installed"
fi

# Dev tools via pipx (never touches system Python)
run_cmd "pipx install black || true"
run_cmd "pipx install flake8 || true"
run_cmd "pipx install mypy || true"
run_cmd "pipx install pytest || true"
