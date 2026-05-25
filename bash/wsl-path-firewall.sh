#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# WSL PATH FIREWALL
# Ensures WSL never uses Windows binaries by accident.
# Removes /mnt/c and /mnt/d paths, verifies key tools, and prints diagnostics.
# Idempotent, reversible, and safe.
# -----------------------------------------------------------------------------

echo "[WSL-PATH-FIREWALL] Starting PATH sanitization..."

# Only run inside WSL
# shellcheck disable=SC2317
if ! grep -qi "microsoft" /proc/version; then
    echo "[WSL-PATH-FIREWALL] Not running inside WSL. Exiting."
    return 0 2>/dev/null || exit 0
fi


echo "[WSL-PATH-FIREWALL] WSL detected."

# Remove Windows paths
CLEAN_PATH=$(echo "$PATH" \
    | tr ':' '\n' \
    | grep -v "^/mnt/c/" \
    | grep -v "^/mnt/d/" \
    | paste -sd ':' -)

export PATH="$CLEAN_PATH"

echo "[WSL-PATH-FIREWALL] Windows paths removed."
echo "[WSL-PATH-FIREWALL] Current PATH entries:"
echo "$PATH" | tr ':' '\n'

# Verify Azure CLI
if command -v az >/dev/null 2>&1; then
    AZ_PATH=$(command -v az)
    echo "[WSL-PATH-FIREWALL] az resolved to: $AZ_PATH"

    if echo "$AZ_PATH" | grep -q "/mnt/c/"; then
        echo "[WSL-PATH-FIREWALL][WARNING] Windows Azure CLI still detected!"
        echo "[WSL-PATH-FIREWALL] Install Linux CLI: https://aka.ms/InstallAzureCLIDeb"
    else
        echo "[WSL-PATH-FIREWALL] Linux Azure CLI confirmed."
    fi
else
    echo "[WSL-PATH-FIREWALL] Azure CLI not found in PATH."
fi

echo "[WSL-PATH-FIREWALL] PATH sanitization complete."
# -----------------------------------------------------------------------------
