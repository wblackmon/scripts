<#
.SYNOPSIS
    Creates a safe symlink for the repos folder:
        C:\Users\wayne\source\repos  →  $env:OneDrive\repos

.DESCRIPTION
    - Creates OneDrive\repos if missing
    - Backs up the original repos folder once (repos_backup)
    - Creates a symlink at the original location
    - Idempotent: safe to run repeatedly
    - No destructive deletes
    - No OneDrive or shell-folder changes
#>

Write-Host "`n========== Setting Up Repos Symlink ==========`n"

function Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

$orig  = "C:\Users\wayne\source\repos"
$dest  = "$env:OneDrive\repos"
$backup = "${orig}_backup"

Log "Original path : $orig"
Log "OneDrive path : $dest"
Write-Host ""

# ------------------------------------------------------------
# Ensure OneDrive destination exists
# ------------------------------------------------------------
if (-not (Test-Path $dest)) {
    Log "Creating OneDrive repos folder..."
    try {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    catch {
        Log "Failed to create OneDrive folder: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Log "OneDrive repos folder already exists."
}

# ------------------------------------------------------------
# If original is already a symlink → skip
# ------------------------------------------------------------
if ((Test-Path $orig) -and (Get-Item $orig).LinkType) {
    Log "Repos folder is already a symlink. Nothing to do."
    Write-Host ""
    exit 0
}

# ------------------------------------------------------------
# If original exists and is NOT a symlink → back it up
# ------------------------------------------------------------
if (Test-Path $orig -PathType Container) {
    if (-not (Test-Path $backup)) {
        Log "Backing up original repos folder → $backup"
        try {
            Rename-Item -Path $orig -NewName $backup -ErrorAction Stop
        }
        catch {
            Log "Backup failed: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Log "Backup folder already exists. Skipping backup."
    }
}

# ------------------------------------------------------------
# Create symlink
# ------------------------------------------------------------
Log "Creating symlink:"
Log "  Link   : $orig"
Log "  Target : $dest"

try {
    New-Item -ItemType SymbolicLink -Path $orig -Target $dest -Force | Out-Null
    Log "Symlink created successfully."
}
catch {
    Log "Failed to create symlink: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Log "========== Repos Symlink Setup Complete ==========`n"
