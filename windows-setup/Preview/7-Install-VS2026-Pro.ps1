<#
    Visual Studio 2026 Installer (Professional Edition)
    Wayne Edition – .NET + Azure + Web + SQL
#>

# ============================================================
# CONFIGURATION
# ============================================================

# Replace with the real 2026 bootstrapper URL when published
$BootstrapperUrl = "https://aka.ms/vs/2026/release/vs_Professional.exe"

$InstallPath = "C:\Program Files\Microsoft Visual Studio\2026\Professional"
$BootstrapperPath = Join-Path $env:TEMP "vs2026_pro_setup.exe"
$MaxDownloadAttempts = 5

$Workloads = @(
    "Microsoft.VisualStudio.Workload.ManagedDesktop"
    "Microsoft.VisualStudio.Workload.NetWeb"
    "Microsoft.VisualStudio.Workload.NetCoreTools"
    "Microsoft.VisualStudio.Workload.Azure"
    "Microsoft.VisualStudio.Workload.Data"
)

$Components = @(
    "Microsoft.VisualStudio.Component.WebAssemblyTools"
    "Microsoft.NetCore.Component.Runtime.8.0"
    "Microsoft.NetCore.Component.Runtime.9.0"
    "Microsoft.NetCore.Component.Runtime.10.0"
    "Microsoft.Net.Component.4.8.SDK"
    "Microsoft.Net.Component.4.8.TargetingPack"
)

# ============================================================
# ENVIRONMENT CHECK
# ============================================================

if ($PSVersionTable.PSEdition -ne "Core") {
    Write-Host "PowerShell 7 is required." -ForegroundColor Red
    exit 1
}

function Log { param([string]$m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" }

function Download-WithRetry {
    param([string]$Url, [string]$OutFile, [int]$MaxAttempts = 5)

    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            Log "Download attempt $attempt..."
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop
            if ((Get-Item $OutFile).Length -gt 1MB) { return }
            throw "Downloaded file too small."
        }
        catch {
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
            if ($attempt -lt $MaxAttempts) { Start-Sleep 3 }
            $attempt++
        }
    }
    throw "Failed to download bootstrapper."
}

# ============================================================
# DOWNLOAD
# ============================================================

Log "Downloading Visual Studio 2026 Professional bootstrapper..."
Download-WithRetry -Url $BootstrapperUrl -OutFile $BootstrapperPath -MaxAttempts $MaxDownloadAttempts

# ============================================================
# INSTALL
# ============================================================

$Args = @(
    "--quiet", "--wait", "--norestart",
    "--installPath", "`"$InstallPath`"",
    "--includeRecommended"
)

foreach ($w in $Workloads) { $Args += "--add"; $Args += $w }
foreach ($c in $Components) { $Args += "--add"; $Args += $c }

Log "Starting installation..."
Start-Process -FilePath $BootstrapperPath -ArgumentList $Args -Wait

# ============================================================
# CLEANUP
# ============================================================

if (Test-Path $BootstrapperPath) { Remove-Item $BootstrapperPath -Force }

Log "Visual Studio 2026 Professional installation complete."
Write-Host "Reboot recommended." -ForegroundColor Yellow
