# =====================================================================
# Repos Backup Script (Interruptible, Deterministic, Dependency-Free)
# With Progress Bars
# =====================================================================

$LocalRepos      = "C:\Users\wayne\source\repos"
$BackupRoot      = "C:\Users\wayne\OneDrive\Backups\repos"
$TempStaging     = "C:\Users\wayne\repos-backup-staging"

$Timestamp       = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$ArchiveName     = "repos-clean-$Timestamp.zip"
$ArchivePath     = Join-Path $BackupRoot $ArchiveName

# Expanded exclusion list (dependencies + build artifacts)
$ExcludeDirs = @(
    # JS/TS
    "node_modules", ".pnp", ".yarn", ".yarn/cache", ".yarn/unplugged",

    # Python
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".venv", "venv", ".tox",

    # .NET
    "bin", "obj", "packages", ".vs",

    # Rust
    "target",

    # Java
    ".gradle", "build", "out",

    # Go
    "pkg", "bin",

    # General build/cache
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
# Pre-run cleanup (delete partial backups)
# ---------------------------------------------------------------------
Write-Host "Performing pre-run cleanup..."

if (Test-Path $TempStaging) {
    Write-Host "Removing leftover staging folder..."
    Remove-Item -Path $TempStaging -Recurse -Force
}

Get-ChildItem -Path $BackupRoot -Filter "*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -lt 1024 } | ForEach-Object {
        Write-Host "Removing partial ZIP: $($_.FullName)"
        Remove-Item $_.FullName -Force
    }

# ---------------------------------------------------------------------
# Main backup logic
# ---------------------------------------------------------------------
try {
    if (-not (Test-Path $LocalRepos)) {
        throw "Local repos folder not found at $LocalRepos"
    }

    New-Item -ItemType Directory -Path $TempStaging | Out-Null

    Write-Host "Enumerating files..."

    # Enumerate all files first for progress bar
    $allItems = Get-ChildItem -Path $LocalRepos -Recurse -Force
    $total = $allItems.Count
    $index = 0

    Write-Host "Copying clean repo contents to staging..."

    foreach ($item in $allItems) {
        if ($script:Interrupted) { throw "Backup interrupted by user" }

        $index++
        $percent = [int](($index / $total) * 100)

        Write-Progress -Activity "Copying files" `
                       -Status "$percent% complete" `
                       -PercentComplete $percent

        $relative = $item.FullName.Substring($LocalRepos.Length).TrimStart("\")
        $parts = $relative -split "\\"

        if ($parts[0] -in $ExcludeDirs) {
            continue
        }

        $dest = Join-Path $TempStaging $relative

        if ($item.PSIsContainer) {
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Path $dest | Out-Null
            }
        } else {
            Copy-Item -Path $item.FullName -Destination $dest -Force
        }
    }

    if ($script:Interrupted) { throw "Backup interrupted by user" }

    if (-not (Test-Path $BackupRoot)) {
        New-Item -ItemType Directory -Path $BackupRoot | Out-Null
    }

    Write-Host "Creating clean backup archive..."

    # ZIP progress approximation
    for ($i = 0; $i -le 100; $i += 5) {
        if ($script:Interrupted) { throw "Backup interrupted by user" }
        Write-Progress -Activity "Creating ZIP archive" `
                       -Status "$i% complete" `
                       -PercentComplete $i
        Start-Sleep -Milliseconds 100
    }

    Compress-Archive -Path $TempStaging -DestinationPath $ArchivePath -Force

    Write-Progress -Activity "Creating ZIP archive" -Completed

    if ($script:Interrupted) { throw "Backup interrupted by user" }

    if (-not (Test-Path $ArchivePath)) {
        throw "Backup archive failed to create."
    }

    $size = (Get-Item $ArchivePath).Length
    Write-Host "Backup created successfully:"
    Write-Host "  $ArchivePath"
    Write-Host "  Size: $size bytes"
}
catch {
    Write-Host "ERROR: $_"

    if (Test-Path $ArchivePath) {
        Write-Host "Removing partial ZIP..."
        Remove-Item $ArchivePath -Force
    }
}
finally {
    if (Test-Path $TempStaging) {
        Write-Host "Cleaning up staging folder..."
        Remove-Item -Path $TempStaging -Recurse -Force
    }

    Unregister-Event -SourceIdentifier ConsoleCancelEventHandler -ErrorAction SilentlyContinue
    Write-Host "Backup script finished."
}
# =====================================================================
