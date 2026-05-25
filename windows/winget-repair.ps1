<# 
    WingetRepair.ps1
    Repairs winget when App Installer is installed but the alias is missing.
#>

Write-Host "`n========== Winget Repair ==========`n"

function Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

# ------------------------------------------
# Step 1 — Check if winget is already available
# ------------------------------------------
Log "Checking if winget is available..."

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Log "winget is already available: $(winget --version)"
    return
} else {
    Log "winget is NOT available in PATH or alias table."
}

# ------------------------------------------
# Step 2 — Verify App Installer package
# ------------------------------------------
Log "Checking App Installer package..."

$pkg = Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue

if (-not $pkg) {
    Log "ERROR: App Installer is NOT installed. Install it from the Microsoft Store."
    exit 1
}

Log "App Installer found: $($pkg.PackageFullName)"
Log "Install location: $($pkg.InstallLocation)"

# ------------------------------------------
# Step 3 — Re-register App Installer
# ------------------------------------------
Log "Re-registering App Installer package..."

try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    Log "Re-registration complete."
} catch {
    Log "ERROR during re-registration: $_"
}

# ------------------------------------------
# Step 4 — Check for winget.exe on disk
# ------------------------------------------
Log "Searching for winget.exe..."

$wingetPath = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Filter winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1

if ($wingetPath) {
    Log "winget.exe found at: $($wingetPath.FullName)"
} else {
    Log "ERROR: winget.exe not found on disk. App Installer may be corrupted."
    exit 1
}

# ------------------------------------------
# Step 5 — Test winget directly
# ------------------------------------------
Log "Testing winget directly from disk..."

try {
    & $wingetPath.FullName --version
    Log "Direct execution succeeded."
} catch {
    Log "ERROR: winget.exe failed to run directly: $_"
}

# ------------------------------------------
# Step 6 — Final PATH/alias check
# ------------------------------------------
Log "Rechecking winget availability..."

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Log "SUCCESS: winget is now available: $(winget --version)"
} else {
    Log "winget still not registered. A Windows sign-out or reboot may be required."
}

Log "`n========== Winget Repair Complete ==========`n"
