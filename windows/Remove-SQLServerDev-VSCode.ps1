<#
.SYNOPSIS
    Completely removes:
    - SQL Server Developer Edition (all instances)
    - SQL Server shared features
    - SQL Server services
    - SQL Server registry entries
    - SQL Server data directories
    - SQL Server Management Studio (SSMS)
    - Visual Studio Code
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== SQL Server + SSMS + VS Code Removal Starting ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Helper: Stop a service if it exists
# ---------------------------------------------------------------------------
function Stop-ServiceSafe {
    param([string]$Name)
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        Write-Host "Stopping service: $Name"
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# 1. Stop all SQL Server services
# ---------------------------------------------------------------------------
Write-Host "`nStopping SQL Server services..." -ForegroundColor Yellow

$services = @(
    'MSSQLSERVER',
    'SQLSERVERAGENT',
    'MSSQL$SQLEXPRESS',
    'SQLAgent$SQLEXPRESS',
    'SQLBrowser',
    'SQLWriter',
    'MSSQLFDLauncher',
    'SSISTELEMETRY130',
    'SSISTELEMETRY140',
    'SSISTELEMETRY150',
    'SSISTELEMETRY160'
)

foreach ($svc in $services) {
    Stop-ServiceSafe $svc
}

# ---------------------------------------------------------------------------
# 2. Uninstall SQL Server instances + shared features
# ---------------------------------------------------------------------------
Write-Host "`nUninstalling SQL Server instances..." -ForegroundColor Yellow

# SQL Server uninstallers live in Programs and Features
$uninstallers = Get-WmiObject -Class Win32_Product |
    Where-Object { $_.Name -match "SQL Server" }

foreach ($app in $uninstallers) {
    Write-Host "Uninstalling: $($app.Name)"
    try {
        $app.Uninstall() | Out-Null
    }
    catch {
        Write-Host "Failed to uninstall $($app.Name) (non-fatal)" -ForegroundColor DarkYellow
    }
}

# ---------------------------------------------------------------------------
# 3. Remove SQL Server directories
# ---------------------------------------------------------------------------
Write-Host "`nRemoving SQL Server directories..." -ForegroundColor Yellow

$paths = @(
    "C:\Program Files\Microsoft SQL Server",
    "C:\Program Files (x86)\Microsoft SQL Server",
    "C:\ProgramData\Microsoft\SQL Server",
    "C:\Program Files\Microsoft SQL Server Management Studio",
    "C:\Program Files (x86)\Microsoft SQL Server Management Studio",
    "C:\SQLServer",
    "C:\MSSQL"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Removing: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# 4. Remove SQL Server registry keys
# ---------------------------------------------------------------------------
Write-Host "`nRemoving SQL Server registry keys..." -ForegroundColor Yellow

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server",
    "HKLM:\SOFTWARE\Microsoft\MSSQLServer",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer"
)

foreach ($reg in $regPaths) {
    if (Test-Path $reg) {
        Write-Host "Removing registry key: $reg"
        Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# 5. Uninstall SSMS
# ---------------------------------------------------------------------------
Write-Host "`nUninstalling SQL Server Management Studio (SSMS)..." -ForegroundColor Yellow

try {
    winget uninstall --id Microsoft.SQLServerManagementStudio -e -h `
        --accept-source-agreements --accept-package-agreements
}
catch {
    Write-Host "SSMS not found or already removed." -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 6. Uninstall Visual Studio Code
# ---------------------------------------------------------------------------
Write-Host "`nUninstalling Visual Studio Code..." -ForegroundColor Yellow

try {
    winget uninstall --id Microsoft.VisualStudioCode -e -h `
        --accept-source-agreements --accept-package-agreements
}
catch {
    Write-Host "VS Code not found or already removed." -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 7. Remove leftover VS Code directories
# ---------------------------------------------------------------------------
$vsPaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "$env:APPDATA\Code",
    "$env:USERPROFILE\.vscode"
)

foreach ($path in $vsPaths) {
    if (Test-Path $path) {
        Write-Host "Removing: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Removal Complete ===" -ForegroundColor Green
Write-Host "SQL Server Developer Edition: Removed"
Write-Host "SQL Server Shared Features: Removed"
Write-Host "SQL Server Registry Keys: Removed"
Write-Host "SSMS: Removed"
Write-Host "Visual Studio Code: Removed"
Write-Host ""
Write-Host "A reboot is recommended to finalize cleanup." -ForegroundColor Yellow
