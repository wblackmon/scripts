#!/usr/bin/env pwsh
<# 
    Reset-Ubuntu.ps1
    -----------------
    Deletes and recreates the default WSL distro named "Ubuntu".
    Automatically creates UNIX user: wblackmon
    Automatically sets password: 402640
#>

param(
    [switch]$Backup,
    [switch]$Provision,
    [string]$ProvisionScriptPath = "$HOME\provision.sh"
)

$ErrorActionPreference = 'Stop'

$UserName = "wblackmon"
$Password = "402640"   # <-- Your requested password

Write-Host "`n========== Resetting WSL Ubuntu ==========`n"

# ---------------------------------------------------------------------
# 1. Optional backup
# ---------------------------------------------------------------------
if ($Backup) {
    $backupPath = "$HOME\Ubuntu-backup.tar"
    Write-Host "Exporting existing Ubuntu distro to $backupPath ..."
    wsl --export Ubuntu $backupPath
    Write-Host "Backup complete.`n"
}

# ---------------------------------------------------------------------
# 2. Unregister (delete)
# ---------------------------------------------------------------------
Write-Host "Unregistering (deleting) Ubuntu distro..."
wsl --unregister Ubuntu
Write-Host "Ubuntu distro removed.`n"

# ---------------------------------------------------------------------
# 3. Reinstall Ubuntu from Microsoft Store package
# ---------------------------------------------------------------------
Write-Host "Reinstalling Ubuntu..."

$ubuntuPackage = Get-AppxPackage -Name "*Ubuntu*" | Sort-Object -Property Name | Select-Object -First 1

if (-not $ubuntuPackage) {
    Write-Error "Ubuntu is not installed from the Microsoft Store. Install it first."
    exit 1
}

# Launch Ubuntu to initialize filesystem
Write-Host "Launching Ubuntu for first-time setup..."
Start-Process $ubuntuPackage.InstallLocation\ubuntu.exe

Write-Host "`nWaiting for Ubuntu to initialize..."
Start-Sleep -Seconds 5

# ---------------------------------------------------------------------
# 4. Create UNIX user and set password
# ---------------------------------------------------------------------
Write-Host "Creating UNIX user '$UserName'..."

# Create the user with home directory and bash shell
wsl -d Ubuntu -u root -- useradd -m -s /bin/bash $UserName

# Set password
Write-Host "Setting password for '$UserName'..."
$passwdInput = "$Password`n$Password`n"
$passwdInput | wsl -d Ubuntu -u root -- passwd $UserName

# ---------------------------------------------------------------------
# 5. Set default user in /etc/wsl.conf
# ---------------------------------------------------------------------
Write-Host "Setting '$UserName' as the default user..."

wsl -d Ubuntu -u root -- bash -c "echo '[user]' > /etc/wsl.conf"
wsl -d Ubuntu -u root -- bash -c "echo 'default=$UserName' >> /etc/wsl.conf"

# ---------------------------------------------------------------------
# 6. Set Ubuntu as default distro
# ---------------------------------------------------------------------
Write-Host "Setting Ubuntu as the default WSL distro..."
wsl --set-default Ubuntu

# ---------------------------------------------------------------------
# 7. Optional: run provisioning script
# ---------------------------------------------------------------------
if ($Provision) {
    if (-not (Test-Path $ProvisionScriptPath)) {
        Write-Error "Provision script not found at: $ProvisionScriptPath"
        exit 1
    }

    Write-Host "Copying provisioning script into Ubuntu..."
    wsl -d Ubuntu --exec mkdir -p /home/$UserName/provision
    wsl -d Ubuntu --exec rm -f /home/$UserName/provision/provision.sh

    # FIXED: PowerShell-safe streaming into WSL
    Get-Content $ProvisionScriptPath | wsl -d Ubuntu --exec bash -c "cat > /home/$UserName/provision/provision.sh"

    wsl -d Ubuntu --exec chmod +x /home/$UserName/provision/provision.sh

    Write-Host "Running provisioning script inside Ubuntu..."
    wsl -d Ubuntu --exec bash -c "/home/$UserName/provision/provision.sh"
}

Write-Host "`n========== Ubuntu Reset Complete ==========`n"
Write-Host "Ubuntu is now fresh, default, and using UNIX user: $UserName"
Write-Host "Password has been set to: $Password"
