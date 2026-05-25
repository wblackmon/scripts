<#
.SYNOPSIS
    Makes PowerShell 7 the default shell for VS Code and PATH.
    SAFE VERSION — does NOT modify Windows Terminal settings.json.
#>

Write-Host "=== PowerShell 7 Default Environment Setup (SAFE VERSION) ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Verify PowerShell 7 installation
# ------------------------------------------------------------
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"

if (-not (Test-Path $pwshPath)) {
    Write-Host "PowerShell 7 not found. Installing via winget..." -ForegroundColor Yellow
    winget install --id Microsoft.PowerShell --source winget --scope machine --silent
} else {
    Write-Host "PowerShell 7 already installed." -ForegroundColor Green
}

# ------------------------------------------------------------
# 2. Ensure PS7 is first in PATH
# ------------------------------------------------------------
$pwshDir = "C:\Program Files\PowerShell\7\"
$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($envPath -notlike "*$pwshDir*") {
    Write-Host "Adding PowerShell 7 to PATH..." -ForegroundColor Yellow
    $newPath = "$pwshDir;$envPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
} else {
    Write-Host "PowerShell 7 already present in PATH." -ForegroundColor Green
}

# ------------------------------------------------------------
# 3. REMOVE UNSAFE WINDOWS TERMINAL BLOCK
# ------------------------------------------------------------
Write-Host "Skipping Windows Terminal modification (SAFE)." -ForegroundColor DarkYellow

# ------------------------------------------------------------
# 4. VS Code — ensure JSON structure exists before writing
# ------------------------------------------------------------
$vsSettings = "$env:APPDATA\Code\User\settings.json"

if (Test-Path $vsSettings) {
    Write-Host "Processing VS Code settings..." -ForegroundColor Yellow

    try {
        $vs = Get-Content $vsSettings -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host "VS Code settings.json malformed. Rebuilding..." -ForegroundColor Yellow
        $vs = @{}
    }

    if (-not $vs."terminal.integrated.profiles.windows") {
        $vs | Add-Member -MemberType NoteProperty -Name "terminal.integrated.profiles.windows" -Value @{}
    }

    $vs."terminal.integrated.profiles.windows".PowerShell = @{
        source = "PowerShell"
        path   = $pwshPath
    }

    $vs."terminal.integrated.defaultProfile.windows" = "PowerShell"

    $vs | ConvertTo-Json -Depth 10 | Set-Content $vsSettings -Encoding UTF8
    Write-Host "VS Code now defaults to PowerShell 7." -ForegroundColor Green
} else {
    Write-Host "VS Code settings.json not found — skipping." -ForegroundColor DarkYellow
}

# ------------------------------------------------------------
# 5. PS5.1 compatibility shim
# ------------------------------------------------------------
$shimPath = "$env:ProgramData\ps5.ps1"

if (-not (Test-Path $shimPath)) {
    Write-Host "Creating PS5.1 compatibility shim..." -ForegroundColor Yellow
    @"
Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList \$args
"@ | Set-Content $shimPath
    Write-Host "Shim created at $shimPath" -ForegroundColor Green
} else {
    Write-Host "PS5.1 shim already exists." -ForegroundColor Green
}

# ------------------------------------------------------------
# 6. Auto‑relaunch block for scripts
# ------------------------------------------------------------
$profilePath = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$relaunchBlock = @'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Relaunching in PowerShell 7..."
    $pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
    Start-Process $pwsh -ArgumentList "-NoLogo -NoProfile -File `"$PSCommandPath`""
    exit
}
'@

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

if ((Get-Content $profilePath -Raw) -notlike "*Relaunching in PowerShell 7*") {
    Write-Host "Adding auto‑relaunch enforcement to profile..." -ForegroundColor Yellow
    Add-Content $profilePath $relaunchBlock
    Write-Host "Auto‑relaunch block added." -ForegroundColor Green
} else {
    Write-Host "Auto‑relaunch block already present." -ForegroundColor Green
}

Write-Host "=== PowerShell 7 Default Environment Setup Complete (SAFE VERSION) ===" -ForegroundColor Cyan
