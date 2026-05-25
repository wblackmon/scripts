#!/usr/bin/env bash

set -euo pipefail

MAX_RETRIES=5
SLEEP_BASE=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

delete_rg() {
    local rg="$1"
    local attempt=1

    while (( attempt <= MAX_RETRIES )); do
        log "Deleting resource group: $rg (attempt $attempt/$MAX_RETRIES)"

        if az group delete -n "$rg" --yes --verbose; then
            log "SUCCESS: Deleted $rg"
            return 0
        else
            log "WARNING: Failed to delete $rg (attempt $attempt)"
        fi

        # Exponential backoff
        sleep_time=$(( SLEEP_BASE * attempt ))
        log "Sleeping $sleep_time seconds before retry..."
        sleep "$sleep_time"

        ((attempt++))
    done

    log "ERROR: Exhausted retries for $rg"
    return 1
}

log "Fetching resource groups..."
mapfile -t groups < <(az group list --query "[?name!=''].name" -o tsv)

if (( ${#groups[@]} == 0 )); then
    log "No resource groups found."
    exit 0
fi

log "Found ${#groups[@]} resource groups."

for rg in "${groups[@]}"; do
    delete_rg "$rg"
done

log "All deletions attempted."
