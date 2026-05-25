#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# CONFIG
# ----------------------------------------
RG_NAME="rg-ai-demo"
LOCATION="eastus"
LOG_FILE="./provision.log"

# ----------------------------------------
# LOGGING
# ----------------------------------------
log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S')  $msg" | tee -a "$LOG_FILE"
}

# ----------------------------------------
# AZURE HELPERS
# ----------------------------------------

ensure_az_login() {
    if ! az account show &>/dev/null; then
        log "No active Azure login detected. Initiating login..."
        az login --output none
        log "Azure login successful"
    else
        log "Azure login already active"
    fi
}

ensure_rg() {
    log "Checking if resource group '$RG_NAME' exists..."
    if az group exists --name "$RG_NAME" | grep -q true; then
        log "Resource group '$RG_NAME' already exists — skipping creation"
    else
        log "Creating resource group '$RG_NAME' in '$LOCATION'"
        az group create \
            --name "$RG_NAME" \
            --location "$LOCATION" \
            --output none
        log "Resource group created"
    fi
}

create_storage_account() {
    local sa_name="$1"

    log "Checking if storage account '$sa_name' exists..."
    if az storage account show -g "$RG_NAME" -n "$sa_name" &>/dev/null; then
        log "Storage account '$sa_name' already exists — skipping creation"
    else
        log "Creating storage account '$sa_name'"
        az storage account create \
            --name "$sa_name" \
            --resource-group "$RG_NAME" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --kind StorageV2 \
            --output none
        log "Storage account created"
    fi
}

create_app_insights() {
    local ai_name="$1"

    log "Checking if App Insights '$ai_name' exists..."
    if az monitor app-insights component show -g "$RG_NAME" -a "$ai_name" &>/dev/null; then
        log "App Insights '$ai_name' already exists — skipping creation"
    else
        log "Creating App Insights '$ai_name'"
        az monitor app-insights component create \
            --app "$ai_name" \
            --location "$LOCATION" \
            --resource-group "$RG_NAME" \
            --application-type web \
            --output none
        log "App Insights created"
    fi
}

# ----------------------------------------
# MAIN WORKFLOW
# ----------------------------------------

log "=== Azure Provisioning Script Started ==="

ensure_az_login
ensure_rg
create_storage_account "st${RG_NAME//-/}"
create_app_insights "ai-${RG_NAME}"

log "=== Provisioning Completed Successfully ==="
