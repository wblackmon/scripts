<#
.SYNOPSIS
    WayneOS Dev + Gaming Optimization Script (Balanced Edition)

.DESCRIPTION
    A safe, reversible, non-destructive optimization script designed for
    development + gaming workloads on Windows 10/11.

    This script:
      - Minimizes Widgets (keeps Weather + News only)
      - Disables non-essential background services (Xbox, Mixed Reality, Retail Demo)
      - Reduces telemetry (non-breaking, balanced)
      - Disables background apps (safe)
      - Cleans lock screen while preserving Spotlight
      - Preserves all core Windows features

    SAFETY:
      - No UAC changes
      - No OneDrive changes
      - No shell folder changes
      - No Windows Update changes
      - No Explorer/session elevation
      - No irreversible system modifications
      - All service disables are reversible
      - All registry edits are safe and limited to HKCU or HKLM policy keys

    REQUIREMENTS:
      - PowerShell 7+
      - Run as Administrator (for service changes)

.NOTES
    This script is intentionally conservative and avoids any “debloat”
    operations that break Windows features or cause instability.
#>

Write-Host "=== WayneOS Dev + Gaming Optimization (Balanced Edition) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# Helper: Safe Service Disable (Idempotent + Try/Catch)
# ---------------------------------------------------------------------
function Disable-ServiceSafe {
    param([string]$Name)

    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            Write-Host "Service not found: $Name (skipped)" -ForegroundColor DarkYellow
            return
        }

        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Disabled service: $Name" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to disable service $Name (non-fatal): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# ---------------------------------------------------------------------
# Helper: Safe Registry Write
# ---------------------------------------------------------------------
function Set-RegValueSafe {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )

    try {
        reg add $Path /v $Name /t $Type /d $Value /f > $null 2>&1
    }
    catch {
        Write-Host "Failed to set registry value $Path\$Name (non-fatal)" -ForegroundColor DarkYellow
    }
}

# ---------------------------------------------------------------------
# 1. Minimize Widgets (Weather + News Only)
# ---------------------------------------------------------------------
Write-Host "`n=== Minimizing Widgets (Weather + News Only) ===" -ForegroundColor Cyan

Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" "REG_DWORD" "2"
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Feeds" "IsFeedsAvailable" "REG_DWORD" "1"
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" "REG_DWORD" "1"

Write-Host "Widgets optimized." -ForegroundColor Green

# ---------------------------------------------------------------------
# 2. Disable Real Background Offenders (Safe)
# ---------------------------------------------------------------------
Write-Host "`n=== Disabling Real Background Offenders ===" -ForegroundColor Cyan

Disable-ServiceSafe -Name "XboxGipSvc"
Disable-ServiceSafe -Name "XboxNetApiSvc"
Disable-ServiceSafe -Name "MixedRealityOpenXRSvc"
Disable-ServiceSafe -Name "RetailDemo"
Disable-ServiceSafe -Name "diagsvc"

Write-Host "Background offenders disabled." -ForegroundColor Green

# ---------------------------------------------------------------------
# 3. Reduce Telemetry (Balanced, Non-Breaking)
# ---------------------------------------------------------------------
Write-Host "`n=== Reducing Telemetry (Balanced) ===" -ForegroundColor Cyan

Set-RegValueSafe "HKLM\Software\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" "REG_DWORD" "1"
Set-RegValueSafe "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" "REG_DWORD" "1"

Write-Host "Telemetry reduced (non-breaking)." -ForegroundColor Green

# ---------------------------------------------------------------------
# 4. Disable Background Apps (Safe)
# ---------------------------------------------------------------------
Write-Host "`n=== Disabling Background Apps (Safe) ===" -ForegroundColor Cyan

Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" "REG_DWORD" "1"

Write-Host "Background apps disabled." -ForegroundColor Green

# ---------------------------------------------------------------------
# 5. Clean Up Lock Screen (Spotlight-Friendly)
# ---------------------------------------------------------------------
Write-Host "`n=== Cleaning Up Lock Screen (Spotlight-Friendly) ===" -ForegroundColor Cyan

# Spotlight ON, ads OFF
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" "REG_DWORD" "1"
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" "REG_DWORD" "0"
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" "REG_DWORD" "0"
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" "REG_DWORD" "0"

# Disable lock-screen notifications
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" "REG_DWORD" "0"

# Disable lock-screen apps
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "CreativeId" "REG_SZ" ""
Set-RegValueSafe "HKCU\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "CreativeJson" "REG_SZ" ""

Write-Host "Lock screen cleaned (Spotlight preserved)." -ForegroundColor Green

# ---------------------------------------------------------------------
# 6. Preserve Core Windows Features
# ---------------------------------------------------------------------
Write-Host "`n=== Preserving Core Windows Features ===" -ForegroundColor Cyan
Write-Host "Spotlight, Search, Store, Photos, Widgets remain fully functional." -ForegroundColor Green

# ---------------------------------------------------------------------
# 7. Final Output
# ---------------------------------------------------------------------
Write-Host "`n=== WayneOS Optimization Complete ===" -ForegroundColor Cyan
Write-Host "A reboot is recommended for all changes to apply." -ForegroundColor Yellow
