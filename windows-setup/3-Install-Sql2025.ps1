<#
.SYNOPSIS
    Installs SQL Server 2025 Developer Edition (silent) + SSMS.
    - SQL 2025 installs as the default instance (MSSQLSERVER)
    - SSMS installed via Winget
    - Idempotent: skips install if SQL already exists

.NOTES
    - Run as Administrator
    - Works in PowerShell 7+
#>

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

# ---------------------------------------------------------------------------
# Helper: Section Header
# ---------------------------------------------------------------------------
function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Install SQL Server 2025 Developer Edition
# ---------------------------------------------------------------------------
function Install-Sql2025Developer {
    Write-Section "SQL Server 2025 Developer Edition"

    # Detect existing SQL installation
    $sqlInstalled = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
    if ($sqlInstalled) {
        Write-Host "SQL Server already installed. Skipping SQL installation." -ForegroundColor DarkYellow
        return
    }

    # ------------------------------------------------------------
    # Download SQL Server 2025 Developer Edition
    # ------------------------------------------------------------
    Write-Host "Downloading SQL Server 2025 Developer Edition..." -ForegroundColor Yellow

    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2344711&clcid=0x409&culture=en-us&country=us"
    $installerPath = "$env:TEMP\SQL2025.exe"

    if (-not (Test-Path $installerPath)) {
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-Host "Download complete." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to download SQL installer: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "Installer already exists at $installerPath — skipping download." -ForegroundColor DarkYellow
    }

    # ------------------------------------------------------------
    # Create silent configuration file
    # ------------------------------------------------------------
    Write-Host "Creating SQL Server configuration file..." -ForegroundColor Yellow

    $configPath = "$env:TEMP\SQL2025.ini"

    if (-not (Test-Path $configPath)) {
@"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME="MSSQLSERVER"
SECURITYMODE="SQL"
SAPWD="P@ssw0rd123!"
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
SQLSYSADMINACCOUNTS="$env:USERNAME"
IACCEPTSQLSERVERLICENSETERMS="True"
QUIET="True"
"@ | Out-File -FilePath $configPath -Encoding ASCII

        Write-Host "Configuration file created." -ForegroundColor Green
    }
    else {
        Write-Host "Config file already exists — reusing $configPath" -ForegroundColor DarkYellow
    }

    # ------------------------------------------------------------
    # Install SQL Server
    # ------------------------------------------------------------
    Write-Host "Installing SQL Server 2025 Developer Edition..." -ForegroundColor Yellow

    try {
        Start-Process -FilePath $installerPath -ArgumentList "/ConfigurationFile=$configPath" -Wait
        Write-Host "SQL Server 2025 installation complete." -ForegroundColor Green
    }
    catch {
        Write-Host "SQL installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------------
# Install SSMS
# ---------------------------------------------------------------------------
function Install-SSMS {
    Write-Section "SQL Server Management Studio (SSMS 22)"

    # Check if SSMS is already installed
    $ssmsInstalled = winget list --id Microsoft.SQLServerManagementStudio.22 -q 2>$null

    if ($ssmsInstalled -match "Microsoft SQL Server Management Studio") {
        Write-Host "SSMS 22 already installed. Skipping." -ForegroundColor DarkYellow
        return
    }

    try {
        winget install -e --id Microsoft.SQLServerManagementStudio.22 -h `
            --accept-package-agreements --accept-source-agreements
        Write-Host "SSMS 22 installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "SSMS installation failed or skipped: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# ---------------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------------
Install-Sql2025Developer
Install-SSMS

Write-Host ""
Write-Host "SQL Server 2025 Developer Edition + SSMS installation complete." -ForegroundColor Cyan
Write-Host ""
