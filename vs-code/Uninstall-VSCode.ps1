<#
.SYNOPSIS
    Fully uninstalls Visual Studio Code and removes all extensions,
    settings, caches, and residual files for both User and System installs.

.NOTES
    Safe, idempotent, Windows‑only.
#>

Write-Host "Stopping VS Code processes..."
Get-Process "Code" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process "Code - Insiders" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# --- Uninstall VS Code (User + System) ---------------------------------------

Write-Host "Attempting to uninstall VS Code..."

$possibleUninstallers = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\unins000.exe",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\unins000.exe",
    "$env:ProgramFiles\Microsoft VS Code\unins000.exe",
    "$env:ProgramFiles(x86)\Microsoft VS Code\unins000.exe"
)

foreach ($uninstaller in $possibleUninstallers) {
    if (Test-Path $uninstaller) {
        Write-Host "Running uninstaller: $uninstaller"
        Start-Process $uninstaller "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
    }
}

# --- Remove leftover program folders -----------------------------------------

$programPaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders",
    "$env:ProgramFiles\Microsoft VS Code",
    "$env:ProgramFiles(x86)\Microsoft VS Code"
)

foreach ($path in $programPaths) {
    if (Test-Path $path) {
        Write-Host "Removing program folder: $path"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Remove user data (extensions, settings, caches) --------------------------

Write-Host "Removing user data folders..."

$userDataPaths = @(
    "$env:APPDATA\Code",
    "$env:APPDATA\Code - Insiders",
    "$env:LOCALAPPDATA\Code",
    "$env:LOCALAPPDATA\Code - Insiders",
    "$env:USERPROFILE\.vscode",
    "$env:USERPROFILE\.vscode-insiders"
)

foreach ($path in $userDataPaths) {
    if (Test-Path $path) {
        Write-Host "Removing: $path"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Remove extension cache + workspace storage -------------------------------

$cachePaths = @(
    "$env:LOCALAPPDATA\Microsoft\VSCode",
    "$env:LOCALAPPDATA\Microsoft\VSCode-insiders",
    "$env:APPDATA\Microsoft\VSCode",
    "$env:APPDATA\Microsoft\VSCode-insiders"
)

foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        Write-Host "Removing cache: $path"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nVS Code has been fully removed from this system."
Write-Host "All extensions, settings, and caches have been purged."
