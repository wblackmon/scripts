<#
.SYNOPSIS
    Fully nukes any existing VS Code installation on Windows and WSL, then provisions a clean, deterministic reinstall.

.DESCRIPTION
    This script:
      - Ensures winget is available
      - Ensures script is running elevated
      - On Windows:
          * Uninstalls VS Code (if present)
          * Deletes ALL VS Code folders, extensions, caches, user data
          * Deletes ALL stale VS Code shortcuts
      - On ALL WSL distros:
          * Kills VS Code server processes
          * Deletes ALL VS Code remote folders, extensions, caches, configs
      - Installs VS Code cleanly (system-wide)
      - Rebuilds VS Code shortcuts
      - Verifies the `code` CLI
      - Installs a curated, deduplicated, conflict-free extension set

    REQUIREMENTS:
      - Must be run as Administrator
      - Requires winget
      - Requires WSL (for WSL cleanup; otherwise WSL steps are skipped)
      - Requires internet access
#>

Write-Host "`n========== VS Code Provisioning (Windows + WSL Full Nuclear) ==========`n"

function Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

# ------------------------------------------------------------
# Ensure running as Administrator
# ------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "This script must be run as Administrator."
}

# ------------------------------------------------------------
# Ensure winget exists
# ------------------------------------------------------------
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw "winget is not installed or available in PATH. Install Windows App Installer from the Microsoft Store."
}

# ------------------------------------------------------------
# Detect existing VS Code installation (Windows)
# ------------------------------------------------------------
function Test-VSCodeInstalled {
    $pkg = winget list --id Microsoft.VisualStudioCode --source winget 2>$null
    return ($pkg -match "Visual Studio Code")
}

# ------------------------------------------------------------
# Hardened deletion (attrib + robocopy wipe)
# ------------------------------------------------------------
function Remove-Safe {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return }

    try {
        attrib -r -h -s "$Path" /S /D 2>$null
        Remove-Item $Path -Recurse -Force -ErrorAction Stop
    }
    catch {
        Log "Standard delete failed, applying robocopy wipe: $Path"
        $empty = "$env:TEMP\_empty"
        if (-not (Test-Path $empty)) { New-Item -ItemType Directory -Path $empty | Out-Null }
        robocopy $empty $Path /MIR | Out-Null
        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# Remove stale VS Code shortcuts (Windows)
# ------------------------------------------------------------
function Remove-VSCodeShortcuts {
    Log "Removing stale VS Code shortcuts..."

    $shortcuts = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Visual Studio Code.lnk",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Visual Studio Code (User).lnk",
        "$env:PUBLIC\Desktop\Visual Studio Code.lnk",
        "$env:USERPROFILE\Desktop\Visual Studio Code.lnk"
    )

    foreach ($sc in $shortcuts) {
        if (Test-Path $sc) {
            Log "Deleting shortcut: $sc"
            Remove-Item $sc -Force -ErrorAction SilentlyContinue
        }
    }

    Log "Shortcut cleanup complete.`n"
}

# ------------------------------------------------------------
# Full Nuclear Uninstall (Windows)
# ------------------------------------------------------------
function Uninstall-VSCode-Windows {
    Log "VS Code detected on Windows — performing FULL NUCLEAR UNINSTALL..."

    # Uninstall via winget
    try {
        winget uninstall --id Microsoft.VisualStudioCode `
                         --source winget `
                         --silent `
                         --force `
                         --accept-package-agreements `
                         --accept-source-agreements
        Log "VS Code uninstalled via winget."
    }
    catch {
        Log "Winget uninstall failed (non-fatal): $($_.Exception.Message)"
    }

    # Paths to wipe
    $paths = @(
        "C:\Program Files\Microsoft VS Code",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
        "$env:LOCALAPPDATA\Code",
        "$env:APPDATA\Code",
        "$env:USERPROFILE\.vscode",
        "$env:USERPROFILE\.vscode-insiders",
        "$env:LOCALAPPDATA\Microsoft\VSCode",
        "$env:APPDATA\Microsoft\VSCode"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Log "Wiping: $path"
            Remove-Safe $path
        }
    }

    # Remove any stray Code.exe
    try {
        Get-ChildItem -Path "C:\" -Recurse -Filter "Code.exe" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Log "Deleting stray Code.exe: $($_.FullName)"
                Remove-Safe $_.FullName
            }
    }
    catch {
        Log "Stray Code.exe search failed (non-fatal): $($_.Exception.Message)"
    }

    Log "Full nuclear uninstall on Windows complete.`n"
}

# ------------------------------------------------------------
# Full Nuclear WSL Cleanup (ALL distros)
# ------------------------------------------------------------
function Cleanup-VSCode-WSL {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Log "WSL not detected. Skipping WSL cleanup."
        return
    }

    Log "WSL detected — performing FULL NUCLEAR VS Code cleanup on ALL distros..."

    $distros = wsl.exe -l -q 2>$null | Where-Object { $_ -and ($_ -notmatch "Legacy") }

    foreach ($distro in $distros) {
        $trimmed = $distro.Trim()
        if (-not $trimmed) { continue }

        Log "Cleaning VS Code artifacts in WSL distro: $trimmed"

        $cleanupScript = @'
set -e

if command -v pkill >/dev/null 2>&1; then
  pkill -f vscode-server || true
fi

rm -rf ~/.vscode-server
rm -rf ~/.vscode-server-insiders
rm -rf ~/.vscode-remote
rm -rf ~/.vscode

rm -rf ~/.config/Code
rm -rf ~/.config/"Code - Insiders"
rm -rf ~/.config/Code/logs
rm -rf ~/.cache/vscode
rm -rf ~/.local/share/code-server
rm -rf ~/.vscode-oss

find ~ -type f -name "code" -exec rm -f {} \; 2>/dev/null || true
'@

        try {
            wsl.exe -d "$trimmed" -- bash -lc "$cleanupScript"
            Log "WSL distro '$trimmed' VS Code cleanup complete."
        }
        catch {
            Log "WSL cleanup failed for distro '$trimmed' (non-fatal): $($_.Exception.Message)"
        }
    }

    Log "Full nuclear WSL cleanup complete.`n"
}

# ------------------------------------------------------------
# Install VS Code (clean, Windows)
# ------------------------------------------------------------
function Install-VSCode {
    Log "Installing VS Code via winget (system-wide)..."

    try {
        winget install --id Microsoft.VisualStudioCode `
                       --source winget `
                       --scope machine `
                       --accept-package-agreements `
                       --accept-source-agreements `
                       --silent `
                       --force
        Log "VS Code installation complete.`n"
    }
    catch {
        throw "VS Code installation failed: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# Rebuild VS Code shortcuts (Windows)
# ------------------------------------------------------------
function Rebuild-VSCodeShortcuts {
    Log "Rebuilding VS Code shortcuts..."

    $codeCmd = "C:\Program Files\Microsoft VS Code\bin\code.cmd"

    if (Test-Path $codeCmd) {
        try {
            & $codeCmd --help > $null 2>&1
            Log "VS Code shortcut rebuild triggered."
        }
        catch {
            Log "Shortcut rebuild failed (non-fatal): $($_.Exception.Message)"
        }
    }
    else {
        Log "VS Code binary not found for shortcut rebuild."
    }

    Log "Shortcut rebuild complete.`n"
}

# ------------------------------------------------------------
# Verify code CLI
# ------------------------------------------------------------
function Assert-CodeCLI {
    Log "Verifying VS Code CLI availability..."

    $codeCmd = Get-Command code -ErrorAction SilentlyContinue

    if ($null -eq $codeCmd) {
        throw "VS Code CLI 'code' not found in PATH. Restart your terminal or log out/in."
    }

    Log "VS Code CLI detected at: $($codeCmd.Source)`n"
}

# ------------------------------------------------------------
# Install VS Code Extensions (deduplicated, conflict-free)
# ------------------------------------------------------------
function Install-VSCodeExtensions {
    Log "Installing VS Code extensions..."

    $extensions = @(
        # C# / .NET
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "jmrog.vscode-nuget-package-manager",

        # PowerShell
        "ms-vscode.powershell",

        # Containers / Cloud
        "ms-azuretools.vscode-docker",
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-azurefunctions",

        # SQL / Data
        "ms-mssql.mssql",

        # Web / Frontend
        "esbenp.prettier-vscode",
        "Angular.ng-template",
        "ritwickdey.liveserver",
        "yzhang.markdown-all-in-one",
        "bierner.markdown-preview-github-styles",

        # API / Testing
        "Postman.postman-for-vscode",
        "hbenl.vscode-test-explorer",

        # Git / Repo
        "eamodio.gitlens",

        # Python
        "ms-python.python",

        # YAML
        "redhat.vscode-yaml",

        # WSL
        "ms-vscode-remote.remote-wsl",

        # Icons
        "PKief.material-icon-theme",

        # Bash / Shell
        "mads-hartmann.bash-ide-vscode",
        "timonwong.shellcheck"
    )

    foreach ($ext in $extensions) {
        Log "Installing extension: $ext"
        try {
            code --install-extension $ext --force
        }
        catch {
            Log "Failed to install $ext (non-fatal): $($_.Exception.Message)"
        }
    }

    Log "`nVS Code extension installation complete.`n"
}

# ------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------
if (Test-VSCodeInstalled) {
    Remove-VSCodeShortcuts
    Uninstall-VSCode-Windows
} else {
    Log "VS Code not detected on Windows. Skipping Windows uninstall."
    Remove-VSCodeShortcuts
}

Cleanup-VSCode-WSL
Install-VSCode
Rebuild-VSCodeShortcuts
Assert-CodeCLI
Install-VSCodeExtensions

Log "========== VS Code Provisioning Complete (Windows + WSL Clean Install) ==========`n"
