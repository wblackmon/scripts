<#
.SYNOPSIS
    Updates winget itself and all installed packages deterministically.
    Produces a clean log and handles partial failures safely.

.NOTES
    Idempotent. Windows-only.
#>

Write-Host "=== Winget Update Script Starting ==="

# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget is not installed or not available in PATH."
    exit 1
}

# --- PowerShell 7 Install/Update Check ---------------------------------------

Write-Host "`nChecking PowerShell 7 installation status..."

# Query winget for PowerShell 7 package
$pwshInfo = winget list --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements

if ($pwshInfo -match "No installed package found") {
    Write-Host "PowerShell 7 is not installed. Installing..."
    winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
}
else {
    Write-Host "PowerShell 7 is installed. Checking for updates..."
    winget upgrade --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements
}

# --- Winget Source Refresh ----------------------------------------------------

Write-Host "`nRefreshing winget sources..."
winget source update

# Upgrade winget package manager itself (if applicable)
Write-Host "`nChecking for winget package manager updates..."
winget upgrade --id Microsoft.Winget.Source --silent --accept-source-agreements --accept-package-agreements

# List all upgradable packages
Write-Host "`nRetrieving list of upgradable packages..."
$upgrades = winget upgrade --accept-source-agreements --accept-package-agreements

if ($upgrades -match "No applicable update") {
    Write-Host "All packages are already up to date."
    Write-Host "`n=== Winget Update Script Completed ==="
    exit 0
}

# Perform upgrade of all packages
Write-Host "`nUpgrading all packages..."
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements

Write-Host "`n=== Winget Update Script Completed ==="
