<#
    Break-Symlink-And-Restore-Local-Repos.ps1
    -----------------------------------------
    Steps:
        0. Create timestamped ZIP backup (only if no repos_*.zip exists)
        1. Create a temporary real folder (repos_real)
        2. Copy files from OneDrive\repos → repos_real with progress bar
        3. Remove the symlink at source\repos
        4. Rename repos_real → repos
#>

Write-Host "=== Starting repos backup + symlink removal ===" -ForegroundColor Cyan

$LocalRoot   = "C:\Users\wayne\source"
$RealFolder  = Join-Path $LocalRoot "repos_real"
$LinkFolder  = Join-Path $LocalRoot "repos"
$OneDriveSrc = "C:\Users\wayne\OneDrive\repos"
$ZipShare    = "C:\Users\wayne\OneDrive\ZipShare"

# Step 0 — Backup ZIP (skip if ANY repos_*.zip exists)
$existingZip = Get-ChildItem $ZipShare -Filter "repos_*.zip" -ErrorAction SilentlyContinue

if ($existingZip) {
    Write-Host "A repos backup ZIP already exists in ZipShare. Skipping compression." -ForegroundColor Yellow
} else {
    $ts  = Get-Date -Format "yyyyMMdd-HHmmss"
    $zip = Join-Path $ZipShare "repos_$ts.zip"

    Write-Host "Creating backup ZIP: $zip"
    Compress-Archive -Path $OneDriveSrc -DestinationPath $zip -Force
    Write-Host "Backup complete." -ForegroundColor Green
}

# Step 1 — Create a real folder
if (!(Test-Path $RealFolder)) {
    Write-Host "Creating real folder: $RealFolder"
    New-Item -ItemType Directory -Path $RealFolder | Out-Null
} else {
    Write-Host "Real folder already exists: $RealFolder" -ForegroundColor Yellow
}

# Step 2 — Copy files with progress bar
Write-Host "Copying files from OneDrive to real folder with progress..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $OneDriveSrc -Recurse -File
$total = $files.Count
$index = 0

foreach ($file in $files) {
    $index++
    $percent = [math]::Round(($index / $total) * 100, 2)

    Write-Progress `
        -Activity "Copying repos from OneDrive" `
        -Status "$percent% complete ($index of $total)" `
        -PercentComplete $percent

    $dest = $file.FullName.Replace($OneDriveSrc, $RealFolder)
    $destDir = Split-Path $dest

    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item $file.FullName $dest -Force
}

Write-Progress -Activity "Copying repos from OneDrive" -Completed
Write-Host "Copy complete." -ForegroundColor Green

# Step 3 — Remove the symlink
$item = Get-Item $LinkFolder
if ($item.LinkType -eq "SymbolicLink") {
    Write-Host "Removing symlink: $LinkFolder"
    Remove-Item $LinkFolder -Force
    Write-Host "Symlink removed." -ForegroundColor Yellow
} else {
    Write-Host "WARNING: $LinkFolder is not a symlink." -ForegroundColor Red
}

# Step 4 — Rename repos_real → repos
Write-Host "Renaming $RealFolder to $LinkFolder"
Rename-Item $RealFolder "repos"
Write-Host "Rename complete." -ForegroundColor Green

Write-Host "=== Local repos restored successfully ===" -ForegroundColor Cyan
