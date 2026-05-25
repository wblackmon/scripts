Write-Host "=== Optimizing Visual Studio 2026 (Minimal + Safe) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# PART 1 — Clear Visual Studio Caches (Fixes sluggish IntelliSense)
# ---------------------------------------------------------------------------
Write-Host "`n=== Clearing Visual Studio Caches ===" -ForegroundColor Yellow

$vsPaths = @(
    "$env:LOCALAPPDATA\Microsoft\VisualStudio",
    "$env:LOCALAPPDATA\Microsoft\VSCommon",
    "$env:APPDATA\Microsoft\VisualStudio"
)

foreach ($path in $vsPaths) {
    if (Test-Path $path) {
        Write-Host "Cleaning: $path"
        Get-ChildItem -Path $path -Recurse -Include ComponentModelCache, MEFCache, Cache, Temp, *.db -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# PART 2 — Disable CodeLens (Major CPU/RAM win)
# ---------------------------------------------------------------------------
Write-Host "`n=== Disabling CodeLens ===" -ForegroundColor Yellow

$regPath = "HKCU:\Software\Microsoft\VisualStudio\17.0\CodeLens"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "EnableCodeLens" -Value 0

# ---------------------------------------------------------------------------
# PART 3 — Disable Full Solution Analysis (Huge IntelliSense boost)
# ---------------------------------------------------------------------------
Write-Host "`n=== Disabling Full Solution Analysis ===" -ForegroundColor Yellow

$analysisPath = "HKCU:\Software\Microsoft\VisualStudio\17.0\Roslyn\Internal\Performance"
New-Item -Path $analysisPath -Force | Out-Null
Set-ItemProperty -Path $analysisPath -Name "FullSolutionAnalysis" -Value 0

# ---------------------------------------------------------------------------
# PART 4 — Disable Live Share (if not used)
# ---------------------------------------------------------------------------
Write-Host "`n=== Disabling Live Share ===" -ForegroundColor Yellow

$liveSharePath = "HKCU:\Software\Microsoft\VisualStudio\17.0\LiveShare"
New-Item -Path $liveSharePath -Force | Out-Null
Set-ItemProperty -Path $liveSharePath -Name "EnableLiveShare" -Value 0

# ---------------------------------------------------------------------------
# PART 5 — Improve MSBuild Performance
# ---------------------------------------------------------------------------
Write-Host "`n=== Applying MSBuild Performance Tweaks ===" -ForegroundColor Yellow

$propsPath = "$env:USERPROFILE\source\repos\Directory.Build.props"

if (-not (Test-Path $propsPath)) {
    Write-Host "Creating Directory.Build.props at $propsPath"
    @"
<Project>
  <PropertyGroup>
    <Deterministic>true</Deterministic>
    <ContinuousIntegrationBuild>false</ContinuousIntegrationBuild>
    <UseSharedCompilation>true</UseSharedCompilation>
    <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
    <ProduceReferenceAssembly>false</ProduceReferenceAssembly>
  </PropertyGroup>
</Project>
"@ | Out-File -FilePath $propsPath -Encoding utf8
} else {
    Write-Host "Directory.Build.props already exists — leaving it untouched."
}

# ---------------------------------------------------------------------------
# PART 6 — Disable VS Telemetry (Safe)
# ---------------------------------------------------------------------------
Write-Host "`n=== Disabling Visual Studio Telemetry ===" -ForegroundColor Yellow

$telemetryPath = "HKCU:\Software\Microsoft\VisualStudio\17.0\Telemetry"
New-Item -Path $telemetryPath -Force | Out-Null
Set-ItemProperty -Path $telemetryPath -Name "TurnOffSwitch" -Value 1

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host "`n=== Visual Studio Optimization Complete ===" -ForegroundColor Green
Write-Host "Restart Visual Studio to apply all changes."