<#
.SYNOPSIS
    Hardened installer for:
      - Office 2021 Pro Plus (VL)
      - Project Professional 2024 (VL)
      - Visio Professional 2024 (VL)

    Features:
      - Auto-download ODT
      - Validates file size
      - Detects HTML/invalid downloads
      - Auto-fallback to manual ODT mode
      - Safe extraction to C:\ODT
      - Combined XML generation
      - Silent install + auto-activation
#>

# ---------------------------------------------------------
# Helper functions
# ---------------------------------------------------------
function Write-Section { param($t) ; Write-Host "`n========== $t ==========`n" -ForegroundColor Cyan }
function Write-Step    { param($m) ; Write-Host " → $m" -ForegroundColor Yellow }
function Write-Ok      { param($m) ; Write-Host "   ✔ $m" -ForegroundColor Green }
function Write-Err     { param($m) ; Write-Host "   ✖ $m" -ForegroundColor Red }

# ---------------------------------------------------------
# Admin check
# ---------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Err "This script must be run as Administrator."
    exit 1
}

Write-Host "`n=== Office Suite Installer (Office 2021 + Project 2024 + Visio 2024) ===`n" -ForegroundColor Cyan

# ---------------------------------------------------------
# 1. Attempt ODT download (with fallback)
# ---------------------------------------------------------
Write-Section "ODT Download Phase"

$odtUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
$odtExe = "$env:TEMP\odt.exe"
$odtDir = "C:\ODT"

$downloadSuccess = $false

# Try CDN download
Write-Step "Attempting CDN download..."
try {
    Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing -Headers @{
        "Cache-Control"="no-cache"
        "Pragma"="no-cache"
    }
    $size = (Get-Item $odtExe).Length
    if ($size -gt 3000000 -and $size -lt 10000000) {
        Write-Ok "CDN download succeeded ($size bytes)"
        $downloadSuccess = $true
    }
    else {
        Write-Err "CDN download returned invalid file ($size bytes)"
    }
}
catch {
    Write-Err "CDN download failed: $($_.Exception.Message)"
}

# Try Microsoft Download Center fallback
if (-not $downloadSuccess) {
    Write-Step "Trying Microsoft Download Center fallback..."
    $fallbackUrl = "https://download.microsoft.com/download/2/7/A/27A8F67C-5F5F-4F0A-8C3C-6D8C8F7D5C5D/officedeploymenttool.exe"
    try {
        Invoke-WebRequest -Uri $fallbackUrl -OutFile $odtExe -UseBasicParsing
        $size = (Get-Item $odtExe).Length
        if ($size -gt 3000000 -and $size -lt 10000000) {
            Write-Ok "Fallback download succeeded ($size bytes)"
            $downloadSuccess = $true
        }
        else {
            Write-Err "Fallback download returned invalid file ($size bytes)"
        }
    }
    catch {
        Write-Err "Fallback download failed: $($_.Exception.Message)"
    }
}

# Auto-fallback to manual ODT mode
if (-not $downloadSuccess) {
    Write-Err "All downloads failed — switching to manual ODT mode."
    if (!(Test-Path "$odtDir\officedeploymenttool.exe")) {
        Write-Err "Manual ODT not found at C:\ODT\officedeploymenttool.exe"
        Write-Host "`nPlace officedeploymenttool.exe in C:\ODT and re-run the script." -ForegroundColor Yellow
        exit 1
    }
    Write-Ok "Manual ODT detected — proceeding with extraction."
    Copy-Item "$odtDir\officedeploymenttool.exe" $odtExe -Force
}

# ---------------------------------------------------------
# 2. Extract ODT
# ---------------------------------------------------------
Write-Section "Extracting ODT"

New-Item -ItemType Directory -Force -Path $odtDir | Out-Null

Write-Step "Running extractor..."
Start-Process -FilePath $odtExe -ArgumentList "/quiet", "/extract:$odtDir" -Wait

if (!(Test-Path "$odtDir\setup.exe")) {
    Write-Err "Extraction failed — setup.exe not found in ${odtDir}"
    Write-Host "Contents of ${odtDir}:" -ForegroundColor DarkYellow
    Get-ChildItem $odtDir
    exit 1
}

Write-Ok "Extraction successful"

# ---------------------------------------------------------
# 3. Write combined XML
# ---------------------------------------------------------
Write-Section "Writing Office Suite XML"

$configPath = "C:\office-suite.xml"

@"
<Configuration>
  <Add OfficeClientEdition="64" Channel="PerpetualVL2021">
    <Product ID="ProPlus2021Volume">
      <Language ID="en-us" />
      <Property Name="PIDKEY" Value="BPC3N-V6J47-8WQ8X-P6YBW-DGQTW" />
      <Property Name="AUTOACTIVATE" Value="1" />
    </Product>
  </Add>

  <Add OfficeClientEdition="64" Channel="PerpetualVL2024">
    <Product ID="ProjectPro2024Volume">
      <Language ID="en-us" />
      <Property Name="PIDKEY" Value="NDYBY-Q7RRF-RFD43-WRK9W-78WJD" />
      <Property Name="AUTOACTIVATE" Value="1" />
    </Product>
  </Add>

  <Add OfficeClientEdition="64" Channel="PerpetualVL2024">
    <Product ID="VisioPro2024Volume">
      <Language ID="en-us" />
      <Property Name="PIDKEY" Value="FN698-RPWKT-V4RVP-WCMVF-37DY6" />
      <Property Name="AUTOACTIVATE" Value="1" />
    </Product>
  </Add>

  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@ | Set-Content $configPath -Encoding UTF8

Write-Ok "XML written to $configPath"

# ---------------------------------------------------------
# 4. Install Office Suite
# ---------------------------------------------------------
Write-Section "Installing Office Suite"

$setup = "$odtDir\setup.exe"

Start-Process -FilePath $setup -ArgumentList "/configure `"$configPath`"" -Verb RunAs -Wait

Write-Ok "Installation process completed"

# ---------------------------------------------------------
# 5. Activation check
# ---------------------------------------------------------
Write-Section "Activation Status"

$ospp = "C:\Program Files\Microsoft Office\Office16\OSPP.VBS"

if (Test-Path $ospp) {
    cscript.exe //nologo $ospp /dstatus
} else {
    Write-Host "OSPP.VBS not found — Office may not be installed in the default path." -ForegroundColor DarkYellow
}

Write-Host "`n=== Office Suite provisioning complete ===`n" -ForegroundColor Cyan
