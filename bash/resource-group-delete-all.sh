#!/bin/bash

MAX_RETRIES=5
SLEEP_BASE=3

delete_rg() {
    local rg="$1"
    local attempt=1

    while (( attempt <= MAX_RETRIES )); do
        echo "[$rg] Delete attempt $attempt of $MAX_RETRIES..."

        # Capture stderr so we can inspect the error
        error_output=$(az group delete \
            --name "$rg" \
            --yes \
            --no-wait \
            --only-show-errors 2>&1)

        exit_code=$?

        # Success path
        if [[ $exit_code -eq 0 ]]; then
            echo "[$rg] Delete request accepted."
            return 0
        fi

        # Check for the specific transient 10054 reset
        if echo "$error_output" | grep -q "ConnectionResetError(10054"; then
            echo "[$rg] Detected transient 10054 connection reset."
            echo "[$rg] Backing off before retry..."
            sleep $(( SLEEP_BASE * attempt ))
            ((attempt++))
            continue
        fi

        # Any other error is non-retryable
        echo "[$rg] Non-retryable error:"
        echo "$error_output"
        return 1
    done

    echo "[$rg] FAILED after $MAX_RETRIES attempts."
    return 1
}

# Main loop
az group list --query "[].name" -o tsv | while IFS= read -r rg; do
    clean_rg=$(echo "$rg" | tr -d '\r' | xargs)

    echo "Processing resource group: '$clean_rg'"
    delete_rg "$clean_rg"
done
