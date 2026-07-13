# =====================================================================
# LOGITECH TOTAL SYSTEM PURGE - WINDOWS 11
# Deterministic, idempotent, silent, complete.
# =====================================================================

Write-Host "Starting Logitech total purge..."

# ------------------------------------------------------------
# 1. Stop Logitech Processes
# ------------------------------------------------------------
$processes = @(
    "lghub_agent","lghub_updater","lghub",
    "logioptionsplus_agent","logioptionsplus_service",
    "logioptionsplus_updater","logioptionsplus",
    "logitechgaming","setpoint","logishrd","logi_overlay"
)

foreach ($p in $processes) {
    Get-Process -Name $p -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------
# 2. Uninstall Logitech Applications (FAST, NO WIN32_PRODUCT)
# ------------------------------------------------------------
Write-Host "Removing Logitech applications..."

$uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$logiPatterns = @("Logitech","Logi","LGHUB","Options","SetPoint")

foreach ($root in $uninstallRoots) {
    Get-ChildItem $root | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        $disp = $props.DisplayName
        $uninst = $props.UninstallString

        if ($disp) {
            foreach ($pattern in $logiPatterns) {
                if ($disp -like "*$pattern*") {
                    Write-Host "Uninstalling: $disp"
                    try {
                        $cmd = $uninst.Replace('"','')
                        if ($cmd -match "msiexec") {
                            Start-Process "msiexec.exe" -ArgumentList "/x $($_.PSChildName) /qn" -Wait
                        } else {
                            Start-Process $cmd -ArgumentList "/S","/quiet","/qn" -Wait
                        }
                    } catch {}
                }
            }
        }
    }
}

# ------------------------------------------------------------
# 3. Remove Logitech Drivers (PnPUtil)
# ------------------------------------------------------------
Write-Host "Removing Logitech drivers..."

$driverPatterns = @("logi","lg","logitech","lghub","logidriver","logishrd")

foreach ($pattern in $driverPatterns) {
    pnputil /enum-drivers | Select-String $pattern | ForEach-Object {
        if ($_.ToString() -match "Published Name : (oem\d+\.inf)") {
            $inf = $matches[1]
            pnputil /delete-driver $inf /uninstall /force
        }
    }
}

# ------------------------------------------------------------
# 4. Remove Logitech Services
# ------------------------------------------------------------
Write-Host "Removing Logitech services..."

$services = @(
    "LGHUBUpdaterService","LGHUBAgent",
    "LogiOptionsPlusUpdater","LogiOptionsPlusService",
    "LogiOverlay"
)

foreach ($svc in $services) {
    sc.exe stop $svc 2>$null
    sc.exe delete $svc 2>$null
}

# ------------------------------------------------------------
# 5. Remove Scheduled Tasks
# ------------------------------------------------------------
Write-Host "Removing Logitech scheduled tasks..."

$tasks = @("\Logitech","\LGHUB","\LogiOptionsPlus","\LogiOverlay")

foreach ($task in $tasks) {
    schtasks /Delete /TN $task /F 2>$null
}

# ------------------------------------------------------------
# 6. Delete Logitech Folders
# ------------------------------------------------------------
Write-Host "Removing Logitech folders..."

$folders = @(
    "$env:ProgramFiles\LGHUB",
    "$env:ProgramFiles\Logitech",
    "$env:ProgramFiles\Logitech Gaming Software",
    "$env:ProgramFiles\LogiOptionsPlus",
    "$env:ProgramFiles (x86)\Logitech",
    "$env:ProgramFiles (x86)\Logitech Gaming Software",
    "$env:ProgramFiles (x86)\LogiOptionsPlus",
    "$env:LocalAppData\LGHUB",
    "$env:LocalAppData\Logitech",
    "$env:LocalAppData\LogiOptionsPlus",
    "$env:AppData\LGHUB",
    "$env:AppData\Logitech",
    "$env:AppData\LogiOptionsPlus",
    "$env:ProgramData\LGHUB",
    "$env:ProgramData\Logitech",
    "$env:ProgramData\LogiOptionsPlus"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# 7. Registry Cleanup
# ------------------------------------------------------------
Write-Host "Removing Logitech registry keys..."

$regKeys = @(
    "HKLM:\SOFTWARE\Logitech",
    "HKLM:\SOFTWARE\WOW6432Node\Logitech",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LGHUBUpdaterService",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LGHUBAgent",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LogiOptionsPlusService",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LogiOverlay",
    "HKCU:\Software\Logitech",
    "HKCU:\Software\LogiOptionsPlus",
    "HKCU:\Software\LGHUB"
)

foreach ($key in $regKeys) {
    if (Test-Path $key) {
        Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# 8. Remove Logitech HID Devices (VID_046D)
# ------------------------------------------------------------
Write-Host "Removing Logitech HID devices..."

$hidPatterns = @("VID_046D","Logitech")

foreach ($pattern in $hidPatterns) {
    Get-PnpDevice | Where-Object { $_.InstanceId -like "*$pattern*" } |
        ForEach-Object {
            try {
                Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
                Remove-PnpDevice -InstanceId $_.InstanceId -ErrorAction SilentlyContinue
            } catch {}
        }
}

# ------------------------------------------------------------
# 9. Purge Event Viewer Logs
# ------------------------------------------------------------
Write-Host "Purging Event Viewer logs..."

Get-WinEvent -ListLog * | Where-Object {
    $_.LogName -like "*Logi*" -or
    $_.LogName -like "*LGHUB*" -or
    $_.LogName -like "*Logitech*"
} | ForEach-Object {
    try { Clear-EventLog -LogName $_.LogName } catch {}
}

# ------------------------------------------------------------
# 10. Remove WER Crash Dumps
# ------------------------------------------------------------
Write-Host "Removing WER crash dumps..."

$werPaths = @(
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
    "$env:LocalAppData\CrashDumps"
)

foreach ($p in $werPaths) {
    if (Test-Path $p) {
        Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*logi*" -or $_.Name -like "*lghub*" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# 11. Remove DriverStore Logs
# ------------------------------------------------------------
Write-Host "Removing DriverStore logs..."

Get-ChildItem "C:\Windows\inf" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*logi*" -or $_.Name -like "*lghub*" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# 12. Remove FileRepository Logitech Entries
# ------------------------------------------------------------
Write-Host "Removing FileRepository Logitech entries..."

Get-ChildItem "C:\Windows\System32\DriverStore\FileRepository" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*046d*" -or $_.Name -like "*logi*" } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# 13. Remove LEGACY Logitech Services
# ------------------------------------------------------------
Write-Host "Removing LEGACY Logitech services..."

Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\Root" |
    Where-Object { $_.Name -like "*LEGACY_LOGI*" -or $_.Name -like "*LEGACY_LGHUB*" } |
    ForEach-Object {
        try { Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }

# ------------------------------------------------------------
# 14. Remove Cached MSI Logs
# ------------------------------------------------------------
Write-Host "Removing cached MSI logs..."

Get-ChildItem "C:\Windows\Installer" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*logi*" -or $_.Name -like "*lghub*" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# 15. Remove ProgramData Telemetry Logs
# ------------------------------------------------------------
Write-Host "Removing ProgramData telemetry logs..."

Get-ChildItem "$env:ProgramData" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*logi*" -or $_.Name -like "*lghub*" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
Write-Host "Logitech total purge complete."
# =====================================================================
