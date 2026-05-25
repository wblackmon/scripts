<#
    Script: NightlyBackup-7zip-OneDrive.ps1
    Purpose:
        - Create nightly compressed backups of your repos
        - Store them in OneDrive\ZipShare\repos
        - Show a single-line spinning progress indicator
        - Verify archive creation before reporting success
        - Maintain N days of history

    Requirements:
        - 7-Zip installed at: C:\Program Files\7-Zip\7z.exe
#>

# --- CONFIG ---
$User          = $env:USERNAME
$PCName        = $env:COMPUTERNAME
$Source        = "C:\Users\$User\source\repos"                 # Junction → OneDrive\repos
$BackupRoot    = "C:\Users\$User\OneDrive\ZipShare\repos"      # NEW: repos subfolder
$RetentionDays = 14
$SevenZip      = "C:\Program Files\7-Zip\7z.exe"               # Adjust if needed

# --- Basic validation ---
if (-not (Test-Path $Source)) {
    Write-Host "ERROR: Source path does not exist: $Source"
    exit 1
}

if (-not (Test-Path $SevenZip)) {
    Write-Host "ERROR: 7-Zip not found at: $SevenZip"
    exit 1
}

# --- Ensure backup root exists (including repos subfolder) ---
if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

# --- Timestamped archive name: repos-PCNAME-MM-DD-YYYY_HH-mm-ss.7z ---
$DateStamp   = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"
$SafePCName  = $PCName -replace '[^A-Za-z0-9\-]', '_'   # sanitize
$ArchiveName = "repos-$SafePCName-$DateStamp.7z"
$ArchivePath = Join-Path $BackupRoot $ArchiveName

Write-Host "Starting backup for $PCName"
Write-Host "Source:  $Source"
Write-Host "Target:  $ArchivePath"
Write-Host ""

# --- Start 7-Zip process ---
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $SevenZip
$psi.Arguments              = "a -t7z -mx=9 -mmt=on -ms=on `"$ArchivePath`" `"$Source\*`""
$psi.RedirectStandardOutput = $false
$psi.RedirectStandardError  = $false
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
$null = $process.Start()

# --- One-line spinner ---
$spinner = @('|','/','-','\')
$i = 0
$start = Get-Date

while (-not $process.HasExited) {
    $elapsed = (Get-Date) - $start
    $spin = $spinner[$i % $spinner.Length]

    $msg = "[${spin}] Compressing repos on $PCName — Elapsed: {0:hh\:mm\:ss}" -f $elapsed

    Write-Host -NoNewline "`r$msg"

    Start-Sleep -Milliseconds 120
    $i++
}

# Clear the line after completion
Write-Host "`rCompression finished on $PCName.                "

# --- Check process exit code ---
if ($process.ExitCode -ne 0) {
    Write-Host "ERROR: 7-Zip exited with code $($process.ExitCode). Backup FAILED."
    exit 1
}

# --- Verify archive exists ---
if (-not (Test-Path $ArchivePath)) {
    Write-Host "ERROR: Backup FAILED — archive was not created."
    exit 1
}

Write-Host ""
Write-Host "Backup complete: $ArchivePath"
Write-Host ""

# --- Retention cleanup (only runs if backup succeeded) ---
$Cutoff = (Get-Date).AddDays(-$RetentionDays)

$OldBackups =
    Get-ChildItem $BackupRoot -Filter "repos-*.7z" |
    Where-Object { $_.CreationTime -lt $Cutoff }

foreach ($Backup in $OldBackups) {
    Write-Host "Removing old backup: $($Backup.FullName)"
    Remove-Item $Backup.FullName -Force
}

Write-Host "Retention cleanup complete."
