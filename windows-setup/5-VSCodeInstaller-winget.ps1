<#
.SYNOPSIS
    Fully provisions Visual Studio Code using the official system-wide installer.

.DESCRIPTION
    This script:
      - Ensures winget is available
      - Removes old VS Code user data (if present)
      - Installs VS Code using the downloadable EXE (system-wide)
      - Verifies that the `code` CLI is available
      - Installs a curated set of extensions (Wayne Edition)
      - Uses full try/catch safety and if-exists checks

    SAFETY:
      - Does NOT modify UAC
      - Does NOT modify Windows Update
      - Does NOT touch OneDrive or shell folders
      - Does NOT break Explorer session state
      - Idempotent: safe to run repeatedly
      - Deletes only VS Code user data folders if they exist
      - Skips install if VS Code is already installed

    REQUIREMENTS:
      - Must be run as Administrator
      - Requires winget
      - Requires internet access for installer + extensions

.NOTES
    Prefers the official EXE installer over the Microsoft Store version.
    This ensures stable CLI behavior and predictable installation paths.
#>

Write-Host "`n========== VS Code Provisioning ==========`n"

function Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

# ------------------------------------------------------------
# Ensure winget exists
# ------------------------------------------------------------
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw "winget is not installed or available in PATH. Install Windows App Installer from the Microsoft Store."
}

# ------------------------------------------------------------
# Detect existing VS Code installation
# ------------------------------------------------------------
function Test-VSCodeInstalled {
    $paths = @(
        "C:\Program Files\Microsoft VS Code\Code.exe",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }

    return $false
}

# ------------------------------------------------------------
# Reset VS Code user data (safe)
# ------------------------------------------------------------
function Reset-VSCodeUserData {
    Log "Resetting VS Code user data..."

    $pathsToDelete = @(
        "$env:APPDATA\Code",
        "$env:USERPROFILE\.vscode"
    )

    foreach ($path in $pathsToDelete) {
        if (Test-Path $path) {
            Log "Deleting: $path"
            try {
                Remove-Item $path -Recurse -Force -ErrorAction Stop
            }
            catch {
                Log "Failed to delete $path (non-fatal): $($_.Exception.Message)"
            }
        }
    }

    Log "VS Code user data reset complete.`n"
}

# ------------------------------------------------------------
# Install VS Code (system-wide EXE installer)
# ------------------------------------------------------------
function Install-VSCode {
    Log "Checking for existing VS Code installation..."

    if (Test-VSCodeInstalled) {
        Log "VS Code already installed. Skipping installation.`n"
        return
    }

    Log "Downloading official VS Code system-wide installer..."

    $url = "https://update.code.visualstudio.com/latest/win32-x64/stable"
    $installer = Join-Path $env:TEMP "VSCodeSetup.exe"

    try {
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
    }
    catch {
        throw "Failed to download VS Code installer: $($_.Exception.Message)"
    }

    Log "Running VS Code installer (silent)..."

    try {
        Start-Process $installer -ArgumentList "/VERYSILENT", "/NORESTART" -Wait -ErrorAction Stop
        Log "VS Code installation complete.`n"
    }
    catch {
        throw "VS Code installation failed: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path $installer) {
            Remove-Item $installer -Force -ErrorAction SilentlyContinue
        }
    }
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
# Install VS Code Extensions
# ------------------------------------------------------------
function Install-VSCodeExtensions {
    Log "Installing VS Code extensions..."

    $extensions = @(
        # Core scripting
        "ms-dotnettools.csharp",
        "ms-vscode.powershell",
        "mads-hartmann.bash-ide-vscode",
        "ms-python.python",

        # GitHub + AI
        "GitHub.copilot",
        "GitHub.copilot-chat",

        # Remote development
        "ms-vscode-remote.remote-wsl",

        # Azure + Cloud
        "ms-vscode.azure-account",
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-docker",
        "ms-azuretools.vscode-azurefunctions",

        # Data
        "ms-mssql.mssql",

        # YAML (pipelines, GitHub Actions, Kubernetes)
        "redhat.vscode-yaml",
        "ms-kubernetes-tools.vscode-kubernetes-tools",

        # Repo-aware workflows
        "eamodio.gitlens",

        # Formatting & Icons
        "esbenp.prettier-vscode",
        "PKief.material-icon-theme"
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
Reset-VSCodeUserData
Install-VSCode
Assert-CodeCLI
Install-VSCodeExtensions

Log "========== VS Code Provisioning Complete ==========`n"
