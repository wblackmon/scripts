<#
.SYNOPSIS
    Repairs Windows Terminal settings.json so that:
    - PowerShell 7 profile exists
    - GUIDs are brace-wrapped
    - defaultProfile matches a real profile
    - pwsh.exe path is correct
    - JSON is schema-safe

.DESIGNED FOR
    Wayne — deterministic, idempotent, bulletproof.
#>

Write-Host "=== Repairing Windows Terminal for PowerShell 7 ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Paths
# ------------------------------------------------------------
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# ------------------------------------------------------------
# 2. Load JSON safely
# ------------------------------------------------------------
try {
    $jsonText = Get-Content $wtSettings -Raw
    $json = $jsonText | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Host "ERROR: settings.json is malformed. Rebuilding minimal structure..." -ForegroundColor Yellow
    $json = @{
        "$schema" = "https://aka.ms/terminal-profiles-schema"
        "defaultProfile" = ""
        "profiles" = @{
            "list" = @()
        }
    }
}

# ------------------------------------------------------------
# 3. Ensure profiles.list exists
# ------------------------------------------------------------
if (-not $json.profiles) {
    $json.profiles = @{ list = @() }
}
if (-not $json.profiles.list) {
    $json.profiles.list = @()
}

# ------------------------------------------------------------
# 4. GUID helper
# ------------------------------------------------------------
function Convert-ToBraceGuid {
    param([string]$guid)
    if ($guid -match "^\{.*\}$") { return $guid }
    return "{${guid}}"
}

# ------------------------------------------------------------
# 5. Repair GUIDs in existing profiles
# ------------------------------------------------------------
foreach ($p in $json.profiles.list) {
    if ($p.guid) {
        $p.guid = Convert-ToBraceGuid $p.guid
    }
}

# ------------------------------------------------------------
# 6. Ensure PS7 profile exists
# ------------------------------------------------------------
$ps7Profile = $json.profiles.list | Where-Object {
    $_.commandline -like "*pwsh.exe*" -or $_.commandline -eq "pwsh"
}

if (-not $ps7Profile) {
    Write-Host "Creating PowerShell 7 profile..." -ForegroundColor Yellow
    $ps7Profile = @{
        guid = Convert-ToBraceGuid ([guid]::NewGuid().ToString())
        name = "PowerShell 7"
        commandline = $pwshPath
        icon = "ms-appx:///ProfileIcons/pwsh.png"
        startingDirectory = "%USERPROFILE%"
    }
    $json.profiles.list += $ps7Profile
}

# Ensure correct path
$ps7Profile.commandline = $pwshPath

# ------------------------------------------------------------
# 7. Set defaultProfile to PS7 profile GUID
# ------------------------------------------------------------
$json.defaultProfile = $ps7Profile.guid

Write-Host "defaultProfile set to $($json.defaultProfile)" -ForegroundColor Green

# ------------------------------------------------------------
# 8. Save JSON safely
# ------------------------------------------------------------
$json | ConvertTo-Json -Depth 10 | Set-Content $wtSettings -Encoding UTF8

Write-Host "Windows Terminal repaired successfully." -ForegroundColor Cyan
Write-Host "=== Complete ==="
