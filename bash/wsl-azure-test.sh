#!/usr/bin/env bash
set -euo pipefail

echo "====================================================="
echo "   WayneOS WSL Azure CLI Connectivity Test"
echo "====================================================="

# Helper for colored output
pass() { echo -e "\e[32m✔ $1\e[0m"; }
fail() { echo -e "\e[31m✘ $1\e[0m"; }

echo ""
echo "=== 1. Checking Azure CLI installation ==="
if command -v az >/dev/null 2>&1; then
    pass "Azure CLI is installed: $(az version --output json | jq -r '."azure-cli"')"
else
    fail "Azure CLI is NOT installed inside WSL."
    echo "Install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    exit 1
fi

echo ""
echo "=== 2. Checking Azure CLI login status ==="
if az account show >/dev/null 2>&1; then
    SUB=$(az account show --query name -o tsv)
    pass "Logged in to Azure: $SUB"
else
    fail "Not logged in to Azure."
    echo "Run: az login --use-device-code"
    exit 1
fi

echo ""
echo "=== 3. Checking access token validity ==="
if az account get-access-token >/dev/null 2>&1; then
    pass "Access token retrieved successfully."
else
    fail "Failed to retrieve access token."
    exit 1
fi

echo ""
echo "=== 4. Checking subscription list ==="
if az account list --output table >/dev/null 2>&1; then
    pass "Subscription list retrieved."
else
    fail "Unable to list subscriptions."
    exit 1
fi

echo ""
echo "=== 5. Checking Azure Resource Manager endpoint ==="
if curl -Is https://management.azure.com | head -n 1 | grep -q "200\|301\|302"; then
    pass "ARM endpoint reachable."
else
    fail "Cannot reach ARM endpoint."
    echo "Possible DNS, firewall, or proxy issue."
fi

echo ""
echo "=== 6. Checking DNS resolution ==="
if getent hosts management.azure.com >/dev/null 2>&1; then
    pass "DNS resolution works."
else
    fail "DNS resolution failed for management.azure.com."
fi

echo ""
echo "=== 7. Checking network connectivity (ping) ==="
if ping -c 1 management.azure.com >/dev/null 2>&1; then
    pass "Ping successful."
else
    fail "Ping failed (may be blocked, but not fatal)."
fi

echo ""
echo "=== 8. Checking Azure Resource Groups ==="
if az group list --output table >/dev/null 2>&1; then
    pass "Resource group query succeeded."
else
    fail "Failed to query resource groups."
fi

echo ""
echo "====================================================="
echo "   Azure CLI Connectivity Test Complete"
echo "====================================================="
