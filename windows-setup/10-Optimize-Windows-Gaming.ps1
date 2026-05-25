<#  
    Gaming Optimization Script (AWCC-Safe, Maximum Performance)
    Author: Wayne Eliot Blackmon
    Purpose: Apply gaming-focused performance optimizations that do NOT
             conflict with Alienware Command Center power/thermal profiles.
             Includes rollback support.
#>

# ---------------------------
#  Require Admin
# ---------------------------
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Run PowerShell as Administrator."
    Break
}

# ---------------------------
#  Backup Registry Values
# ---------------------------
Function Backup-GamingRegistry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath
    )

    $paths = @{
        "HKCU:\Software\Microsoft\GameBar" = @(
            "AllowAutoGameMode",
            "AutoGameModeEnabled"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" = @(
            "HwSchMode"
        )
        "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" = @(
            "DirectXUserGlobalSettings"
        )
        "HKCU:\System\GameConfigStore" = @(
            "GameDVR_FSEBehaviorMode",
            "GameDVR_HonorUserFSEBehaviorMode"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" = @(
            "TcpNoDelay",
            "TcpDelAckTicks",
            "TcpAckFrequency",
            "EnableTCPChimney",
            "EnableRSS",
            "EnableTCPA",
            "EnableDCA",
            "ECNCapability"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" = @(
            "GlobalTimerResolutionRequests"
        )
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" = @(
            "AppCaptureEnabled",
            "AudioCaptureEnabled"
        )
    }

    $backup = @{}

    foreach ($path in $paths.Keys) {
        foreach ($name in $paths[$path]) {
            if (Test-Path $path) {
                try {
                    $value = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop |
                             Select-Object -ExpandProperty $name
                    $backup["$path|$name"] = $value
                } catch {
                    $backup["$path|$name"] = $null
                }
            } else {
                $backup["$path|$name"] = $null
            }
        }
    }

    $backup | ConvertTo-Json | Out-File $BackupPath -Encoding UTF8
}

# ---------------------------
#  Restore Registry Values
# ---------------------------
Function Restore-GamingRegistry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath
    )

    if (-not (Test-Path $BackupPath)) {
        Write-Host "No gaming backup found." -ForegroundColor Red
        return
    }

    $backup = Get-Content $BackupPath | ConvertFrom-Json

    foreach ($key in $backup.PSObject.Properties.Name) {
        $parts = $key -split "\|"
        $path = $parts[0]
        $name = $parts[1]
        $value = $backup.$key

        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        if ($value -eq $null) {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        } else {
            Set-ItemProperty -Path $path -Name $name -Value $value -Force
        }
    }

    Write-Host "Gaming settings restored." -ForegroundColor Green
}

# ---------------------------
#  Apply Gaming Optimizations (AWCC-Safe)
# ---------------------------
Function Optimize-Gaming {
    Write-Host "Applying AWCC-safe gaming optimizations…" -ForegroundColor Cyan

    # --- Game Mode ---
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Force

    # --- Hardware Accelerated GPU Scheduling (HAGS) ---
    $gpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    If (-not (Test-Path $gpuPath)) { New-Item -Path $gpuPath -Force | Out-Null }
    Set-ItemProperty -Path $gpuPath -Name "HwSchMode" -Value 2 -Force

    # --- Ensure DirectX registry path exists ---
    $dxBase = "HKCU:\Software\Microsoft\DirectX"
    $dxPref = "$dxBase\UserGpuPreferences"

    If (-not (Test-Path $dxBase)) { New-Item -Path $dxBase -Force | Out-Null }
    If (-not (Test-Path $dxPref)) { New-Item -Path $dxPref -Force | Out-Null }

    # --- Combined VRR + GPU Preference (single string) ---
    $dxValue = "GpuPreference=2;VRROptimizeEnable=1;"

    New-ItemProperty -Path $dxPref `
        -Name "DirectXUserGlobalSettings" `
        -Value $dxValue `
        -PropertyType String `
        -Force | Out-Null

    # --- Fullscreen Optimizations ---
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force

    # --- Network Latency Optimization ---
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    If (-not (Test-Path $tcpPath)) { New-Item -Path $tcpPath -Force | Out-Null }

    $netSettings = @{
        "TcpNoDelay" = 1
        "TcpDelAckTicks" = 0
        "TcpAckFrequency" = 1
        "EnableTCPChimney" = 0
        "EnableRSS" = 1
        "EnableTCPA" = 0
        "EnableDCA" = 0
        "ECNCapability" = 0
    }

    foreach ($name in $netSettings.Keys) {
        Set-ItemProperty -Path $tcpPath -Name $name -Value $netSettings[$name] -Force
    }

    # --- Timer Resolution Optimization ---
    $sysPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
    If (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
    Set-ItemProperty -Path $sysPath -Name "GlobalTimerResolutionRequests" -Value 1 -Force

    # --- Disable Game Bar Recording (keep Game Bar itself) ---
    $gbar = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    If (-not (Test-Path $gbar)) { New-Item -Path $gbar -Force | Out-Null }
    Set-ItemProperty -Path $gbar -Name "AppCaptureEnabled" -Value 0 -Force
    Set-ItemProperty -Path $gbar -Name "AudioCaptureEnabled" -Value 0 -Force

    # --- Optional Xbox Service Trimming ---
    $services = @(
        "XblAuthManager",
        "XblGameSave",
        "XboxNetApiSvc"
    )

    foreach ($svc in $services) {
        Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
    }

    Write-Host "Gaming optimizations applied (AWCC-safe)." -ForegroundColor Green
}

# ---------------------------
#  Main Menu
# ---------------------------
Write-Host "`n=== Gaming Optimization Menu (AWCC-Safe) ===" -ForegroundColor Yellow
Write-Host "1. Apply Gaming Optimizations"
Write-Host "2. Rollback Gaming Optimizations"
Write-Host "----------------------------------------------"

$choice = Read-Host "Select an option"

$backupPath = "C:\Windows11-Optimization-Backup\gaming_backup.json"

switch ($choice) {
    "1" {
        Backup-GamingRegistry -BackupPath $backupPath
        Optimize-Gaming
    }
    "2" {
        Restore-GamingRegistry -BackupPath $backupPath
    }
    default {
        Write-Host "Invalid selection." -ForegroundColor Red
    }
}

Write-Host "`nCompleted." -ForegroundColor Green
