Write-Host "Optimizing Microsoft Edge for gaming performance..." -ForegroundColor Cyan

# ---------------------------------------------------
# 1. Clear Edge Cache & Temporary Files
# ---------------------------------------------------
$edgeCache = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage"
)

foreach ($path in $edgeCache) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared: $path"
    }
}

# ---------------------------------------------------
# 2. Disable Background Processes (Performance Only)
# ---------------------------------------------------
$regPaths = @(
    "HKCU:\Software\Microsoft\Edge\Main",
    "HKCU:\Software\Microsoft\Edge",
    "HKCU:\Software\Policies\Microsoft\Edge"
)

foreach ($reg in $regPaths) {
    if (!(Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
}

# Disable background mode
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge\Main" `
    -Name "BackgroundModeEnabled" -Value 0 -Type DWord

# Disable Startup Boost
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" `
    -Name "StartupBoostEnabled" -Value 0 -Type DWord

# Disable preloading
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Edge" `
    -Name "PreloadNewTabPage" -Value 0 -Type DWord -Force

Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Edge" `
    -Name "PrelaunchEnabled" -Value 0 -Type DWord -Force

Write-Host "Disabled background processes safely."

# ---------------------------------------------------
# 3. Disable Non‑Essential Scheduled Tasks
# ---------------------------------------------------
$tasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -like "*Edge*" -and $_.TaskName -notlike "*Update*" -and $_.TaskName -notlike "*Security*"
}

foreach ($task in $tasks) {
    try {
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
        Write-Host "Disabled scheduled task: $($task.TaskName)"
    } catch {}
}

# ---------------------------------------------------
# 4. Reduce Edge Resource Usage (Gaming Friendly)
# ---------------------------------------------------
# Limit renderer processes (helps keep RAM free for games)
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Edge" `
    -Name "RendererProcessLimit" -Value 4 -Type DWord -Force

# Disable sleeping tabs timer extension (keeps RAM low)
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Edge" `
    -Name "SleepingTabsEnabled" -Value 1 -Type DWord -Force

Write-Host "Applied gaming-focused performance tweaks."

# ---------------------------------------------------
# 5. Clean Crash Logs & Temp Reports
# ---------------------------------------------------
$logPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Crashpad",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Crashpad\reports",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Reporting"
)

foreach ($path in $logPaths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed logs: $path"
    }
}

Write-Host "`nEdge gaming optimization complete — security settings untouched." -ForegroundColor Green
