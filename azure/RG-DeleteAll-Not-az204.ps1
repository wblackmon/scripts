# Variables
$MAX_RETRIES = 5
$SLEEP_BASE = 3

function Remove-RG {
    param (
        [string]$ResourceGroupName
    )

    $attempt = 1

    while ($attempt -le $MAX_RETRIES) {
        Write-Host "[$ResourceGroupName] Delete attempt $attempt of $MAX_RETRIES..."

        try {
            az group delete `
                --name $ResourceGroupName `
                --yes `
                --no-wait `
                --only-show-errors | Out-Null

            Write-Host "[$ResourceGroupName] Delete request accepted."
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message

            if ($errorMessage -match "ConnectionResetError\(10054") {
                Write-Host "[$ResourceGroupName] Detected transient 10054 connection reset."
                Write-Host "[$ResourceGroupName] Backing off before retry..."
                Start-Sleep -Seconds ($SLEEP_BASE * $attempt)
                $attempt++
                continue
            }

            Write-Host "[$ResourceGroupName] Non-retryable error:"
            Write-Host $errorMessage
            return $false
        }
    }

    Write-Host "[$ResourceGroupName] FAILED after $MAX_RETRIES attempts."
    return $false
}

# Main loop: Get all resource groups and delete only those NOT starting with "az204"
$resourceGroups = az group list --query "[].name" -o tsv

foreach ($rg in $resourceGroups) {
    $cleanRg = $rg.Trim()

    # Skip resource groups that start with az204 (case-insensitive)
    if ($cleanRg -match "^az204") {
        Write-Host "Skipping resource group (protected): '$cleanRg'"
        continue
    }

    Write-Host "Processing resource group for deletion: '$cleanRg'"
    Remove-RG -ResourceGroupName $cleanRg
}
