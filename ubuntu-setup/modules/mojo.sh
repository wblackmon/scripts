#!/usr/bin/env bash
set -euo pipefail

section "Mojo + pixi setup"

# pixi (environment manager) — aligns with your existing Mojo workflow
if ! command -v pixi >/dev/null 2>&1; then
  echo "Installing pixi..."
  run_cmd "curl -fsSL https://pixi.sh/install.sh | bash"
  # pixi usually installs into ~/.pixi/bin
  if ! grep -q 'PIXIPATH' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.pixi/bin:$PATH" # PIXIPATH' >> "$HOME/.bashrc"
  fi
else
  echo "pixi already installed"
fi

# Mojo via pixi (pattern, you can adjust to your exact channel)
if ! command -v mojo >/dev/null 2>&1; then
  echo "Installing Mojo via pixi (global)..."
  run_cmd "pixi global install mojo || true"
else
  echo "Mojo already installed"
fi

echo "Mojo + pixi baseline ready for WSL/Ubuntu + VS Code integration."
