#!/usr/bin/env bash
set -euo pipefail

section "Installing Ollama (WSL/Ubuntu)"

# ---------------------------------------------------------------------
# Ensure curl exists
# ---------------------------------------------------------------------
install_pkg curl

# ---------------------------------------------------------------------
# Install Ollama if missing
# ---------------------------------------------------------------------
if ! command -v ollama >/dev/null 2>&1; then
    echo "Installing Ollama..."

    # Official installer (safe, signed, stable)
    run_cmd "curl -fsSL https://ollama.com/install.sh | sh"

else
    echo "Ollama already installed"
fi

# ---------------------------------------------------------------------
# Ensure systemd service is running (WSL-compatible)
# ---------------------------------------------------------------------
echo "Starting Ollama service..."

# WSL systemd support (Ubuntu 22.04+)
if [[ -d /run/systemd/system ]]; then
    run_cmd "sudo systemctl enable ollama || true"
    run_cmd "sudo systemctl start ollama || true"
else
    echo "Systemd not active — using manual service start"
    run_cmd "sudo service ollama start || true"
fi

# ---------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------
echo "Verifying Ollama installation..."
if command -v ollama >/dev/null 2>&1; then
    ollama --version || true
else
    echo "ERROR: Ollama installation failed"
fi

echo "Ollama installation complete."
