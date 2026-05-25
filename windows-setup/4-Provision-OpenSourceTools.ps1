<#
.SYNOPSIS
    Provision open-source development tools and Ubuntu WSL on Windows.

.DESCRIPTION
    This script installs a curated set of open-source developer tools using winget,
    and enables WSL2 + VirtualMachinePlatform using Windows PowerShell 5.1
    (required because PowerShell 7 cannot call Enable-WindowsOptionalFeature).

    SAFETY:
    - Does NOT modify UAC
    - Does NOT modify Windows Update
    - Does NOT modify shell folders or OneDrive
    - Does NOT alter system security boundaries
    - All installs are idempotent (winget handles duplicates safely)
    - WSL enablement is safe and does not reboot automatically
    - No destructive registry edits

    REQUIREMENTS:
    - Must be run as Administrator
    - Requires winget (Windows App Installer)
    - Requires Windows 10/11 with virtualization support enabled in BIOS

    COMPONENTS INSTALLED:
    - GitHub CLI
    - Node.js LTS
    - curl / wget
    - 7zip
    - Docker Desktop
    - kubectl / Helm / k9s
    - Terraform CLI
    - Ubuntu 24.04 LTS for WSL2

.NOTES
    Author: Wayne
    Safe for repeated execution (idempotent)
#>

# ------------------------------------------------------------
# SECTION HEADER
# ------------------------------------------------------------
function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
    Write-Host ""
}

# ------------------------------------------------------------
# WINGET CHECK
# ------------------------------------------------------------
function Assert-Winget {
    Write-Section "Checking for winget"

    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($null -eq $winget) {
        Write-Host "winget is NOT installed on this system." -ForegroundColor Red
        Write-Host ""
        Write-Host "Install the Windows App Installer package from the Microsoft Store:" -ForegroundColor Yellow
        Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1"
        Write-Host ""
        throw "winget is required but not installed."
    }

    Write-Host "winget detected at: $($winget.Source)" -ForegroundColor Green
    Write-Host ""
}

# ------------------------------------------------------------
# WINGET PACKAGE INSTALLER (SAFE + IDEMPOTENT)
# ------------------------------------------------------------
function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    Assert-Winget

    Write-Host "Installing $Name..." -ForegroundColor Yellow

    try {
        winget install --id $Id --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity 2>$null
    }
    catch {
        Write-Host "  (already installed or failed gracefully)" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------
# OPEN-SOURCE DEV TOOLS
# ------------------------------------------------------------
function Install-OpenSourceDevTools {
    Write-Section "Installing open-source development tools"

    Install-WingetPackage -Id "GitHub.cli" -Name "GitHub CLI"
    Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
    Install-WingetPackage -Id "Curl.Curl" -Name "curl"
    Install-WingetPackage -Id "GnuWin32.Wget" -Name "wget"
    Install-WingetPackage -Id "7zip.7zip" -Name "7zip"
    Install-WingetPackage -Id "Docker.DockerDesktop" -Name "Docker Desktop"
    Install-WingetPackage -Id "Kubernetes.kubectl" -Name "kubectl"
    Install-WingetPackage -Id "Helm.Helm" -Name "Helm"
    Install-WingetPackage -Id "Derailed.k9s" -Name "k9s"
    Install-WingetPackage -Id "Hashicorp.Terraform" -Name "Terraform CLI"

    Write-Host ""
    Write-Host "Open-source tooling installed. Verify with:" -ForegroundColor Cyan
    Write-Host "  gh --version"
    Write-Host "  node --version"
    Write-Host "  kubectl version --client"
    Write-Host "  terraform version"
    Write-Host "  7z"
    Write-Host ""
}

# ------------------------------------------------------------
# UBUNTU WSL INSTALL — SAFE FOR POWERSHELL 7
# ------------------------------------------------------------
function Install-UbuntuWsl {
    Write-Section "Installing Ubuntu LTS for WSL"

    Write-Host "Enabling WSL + VirtualMachinePlatform using Windows PowerShell 5.1..." -ForegroundColor Yellow

    $ps51 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

    # Enable WSL
    & $ps51 -Command "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart" `
        2>$null | Out-Null

    # Enable VirtualMachinePlatform
    & $ps51 -Command "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart" `
        2>$null | Out-Null

    Write-Host "Setting WSL2 as default version..." -ForegroundColor Yellow
    wsl --set-default-version 2 2>$null

    Write-Host "Installing Ubuntu LTS (24.04)..." -ForegroundColor Yellow
    Install-WingetPackage -Id "Canonical.Ubuntu.2404" -Name "Ubuntu 24.04 LTS"

    Write-Host ""
    Write-Host "Ubuntu installed. Launch it once manually to complete setup:" -ForegroundColor Cyan
    Write-Host "  ubuntu2404"
    Write-Host ""
}

# ------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------
Assert-Winget
Install-OpenSourceDevTools
Install-UbuntuWsl
