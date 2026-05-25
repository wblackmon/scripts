# ============================================
# VS Code Migration Script (Corrected)
# User Installer → System Installer
# ============================================

Write-Host "Exporting installed extensions..." -ForegroundColor Cyan

$extFile = "$env:TEMP\vscode-extensions.txt"
code --list-extensions > $extFile

Write-Host "Extensions exported to: $extFile" -ForegroundColor Green

# --------------------------------------------
# Uninstall User-Scope VS Code
# --------------------------------------------

Write-Host "Searching for user-scope VS Code installation..." -ForegroundColor Cyan

$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$vsCodeEntry = Get-ChildItem $uninstallKey | Where-Object {
    ($_ | Get-ItemProperty).DisplayName -like "Microsoft Visual Studio Code"
}

if ($vsCodeEntry) {
    $uninstallString = ($vsCodeEntry | Get-ItemProperty).UninstallString
    Write-Host "Uninstalling user-scope VS Code..." -ForegroundColor Yellow
    & $uninstallString /VERYSILENT /SUPPRESSMSGBOXES
    Write-Host "VS Code (user-scope) uninstalled." -ForegroundColor Green
} else {
    Write-Host "User-scope VS Code not found. Continuing..." -ForegroundColor DarkYellow
}

# --------------------------------------------
# Download System Installer (Correct URL)
# --------------------------------------------

$installerUrl = "https://vscode.download.prss.microsoft.com/dbazure/download/stable/latest/win32-x64-system/stable"
$installerPath = "$env:TEMP\VSCodeSystemSetup.exe"

Write-Host "Downloading VS Code System Installer..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download complete." -ForegroundColor Green
}
catch {
    Write-Host "Download FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $installerPath)) {
    Write-Host "Installer file missing after download. Aborting." -ForegroundColor Red
    exit 1
}

# --------------------------------------------
# Install System-Scope VS Code
# --------------------------------------------

Write-Host "Installing VS Code (system-scope)..." -ForegroundColor Yellow
Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait

# --------------------------------------------
# Reinstall Extensions
# --------------------------------------------

Write-Host "Reinstalling extensions..." -ForegroundColor Cyan

Get-Content $extFile | ForEach-Object {
    Write-Host "Installing extension: $_" -ForegroundColor DarkCyan
    code --install-extension $_ --force
}

Write-Host "All extensions reinstalled." -ForegroundColor Green

# --------------------------------------------
# Final Verification
# --------------------------------------------

Write-Host "`nVerifying installation..." -ForegroundColor Cyan

$systemPath = "C:\Program Files\Microsoft VS Code\Code.exe"

if (Test-Path $systemPath) {
    Write-Host "VS Code System Installer is correctly installed." -ForegroundColor Green
} else {
    Write-Host "VS Code System Installer NOT found. Installation failed." -ForegroundColor Red
}

Write-Host "`nMigration complete." -ForegroundColor Green
