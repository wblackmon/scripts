#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
#  OLLAMA UNINSTALL SCRIPT (UBUNTU + WSL)
#  Deterministic • Idempotent • Log-rich • Safe re-runs
#  Synchronized with WayneOS Provisioning Script
# ---------------------------------------------------------

log() { echo -e "\n[UNINSTALL] $1"; }
err() { echo -e "\n[ERROR] $1" >&2; exit 1; }

[[ $EUID -ne 0 ]] && err "Run as root: sudo $0"

IS_WSL=false
if grep -qi "microsoft" /proc/version; then
    IS_WSL=true
    log "WSL environment detected."
fi

# ---------------------------------------------------------
# 1. STOP & DISABLE SYSTEMD SERVICE (IF NOT WSL)
# ---------------------------------------------------------
if [[ "$IS_WSL" == false ]]; then
    if systemctl list-unit-files | grep -q "^ollama.service"; then
        log "Stopping Ollama service..."
        systemctl stop ollama.service || true

        log "Disabling Ollama service..."
        systemctl disable ollama.service || true
    else
        log "Ollama systemd service not found. Skipping."
    fi
else
    log "Skipping systemd removal (WSL environment)."
fi

# ---------------------------------------------------------
# 2. REMOVE OLLAMA PACKAGE
# ---------------------------------------------------------
if dpkg -l | grep -q "^ii  ollama "; then
    log "Removing Ollama package..."
    apt-get remove -y ollama
else
    log "Ollama package not installed. Skipping."
fi

# ---------------------------------------------------------
# 3. REMOVE APT REPOSITORY
# ---------------------------------------------------------
REPO_FILE="/etc/apt/sources.list.d/ollama.list"

if [[ -f "$REPO_FILE" ]]; then
    log "Removing Ollama APT repository..."
    rm -f "$REPO_FILE"
else
    log "Ollama APT repository not found. Skipping."
fi

log "Updating apt package lists..."
apt-get update -y

# ---------------------------------------------------------
# 4. REMOVE SYSTEMD OVERRIDES (IF ANY)
# ---------------------------------------------------------
OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"

if [[ -d "$OVERRIDE_DIR" ]]; then
    log "Removing systemd override directory..."
    rm -rf "$OVERRIDE_DIR"
else
    log "No systemd override directory found. Skipping."
fi

# ---------------------------------------------------------
# 5. REMOVE MODEL DATA & CACHE
# ---------------------------------------------------------
DATA_DIR="/usr/share/ollama"
CACHE_DIR="/var/lib/ollama"

if [[ -d "$DATA_DIR" ]]; then
    log "Removing Ollama data directory: $DATA_DIR"
    rm -rf "$DATA_DIR"
else
    log "No Ollama data directory found. Skipping."
fi

if [[ -d "$CACHE_DIR" ]]; then
    log "Removing Ollama cache directory: $CACHE_DIR"
    rm -rf "$CACHE_DIR"
else
    log "No Ollama cache directory found. Skipping."
fi

# ---------------------------------------------------------
# 6. REMOVE VS CODE EXTENSIONS (SYNCED WITH WAYNEOS PROVISIONING)
# ---------------------------------------------------------
if command -v code >/dev/null 2>&1; then
    log "Removing VS Code extensions related to Ollama / Continue.dev / AI tooling..."

    # Continue.dev
    code --uninstall-extension Continue.continue || true

    # Python stack (installed in provisioning)
    code --uninstall-extension ms-python.python || true
    code --uninstall-extension ms-python.vscode-pylance || true

    # .NET stack (synced with provisioning)
    code --uninstall-extension ms-dotnettools.csharp || true
    code --uninstall-extension ms-dotnettools.csdevkit || true

    # YAML (synced with provisioning)
    code --uninstall-extension redhat.vscode-yaml || true

    # GitLens (synced with provisioning)
    code --uninstall-extension eamodio.gitlens || true

    # ShellCheck (optional)
    code --uninstall-extension timonwong.shellcheck || true

    # Azure tooling (synced with provisioning)
    code --uninstall-extension ms-vscode.azure-account || true
    code --uninstall-extension ms-azuretools.vscode-bicep || true
    code --uninstall-extension ms-azuretools.vscode-docker || true
    code --uninstall-extension ms-azuretools.vscode-azurefunctions || true

    # Kubernetes tooling (synced with provisioning)
    code --uninstall-extension ms-kubernetes-tools.vscode-kubernetes-tools || true

    # Icons + formatting (synced with provisioning)
    code --uninstall-extension PKief.material-icon-theme || true
    code --uninstall-extension esbenp.prettier-vscode || true

    log "VS Code extensions removed (or were not installed)."
else
    log "VS Code not detected. Skipping extension removal."
fi

# ---------------------------------------------------------
# 7. REMOVE WSL VS CODE SERVER ARTIFACTS (SAFE)
# ---------------------------------------------------------
if [[ "$IS_WSL" == true ]]; then
    VSCODE_SERVER="$HOME/.vscode-server/extensions"
    if [[ -d "$VSCODE_SERVER" ]]; then
        log "Removing VS Code Server extension cache entries for Ollama/Continue.dev..."
        rm -rf "$VSCODE_SERVER"/continue* || true
        rm -rf "$VSCODE_SERVER"/ms-python* || true
        rm -rf "$VSCODE_SERVER"/ms-dotnettools* || true
        rm -rf "$VSCODE_SERVER"/eamodio.gitlens* || true
        rm -rf "$VSCODE_SERVER"/redhat.vscode-yaml* || true
        rm -rf "$VSCODE_SERVER"/ms-azuretools* || true
        rm -rf "$VSCODE_SERVER"/ms-kubernetes-tools* || true
    else
        log "No VS Code Server extension directory found. Skipping."
    fi
fi

# ---------------------------------------------------------
# 8. DONE
# ---------------------------------------------------------
log "Ollama and related tooling fully uninstalled."
