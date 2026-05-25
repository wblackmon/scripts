<#
.SYNOPSIS
    Updates core developer tools using winget and built-in commands.
    Covers: winget, Python, .NET SDK, Node, Git, Azure CLI, PowerShell 7, VS Code.
    Safe, deterministic, idempotent.

.NOTES
    .NET Framework cannot be updated via script — Windows Update only.
#>

Write-Host "=== Developer Machine Update Script Starting ===`n"

# -------------------------------
# 1. Update Winget Sources
# -------------------------------
Write-Host "Refreshing winget sources..."
winget source update

# -------------------------------
# 2. Update Winget Itself
# -------------------------------
Write-Host "`nUpdating winget package manager (if needed)..."
winget upgrade --id Microsoft.Winget.Source --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 3. Update ALL Winget Packages
# -------------------------------
Write-Host "`nUpgrading all winget packages..."
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 4. Update Python (if installed)
# -------------------------------
Write-Host "`nChecking for Python updates..."
winget upgrade Python --all --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 5. Update .NET SDKs (modern .NET)
# -------------------------------
Write-Host "`nUpdating .NET SDKs..."
winget upgrade Microsoft.DotNet* --all --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 6. Update Node.js (if installed)
# -------------------------------
Write-Host "`nUpdating Node.js..."
winget upgrade OpenJS.NodeJS* --all --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 7. Update Git
# -------------------------------
Write-Host "`nUpdating Git..."
winget upgrade --id Git.Git --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 8. Update Azure CLI
# -------------------------------
Write-Host "`nUpdating Azure CLI..."
winget upgrade --id Microsoft.AzureCLI --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 9. Update PowerShell 7
# -------------------------------
Write-Host "`nUpdating PowerShell 7..."
winget upgrade --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements

# -------------------------------
# 10. Update VS Code
# -------------------------------
Write-Host "`nUpdating Visual Studio Code..."
winget upgrade --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n=== Developer Machine Update Script Complete ==="
