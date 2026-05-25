<#
================================================================================
 Install-AzureDevTools.ps1
 Version: 1.0.0
 Author: Wayne (refined with Copilot)

 PURPOSE:
   Installs Azure CLI, Bicep CLI, and Azure Functions Core Tools using
   deterministic, idempotent, safe operations.

 SAFETY:
   • No registry edits
   • No UAC changes
   • No destructive system modifications
   • All installers wrapped in try/catch
   • Verifies installation before reporting success
   • Handles winget catalog drift for Functions Core Tools
================================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Cosmetic helpers
# ---------------------------------------------------------------------------

function Write-Section { param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Yellow
}

function Write-Step { param([string]$Message)
    Write-Host " → $Message" -ForegroundColor Cyan
}

function Write-Success { param([string]$Message)
    Write-Host "   ✔ $Message" -ForegroundColor Green
}

function Write-Warn { param([string]$Message)
    Write-Host "   ⚠ $Message" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# Ensure winget exists
# ---------------------------------------------------------------------------

function Assert-winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required but not found. Install Windows App Installer from the Store."
    }
}

# ---------------------------------------------------------------------------
# Azure Tooling Installer (standalone)
# ---------------------------------------------------------------------------

function Install-AzureDevTools {

    Write-Section "Installing Azure developer tools"

    Assert-winget

    # -----------------------------------------------------------------------
    # Azure CLI
    # -----------------------------------------------------------------------
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Step "Installing Azure CLI..."
        try {
            winget install -e --id Microsoft.AzureCLI -h `
                --accept-package-agreements --accept-source-agreements
        }
        catch {
            Write-Warn "Azure CLI install failed: $($_.Exception.Message)"
        }
    }

    if (Get-Command az -ErrorAction SilentlyContinue) {
        Write-Success "Azure CLI available"
    }
    else {
        Write-Warn "Azure CLI not detected; skipping Bicep + Functions Core Tools."
        return
    }

    # -----------------------------------------------------------------------
    # Refresh PATH
    # -----------------------------------------------------------------------
    Write-Step "Refreshing PATH for current session..."
    try {
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
    catch {
        Write-Warn "Failed to refresh PATH (non-fatal): $($_.Exception.Message)"
    }

    # -----------------------------------------------------------------------
    # Bicep CLI
    # -----------------------------------------------------------------------
    Write-Step "Installing Bicep CLI via 'az bicep install'..."
    try {
        az bicep install
    }
    catch {
        Write-Warn "Bicep install command failed: $($_.Exception.Message)"
    }

    if (az bicep version 2>$null) {
        Write-Success "Bicep installed"
    }
    else {
        Write-Warn "Bicep install attempted but Bicep is not available."
    }

    # -----------------------------------------------------------------------
    # Azure Functions Core Tools (catalog drift–safe)
    # -----------------------------------------------------------------------
    Write-Step "Installing Azure Functions Core Tools..."

    $funcIds = @(
        "Microsoft.Azure.FunctionsCoreTools",
        "Microsoft.Azure.FunctionsCoreTools.4",
        "Microsoft.Azure.FunctionsCoreTools.3"
    )

    $funcInstalled = $false

    foreach ($id in $funcIds) {
        try {
            winget install -e --id $id -h `
                --accept-package-agreements --accept-source-agreements

            if (func --version 2>$null) {
                Write-Success "Functions Core Tools installed"
                $funcInstalled = $true
                break
            }
        }
        catch {
            # Try next ID
        }
    }

    if (-not $funcInstalled) {
        Write-Warn "Functions Core Tools could not be installed (no matching winget package)."
    }
}

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

Install-AzureDevTools

Write-Host ""
Write-Host "Azure tooling provisioning completed." -ForegroundColor Cyan
