
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
            # Attempt to delete the resource group
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

            # Check for transient 10054 error
            if ($errorMessage -match "ConnectionResetError\(10054") {
                Write-Host "[$ResourceGroupName] Detected transient 10054 connection reset."
                Write-Host "[$ResourceGroupName] Backing off before retry..."
                Start-Sleep -Seconds ($SLEEP_BASE * $attempt)
                $attempt++
                continue
            }

            # Non-retryable error
            Write-Host "[$ResourceGroupName] Non-retryable error:"
            Write-Host $errorMessage
            return $false
        }
    }

    Write-Host "[$ResourceGroupName] FAILED after $MAX_RETRIES attempts."
    return $false
}

# Main loop: Get all resource groups and delete them
$resourceGroups = az group list --query "[].name" -o tsv

foreach ($rg in $resourceGroups) {
    $cleanRg = $rg.Trim()
    Write-Host "Processing resource group: '$cleanRg'"
    Remove-RG -ResourceGroupName $cleanRg
}
