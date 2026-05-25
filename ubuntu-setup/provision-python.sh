#!/usr/bin/bash
set -euo pipefail

echo "=== Python Toolchain Provisioning (WSL Ubuntu) ==="

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "Ubuntu version detected: $UBUNTU_VERSION"

echo "Updating package index..."
sudo apt update -y

echo "Installing Python core packages..."
sudo apt install -y \
    python3 \
    python3-full \
    python3-venv \
    python3-pip \
    pipx

echo "Ensuring pipx path..."
pipx ensurepath

# Reload PATH for current session
export PATH="$HOME/.local/bin:$PATH"

echo "Installing pipx global tools (idempotent)..."

pipx install black || true
pipx install ruff || true
pipx install httpie || true
pipx install uv || true

echo
echo "=== Python Toolchain Installed Successfully ==="
echo
echo "Recommended per‑repo workflow:"
echo "  python3 -m venv .venv"
echo "  source .venv/bin/activate"
echo "  pip install -r requirements.txt"
echo
echo "This keeps system Python clean and ensures deterministic environments."
