<#
.SYNOPSIS
    Pre-provisioning script for a fresh Windows installation.
    - Enables current user to run PowerShell scripts
    - Disables UAC
    - Disables Windows Update
    - Disables hardware driver updates
    - Enables Microsoft product updates
    - Disables automatic reboot after updates
    - Disables OneDrive file sync (without uninstalling OneDrive)
    - Enables Developer Mode
    - Enables Windows sudo (inline mode)
#>

# ---------------------------------------------------------------------------
# Admin Check
# ---------------------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Windows Pre-Provisioning Starting ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Enable Current User to Run Scripts
# ---------------------------------------------------------------------------
Write-Host "Setting PowerShell execution policy for current user..." -ForegroundColor Yellow
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Host "Execution policy set to RemoteSigned." -ForegroundColor Green
# ---------------------------------------------------------------------------
# Disable Windows Update
# ---------------------------------------------------------------------------
Write-Host "Disabling Windows Update service..." -ForegroundColor Yellow
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Set-Service wuauserv -StartupType Disabled
Write-Host "Windows Update disabled." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Disable Hardware Driver Updates
# ---------------------------------------------------------------------------
Write-Host "Disabling automatic driver updates..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" `
    -Name "SearchOrderConfig" -Value 0
Write-Host "Hardware driver updates disabled." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Enable Microsoft Product Updates
# ---------------------------------------------------------------------------
Write-Host "Enabling Microsoft product updates..." -ForegroundColor Yellow
$auPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
Set-ItemProperty -Path $auPath -Name "EnableMicrosoftUpdate" -Value 1
Write-Host "Microsoft product updates enabled." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Disable Automatic Reboot After Updates
# ---------------------------------------------------------------------------
Write-Host "Disabling automatic reboot after updates..." -ForegroundColor Yellow
$rebootPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $rebootPath)) { New-Item -Path $rebootPath -Force | Out-Null }
Set-ItemProperty -Path $rebootPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1
Write-Host "Automatic reboot after updates disabled." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Enable Developer Mode
# ---------------------------------------------------------------------------
Write-Host "Enabling Windows Developer Mode..." -ForegroundColor Yellow
$devKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
if (-not (Test-Path $devKey)) { New-Item -Path $devKey -Force | Out-Null }
Set-ItemProperty -Path $devKey -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
Write-Host "Developer Mode enabled." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Enable Windows sudo (inline mode)
# ---------------------------------------------------------------------------
Write-Host "Enabling Windows sudo (inline mode)..." -ForegroundColor Yellow
$sudoKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
if (-not (Test-Path $sudoKey)) { New-Item -Path $sudoKey -Force | Out-Null }

# Enabled = 1 (on)
Set-ItemProperty -Path $sudoKey -Name "Enabled" -Value 1 -Type DWord
# Mode = 0 (inline), 1 = new window
Set-ItemProperty -Path $sudoKey -Name "Mode" -Value 0 -Type DWord

Write-Host "Windows sudo enabled (inline mode)." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Pre-Provisioning Summary ===" -ForegroundColor Cyan
Write-Host "Execution Policy: Enabled (RemoteSigned)"
Write-Host "Windows Update: Disabled"
Write-Host "Driver Updates: Disabled"
Write-Host "Microsoft Product Updates: Enabled"
Write-Host "Auto Reboot After Updates: Disabled"
Write-Host "Developer Mode: Enabled"
Write-Host "Windows sudo: Enabled (inline mode)"
Write-Host ""
Write-Host "Windows pre-provisioning completed." -ForegroundColor Cyan
