<#
    Visual Studio 2026 Installer (Enterprise Edition)
    Wayne Edition – .NET + Azure + Web + SQL
    Intelligent Version Detection + Graceful Failure
#>

# ============================================================
# CONFIGURATION
# ============================================================

$BootstrapperUrl = "https://aka.ms/vs/2026/release/vs_Enterprise.exe"
$InstallPath = "C:\Program Files\Microsoft Visual Studio\2026\Enterprise"
$BootstrapperPath = Join-Path $env:TEMP "vs2026_ent_setup.exe"

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

# ============================================================
# INTELLIGENT VERSION CHECK
# ============================================================

Log "Checking if Visual Studio 2026 is published..."

# HEAD request: does the URL exist at all?
try {
    $head = Invoke-WebRequest -Uri $BootstrapperUrl -Method Head -ErrorAction Stop
}
catch {
    Log "Visual Studio 2026 is not available on Microsoft's CDN."
    Log "This version has not been released yet."
    exit 1
}

# Try downloading the file
try {
    Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $BootstrapperPath -ErrorAction Stop
    $size = (Get-Item $BootstrapperPath).Length

    # If the file is tiny, it's HTML or a placeholder
    if ($size -lt 1MB) {
        Log "Bootstrapper URL resolves, but file is invalid (HTML or placeholder)."
        Log "Visual Studio 2026 is not yet published."
        Remove-Item $BootstrapperPath -Force
        exit 1
    }
}
catch {
    Log "Visual Studio 2026 is not yet published."
    exit 1
}

Log "Visual Studio 2026 appears to be published. Proceeding with installation."

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

Log "Visual Studio 2026 Enterprise installation complete (if published)."
Write-Host "Reboot recommended." -ForegroundColor Yellow
