# ---------------------------------------------------------------------------
# Re‑Enable OneDrive File Sync (Undo Script)
# ---------------------------------------------------------------------------

Write-Host "Restoring OneDrive sync settings..." -ForegroundColor Cyan

# 1. Remove the Run key override (restores normal auto-launch behavior)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null

# 2. Remove policy flags that disabled OneDrive sync
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSync /f 2>$null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /f 2>$null

# 3. Restart OneDrive so it re-reads policy
$oneDrivePath = "C:\Program Files\Microsoft OneDrive\OneDrive.exe"

if (Test-Path $oneDrivePath) {
    Write-Host "Restarting OneDrive..." -ForegroundColor Cyan
    Start-Process $oneDrivePath
} else {
    Write-Host "OneDrive executable not found. Please reinstall OneDrive." -ForegroundColor Red
}

Write-Host "OneDrive sync has been re-enabled." -ForegroundColor Green