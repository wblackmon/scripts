# =====================================================================
# Repos Differential Backup Script (One ZIP Per Day)
# Interruptible • Deterministic • Exclusion-Aware • Progress Bars
# =====================================================================

$LocalRepos      = "C:\Users\wayne\source\repos"
$BackupRoot      = "C:\Users\wayne\OneDrive\Backups\repos"
$TempStaging     = "C:\Users\wayne\repos-backup-staging"

$TodayStamp      = (Get-Date).ToString("yyyy-MM-dd")
$ArchiveName     = "repos-clean-$TodayStamp.zip"
$ArchivePath     = Join-Path $BackupRoot $ArchiveName

# Expanded exclusion list (dependencies + build artifacts)
$ExcludeDirs = @(
    "node_modules", ".pnp", ".yarn", ".yarn/cache", ".yarn/unplugged",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".venv", "venv", ".tox",
    "bin", "obj", "packages", ".vs",
    "target",
    ".gradle", "build", "out",
    "pkg", "bin",
    "dist", "coverage", "logs", ".cache", ".parcel-cache",
    ".next", ".nuxt", ".svelte-kit", ".angular", ".vite", ".rollup.cache"
)

# ---------------------------------------------------------------------
# Ctrl+C handler
# ---------------------------------------------------------------------
$script:Interrupted = $false

$null = Register-EngineEvent -SourceIdentifier ConsoleCancelEventHandler -Action {
    Write-Host "`nInterrupt received — cleaning up..."
    $script:Interrupted = $true
}

# ---------------------------------------------------------------------
# Pre-run cleanup
# ---------------------------------------------------------------------
Write-Host "Performing pre-run cleanup..."

if (Test-Path $TempStaging) {
    Write-Host "Removing leftover staging folder..."
    Remove-Item -Path $TempStaging -Recurse -Force
}

# Remove partial ZIPs (tiny or zero-byte)
Get-ChildItem -Path $BackupRoot -Filter "*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -lt 1024 } | ForEach-Object {
        Write-Host "Removing partial ZIP: $($_.FullName)"
        Remove-Item $_.FullName -Force
    }

# ---------------------------------------------------------------------
# Determine backup mode: full or differential
# ---------------------------------------------------------------------
$IsDifferential = Test-Path $ArchivePath

if ($IsDifferential) {
    Write-Host "Today's archive found — performing differential backup."
} else {
    Write-Host "No archive for today — performing full backup."
}

# ---------------------------------------------------------------------
# Load existing ZIP file list (for differential mode)
# ---------------------------------------------------------------------
$ExistingFiles = @{}

if ($IsDifferential) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

    foreach ($entry in $zip.Entries) {
        $ExistingFiles[$entry.FullName] = @{
            Name = $entry.FullName
            Size = $entry.Length
            Time = $entry.LastWriteTime.UtcDateTime
        }
    }

    $zip.Dispose()
}

# ---------------------------------------------------------------------
# Enumerate local repo files
# ---------------------------------------------------------------------
Write-Host "Enumerating files..."

$allItems = Get-ChildItem -Path $LocalRepos -Recurse -Force
$total = $allItems.Count
$index = 0

# Create staging folder
New-Item -ItemType Directory -Path $TempStaging | Out-Null

Write-Host "Copying changed/new files to staging..."

foreach ($item in $allItems) {
    if ($script:Interrupted) { throw "Backup interrupted by user" }

    $index++
    $percent = [int](($index / $total) * 100)

    Write-Progress -Activity "Scanning files" `
                   -Status "$percent% complete" `
                   -PercentComplete $percent

    $relative = $item.FullName.Substring($LocalRepos.Length).TrimStart("\")
    $parts = $relative -split "\\"

    # Skip excluded directories
    if ($parts[0] -in $ExcludeDirs) {
        continue
    }

    # Full backup: copy everything
    if (-not $IsDifferential) {
        $dest = Join-Path $TempStaging $relative

        if ($item.PSIsContainer) {
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Path $dest | Out-Null
            }
        } else {
            Copy-Item -Path $item.FullName -Destination $dest -Force
        }

        continue
    }

    # Differential backup: only changed/new files
    if ($item.PSIsContainer) { continue }

    $exists = $ExistingFiles.ContainsKey($relative)

    if ($exists) {
        $prev = $ExistingFiles[$relative]

        $changed = (
            ($item.Length -ne $prev.Size) -or
            ($item.LastWriteTimeUtc -ne $prev.Time)
        )

        if (-not $changed) {
            continue
        }
    }

    # New or changed file → copy to staging
    $dest = Join-Path $TempStaging $relative
    $destDir = Split-Path $dest -Parent

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    Copy-Item -Path $item.FullName -Destination $dest -Force
}

Write-Progress -Activity "Scanning files" -Completed

if ($script:Interrupted) { throw "Backup interrupted by user" }

# ---------------------------------------------------------------------
# Create or update ZIP
# ---------------------------------------------------------------------
Write-Host "Updating backup archive..."

Add-Type -AssemblyName System.IO.Compression.FileSystem

if ($IsDifferential) {
    # Append changed files into existing ZIP
    $zip = [System.IO.Compression.ZipFile]::Open($ArchivePath, "Update")

    foreach ($file in Get-ChildItem -Path $TempStaging -Recurse -File) {
        if ($script:Interrupted) { throw "Backup interrupted by user" }

        $relative = $file.FullName.Substring($TempStaging.Length).TrimStart("\")
        $entry = $zip.GetEntry($relative)

        if ($entry) {
            $entry.Delete()
        }

        $zip.CreateEntryFromFile($file.FullName, $relative)
    }

    $zip.Dispose()
}
else {
    # Full backup ZIP creation
    Compress-Archive -Path $TempStaging -DestinationPath $ArchivePath -Force
}

if ($script:Interrupted) { throw "Backup interrupted by user" }

# ---------------------------------------------------------------------
# Cleanup staging
# ---------------------------------------------------------------------
Remove-Item -Path $TempStaging -Recurse -Force

Write-Host "Backup completed successfully:"
Write-Host "  $ArchivePath"
Write-Host "  Size: $((Get-Item $ArchivePath).Length) bytes"

# ---------------------------------------------------------------------
# Final cleanup
# ---------------------------------------------------------------------
Unregister-Event -SourceIdentifier ConsoleCancelEventHandler -ErrorAction SilentlyContinue
Write-Host "Backup script finished."
# =====================================================================
