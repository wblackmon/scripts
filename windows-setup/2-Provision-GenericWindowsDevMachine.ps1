<#
================================================================================
 Provision-DevMachine.ps1
 Version: 1.0.0
 Author: Wayne
================================================================================

.SYNOPSIS
    Provisions a clean, stable Windows development environment using safe,
    idempotent, repeatable operations.

.DESCRIPTION
    This script installs and configures a complete development baseline for
    Windows 10/11 using only safe, reversible, non-destructive actions.

    It provisions:
      • Windows developer tools (Git, Windows Terminal, PowerShell 7)
      • .NET SDKs (8 LTS, 9 Current, 10.0.101)
      • Azure CLI, Bicep CLI, Azure Functions Core Tools
      • WSL + VirtualMachinePlatform (PowerShell 7–safe enablement)
      • Disables PowerShell paste warning for improved UX

    SAFETY GUARANTEES:
      • No UAC modifications
      • No Windows Update modifications
      • No OneDrive or shell-folder changes
      • No Explorer/session elevation changes
      • No COM calls (PowerShell 7–safe)
      • No destructive registry edits
      • No system-breaking debloat operations
      • All installers wrapped in try/catch
      • All operations idempotent (safe to re-run)

    EXECUTION MODEL:
      • Must be run as Administrator
      • Requires winget (Windows App Installer)
      • WSL enablement uses DISM in a background job
      • WSL installation may require a reboot (prompted automatically)

.PARAMETER InstallWindowsTools
    Installs Git, Windows Terminal, and PowerShell 7.

.PARAMETER InstallDotNet
    Installs .NET SDK 8, 9, and 10.0.101.

.PARAMETER InstallAzure
    Installs Azure CLI, Bicep CLI, and Azure Functions Core Tools.

.EXAMPLE
    # Install everything (default behavior when no switches are provided)
    .\Provision-DevMachine.ps1

.EXAMPLE
    # Install only .NET and Azure tooling
    .\Provision-DevMachine.ps1 -InstallDotNet -InstallAzure

.EXAMPLE
    # Install only Windows developer tools
    .\Provision-DevMachine.ps1 -InstallWindowsTools

.NOTES
    This script is designed for deterministic provisioning and can be safely
    executed multiple times. Missing components are installed; existing ones
    are skipped automatically.

.CHANGELOG
    1.0.0 — Initial documented release
================================================================================
#>

param(
    [switch] $InstallWindowsTools,
    [switch] $InstallDotNet,
    [switch] $InstallAzure
)

# ---------------------------------------------------------------------------
# Admin Check
# ---------------------------------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Generic Dev Machine Provisioning Starting ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Writes a formatted section header for readability.
# Purely cosmetic; no side effects.
function Write-Section {
    param([string] $Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Yellow
}

# Writes a step indicator for sub-operations.
# Purely cosmetic; no side effects.
function Write-Step {
    param([string] $Message)
    Write-Host " → $Message" -ForegroundColor Cyan
}

# Writes a success indicator.
# Purely cosmetic; no side effects.
function Write-Success {
    param([string] $Message)
    Write-Host "   ✔ $Message" -ForegroundColor Green
}

# Writes a warning indicator.
# Non-fatal; used for recoverable errors.
function Write-Warn {
    param([string] $Message)
    Write-Host "   ⚠ $Message" -ForegroundColor DarkYellow
}

# Ensures winget is installed and available.
# Throws a terminating error if missing.
# Safe: does not modify system state.
function Assert-winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required but not found. Please install or update the Windows App Installer from the Store, then re-run this script."
    }
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

Write-Section "Pre-flight checks"

# Ensure script is running in PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)"
}

# Optional: virtualization check (non-fatal)
try {
    $virt = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $virt.HypervisorPresent) {
        Write-Warn "Virtualization is not enabled. WSL2 may not function."
    }
}
catch {
    Write-Warn "Could not verify virtualization support (non-fatal)."
}

# ---------------------------------------------------------------------------
# Disable Paste Warning
# ---------------------------------------------------------------------------

# Disables the PowerShell paste warning for improved UX.
# Safe: modifies only HKCU\Console\PasteWarning.
# Idempotent: safe to run repeatedly.
function Disable-PasteWarning {
    Write-Section "Disabling PowerShell paste warning"
    try {
        Write-Step "Setting HKCU:\Console\PasteWarning = 0"
        if (-not (Test-Path HKCU:\Console)) {
            New-Item -Path HKCU:\Console -Force | Out-Null
        }
        Set-ItemProperty -Path HKCU:\Console -Name "PasteWarning" -Value 0 -Type DWord
        Write-Success "Paste warning disabled"
    }
    catch {
        Write-Warn "Failed to disable paste warning (non-fatal): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# WSL + VirtualMachinePlatform (PS7-safe)
# ---------------------------------------------------------------------------

# Enables WSL + VirtualMachinePlatform using DISM.
# Uses PowerShell 7–safe patterns (no COM).
# Detects existing WSL installations.
# Returns $true if reboot is required.
# Safe: does not reboot automatically.
function Enable-WSLFeatures {
    Write-Section "Enabling WSL + VirtualMachinePlatform"

    # Fast-path: if WSL v2 is already working, do nothing
    try {
        $null = wsl.exe --version 2>$null
        Write-Success "WSL already functional"
        return $false
    }
    catch {}

    Write-Step "Checking feature states..."

    function Get-FeatureState {
        param([string]$Name)
        $output = dism.exe /online /Get-FeatureInfo /FeatureName:$Name 2>$null

        if ($LASTEXITCODE -ne 0) { return "Unknown" }

        if ($output -match "State : Enabled")          { return "Enabled" }
        if ($output -match "State : Enable Pending")   { return "EnablePending" }
        if ($output -match "State : Disabled")         { return "Disabled" }
        if ($output -match "State : Disabled Pending") { return "DisablePending" }
        return "Unknown"
    }

    $wslState = Get-FeatureState "Microsoft-Windows-Subsystem-Linux"
    $vmState  = Get-FeatureState "VirtualMachinePlatform"

    if ($wslState -in @("Enabled","EnablePending") -and
        $vmState  -in @("Enabled","EnablePending"))
    {
        Write-Success "WSL + VirtualMachinePlatform already enabled"
        return $false
    }

    Write-Step "Enabling features via DISM..."

    try {
        $job = Start-Job -ScriptBlock {
            dism.exe /online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /All /NoRestart
            dism.exe /online /Enable-Feature /FeatureName:VirtualMachinePlatform /All /NoRestart
        }

        if (-not (Wait-Job $job -Timeout 300)) {
            Write-Warn "WSL enable operation timed out; features may not be fully enabled."
            Stop-Job $job -Force
            return $false
        }

        Receive-Job $job | Write-Host
        Write-Success "WSL features enabled (pending reboot)"
        return $true
    }
    catch {
        Write-Warn "Failed to enable WSL features (non-fatal): $($_.Exception.Message)"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Windows Baseline
# ---------------------------------------------------------------------------

# Installs Git, Windows Terminal, and PowerShell 7 via winget.
# Safe: winget handles idempotency.
# No system-breaking changes.
function Initialize-WindowsBaseline {
    Write-Section "Installing Windows developer tools"

    Assert-winget

    $apps = @(
        @{ Id = "Git.Git"; Name = "Git" },
        @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7" },
        @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal" }
    )

    foreach ($app in $apps) {
        Write-Step "Installing $($app.Name)..."
        try {
            winget install -e --id $($app.Id) -h `
                --accept-package-agreements --accept-source-agreements
            Write-Success "$($app.Name) installed"
        }
        catch {
            Write-Warn "$($app.Name) may already be installed or install failed: $($_.Exception.Message)"
        }
    }

    $global:WSLRebootRequired = Enable-WSLFeatures
}

# ---------------------------------------------------------------------------
# .NET Baseline (8 + 9)
# ---------------------------------------------------------------------------

# Installs .NET SDK 8 and 9 via winget.
# Safe: winget handles duplicates.
# No registry or system modifications.
function Install-DotNetSdkBaseline {
    Write-Section "Installing .NET SDKs (8 + 9)"

    Assert-winget

    $dotnetSdks = @(
        @{ Id = "Microsoft.DotNet.SDK.8"; Name = ".NET 8 SDK (LTS)" },
        @{ Id = "Microsoft.DotNet.SDK.9"; Name = ".NET 9 SDK (Current)" }
    )

    foreach ($sdk in $dotnetSdks) {
        Write-Step "Installing $($sdk.Name)..."
        try {
            winget install -e --id $($sdk.Id) -h `
                --accept-package-agreements --accept-source-agreements
            Write-Success "$($sdk.Name) installed"
        }
        catch {
            Write-Warn "$($sdk.Name) may already be installed or install failed: $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# .NET 10.0.101 (defensive download/install)
# ---------------------------------------------------------------------------

# Downloads and installs .NET 10.0.101 SDK.
# Defensive: verifies download, wraps installer in try/catch.
# Cleans up installer afterward.
# Safe: does not modify system settings.
function Install-DotNet10 {
    Write-Section "Installing .NET 10 SDK (10.0.101)"

    $url = "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.101/dotnet-sdk-10.0.101-win-x64.exe"
    $installer = Join-Path $env:TEMP "dotnet-sdk-10.0.101-win-x64.exe"

    try {
        Write-Step "Downloading .NET 10 SDK from official builds URL..."
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

        if (-not (Test-Path $installer)) {
            Write-Warn "Download did not produce an installer file. Skipping .NET 10 install."
            return
        }

        Write-Step "Running installer..."
        $process = Start-Process $installer -ArgumentList "/install", "/quiet", "/norestart" -PassThru -Wait

        if ($process.ExitCode -ne 0) {
            Write-Warn ".NET 10 installer exited with code $($process.ExitCode)."
            return
        }

        Write-Success ".NET 10 installation complete"
    }
    catch {
        Write-Warn "Failed to install .NET 10 (non-fatal): $($_.Exception.Message)"
    }
    finally {
        try {
            if (Test-Path $installer) {
                Remove-Item $installer -Force
            }
        }
        catch {
            Write-Warn "Could not clean up .NET 10 installer: $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# Azure Tooling
# ---------------------------------------------------------------------------

# Installs Azure CLI, Bicep CLI, and Azure Functions Core Tools.
# Detects existing Azure CLI before installing.
# Refreshes PATH safely.
# Idempotent and safe.
function Install-AzureDevTools {
    Write-Section "Installing Azure developer tools"

    Assert-winget

    # -----------------------------------------------------------------------
    # Azure CLI
    # -----------------------------------------------------------------------
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Step "Installing Azure CLI..."
        try {
            winget install -e --id Microsoft.AzureCLI -h `
                --accept-package-agreements --accept-source-agreements
        }
        catch {
            Write-Warn "Azure CLI install failed: $($_.Exception.Message)"
        }
    }

    if (Get-Command az -ErrorAction SilentlyContinue) {
        Write-Success "Azure CLI available"
    }
    else {
        Write-Warn "Azure CLI not detected; skipping Bicep + Functions Core Tools."
        return
    }

    # -----------------------------------------------------------------------
    # Refresh PATH (safe)
    # -----------------------------------------------------------------------
    Write-Step "Refreshing PATH for current session..."
    try {
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
    catch {
        Write-Warn "Failed to refresh PATH (non-fatal): $($_.Exception.Message)"
    }

    # -----------------------------------------------------------------------
    # Bicep CLI (with verification)
    # -----------------------------------------------------------------------
    Write-Step "Installing Bicep CLI via 'az bicep install'..."
    try {
        az bicep install
    }
    catch {
        Write-Warn "Bicep install command failed: $($_.Exception.Message)"
    }

    if (az bicep version 2>$null) {
        Write-Success "Bicep installed"
    }
    else {
        Write-Warn "Bicep install attempted but Bicep is not available."
    }

    # -----------------------------------------------------------------------
    # Azure Functions Core Tools (catalog drift–safe)
    # -----------------------------------------------------------------------
    Write-Step "Installing Azure Functions Core Tools..."

    $funcIds = @(
        "Microsoft.Azure.FunctionsCoreTools",
        "Microsoft.Azure.FunctionsCoreTools.4",
        "Microsoft.Azure.FunctionsCoreTools.3"
    )

    $funcInstalled = $false

    foreach ($id in $funcIds) {
        try {
            winget install -e --id $id -h `
                --accept-package-agreements --accept-source-agreements

            if (func --version 2>$null) {
                Write-Success "Functions Core Tools installed"
                $funcInstalled = $true
                break
            }
        }
        catch {
            # Try next ID
        }
    }

    if (-not $funcInstalled) {
        Write-Warn "Functions Core Tools could not be installed (no matching winget package)."
    }
}

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

# Coordinates provisioning based on user parameters.
# Default behavior: install everything if no switches are provided.
# Builds a summary for downstream automation.
# Prompts for reboot only if WSL requires it.
$summary = New-Object System.Collections.Specialized.OrderedDictionary
$global:WSLRebootRequired = $false

Disable-PasteWarning

$noSwitches = (-not $InstallWindowsTools -and -not $InstallDotNet -and -not $InstallAzure)

if ($InstallWindowsTools -or $noSwitches) {
    Initialize-WindowsBaseline
    $summary["WindowsTools"] = "Attempted install (see log for details)"
}

if ($InstallDotNet -or $noSwitches) {
    Install-DotNetSdkBaseline
    Install-DotNet10
    $summary["DotNet"] = "8 + 9 + 10 attempted (see log for details)"
}

if ($InstallAzure -or $noSwitches) {
    Install-AzureDevTools
    $summary["AzureTools"] = "Attempted install (see log for details)"
}

Write-Section "Provisioning summary"

if ($summary.Count -eq 0) {
    Write-Host "No provisioning actions were requested." -ForegroundColor Yellow
}
else {
    foreach ($key in $summary.Keys) {
        Write-Host "$key : $($summary[$key])"
    }
}

Write-Host ""
Write-Host "Generic dev machine provisioning completed." -ForegroundColor Cyan

if ($global:WSLRebootRequired) {
    Write-Host ""
    Write-Host "A reboot is required to complete WSL installation." -ForegroundColor Yellow
    $choice = Read-Host "Reboot now? (Y/N)"

    if ($choice -match '^[Yy]$') {
        try {
            Restart-Computer
        }
        catch {
            Write-Warn "Failed to initiate reboot: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Reboot skipped. Please reboot manually later." -ForegroundColor Yellow
    }
}
