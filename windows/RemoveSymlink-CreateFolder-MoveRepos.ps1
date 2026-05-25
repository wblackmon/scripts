<#
.SYNOPSIS
    Restores a real repos folder at:
        C:\Users\wayne\source\repos
    AND maintains a backup copy in OneDrive:
        C:\Users\wayne\OneDrive\repos_backup

.DESCRIPTION
    - Removes symlink safely
    - Creates real folder
    - Moves repos from OneDrive into real folder
    - Creates/updates OneDrive backup folder
    - Idempotent and fully observable
#>

Write-Host "`n========== Restoring Real Repos Folder + OneDrive Backup ==========`n"

function Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

$orig        = "C:\Users\wayne\source\repos"
$onedriveSrc = "$env:OneDrive\repos"
$backup      = "$env:OneDrive\repos_backup"

Log "Original repo root : $orig"
Log "OneDrive source    : $onedriveSrc"
Log "OneDrive backup    : $backup"
Write-Host ""

# ------------------------------------------------------------
# Remove symlink if present
# ------------------------------------------------------------
if ((Test-Path $orig) -and (Get-Item $orig).LinkType) {
    Log "Detected symlink at $orig → $((Get-Item $orig).Target)"
    Log "Removing symlink..."
    Remove-Item $orig -Force
    Log "Symlink removed."
}
elseif (Test-Path $orig) {
    Log "Real folder already exists at $orig"
}
else {
    Log "No repos folder found at original location."
}

# ------------------------------------------------------------
# Ensure real folder exists
# ------------------------------------------------------------
if (-not (Test-Path $orig)) {
    Log "Creating real repos folder at $orig"
    New-Item -ItemType Directory -Path $orig | Out-Null
    Log "Real folder created."
}

# ------------------------------------------------------------
# Move repos from OneDrive\repos → real folder
# ------------------------------------------------------------
if (Test-Path $onedriveSrc) {
    Log "Moving repos from OneDrive\repos → real folder..."

    Get-ChildItem $onedriveSrc | ForEach-Object {
        $target = Join-Path $orig $_.Name
        if (-not (Test-Path $target)) {
            Move-Item $_.FullName $target
            Log "Moved: $($_.Name)"
        }
        else {
            Log "Skipped (already exists): $($_.Name)"
        }
    }
}
else {
    Log "No OneDrive\repos folder found. Nothing to move."
}

# ------------------------------------------------------------
# Maintain OneDrive backup folder
# ------------------------------------------------------------
if (-not (Test-Path $backup)) {
    Log "Creating OneDrive backup folder at $backup"
    New-Item -ItemType Directory -Path $backup | Out-Null
}

Log "Updating OneDrive backup..."
robocopy $orig $backup /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
Log "Backup updated."

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------
Write-Host "`n=== FINAL STATE ===" -ForegroundColor Cyan
Log "Real repo root exists: $(Test-Path $orig)"
Log "Backup exists        : $(Test-Path $backup)"
Log "Real folder contents:"
Get-ChildItem $orig | Select-Object Name

Write-Host ""
Log "========== Repo Restoration + Backup Complete ==========`n"
