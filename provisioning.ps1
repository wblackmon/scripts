# =====================================================================
#  CleanFeatures Windows 11 Provisioning Script
# =====================================================================

Write-Host "Starting CleanFeatures provisioning..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force

# ---------------------------------------------------------------------
# 1. Disable Windows Update + Driver Updates
# ---------------------------------------------------------------------
Write-Host "Disabling Windows Update and driver updates..." -ForegroundColor Cyan

# Disable Windows Update service
Stop-Service wuauserv -Force
Set-Service wuauserv -StartupType Disabled

# Disable WaaSMedic
Stop-Service WaaSMedicSvc -Force
Set-Service WaaSMedicSvc -StartupType Disabled

# Disable driver updates
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrder /t REG_DWORD /d 0 /f

# ---------------------------------------------------------------------
# 2. Enable Windows sudo
# ---------------------------------------------------------------------
Write-Host "Enabling Windows sudo..." -ForegroundColor Cyan
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v Enabled /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" /v Mode /t REG_DWORD /d 1 /f

# ---------------------------------------------------------------------
# 3. Enforce Developer Mode
# ---------------------------------------------------------------------
Write-Host "Enabling Developer Mode..." -ForegroundColor Cyan
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowAllTrustedApps /t REG_DWORD /d 1 /f

# ---------------------------------------------------------------------
# 4. Install Dell SupportAssist BEFORE updates
# ---------------------------------------------------------------------
Write-Host "Installing Dell SupportAssist..." -ForegroundColor Cyan

$saUrl = "https://downloads.dell.com/serviceability/catalog/SupportAssistInstaller.exe"
$saInstaller = "$env:TEMP\SupportAssistInstaller.exe"

Invoke-WebRequest $saUrl -OutFile $saInstaller
Start-Process $saInstaller -ArgumentList "/S" -Wait

Write-Host "Running SupportAssist scan..." -ForegroundColor Cyan
$saCmd = "C:\Program Files\Dell\SupportAssistAgent\bin\SupportAssistCmd.exe"
if (Test-Path $saCmd) {
    Start-Process $saCmd -ArgumentList "/Scan /Auto" -Wait
}

# ---------------------------------------------------------------------
# 5. Install WSL + Ubuntu
# ---------------------------------------------------------------------
Write-Host "Installing WSL + Ubuntu..." -ForegroundColor Cyan
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
wsl --install -d Ubuntu

# ---------------------------------------------------------------------
# 6. Install Chocolatey + Dev Tools
# ---------------------------------------------------------------------
Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host "Installing development tools..." -ForegroundColor Cyan
choco install -y git vscode docker-desktop azure-cli bicep visualstudio2022buildtools

# ---------------------------------------------------------------------
# 7. Configure Git + SSH
# ---------------------------------------------------------------------
Write-Host "Configuring Git + SSH..." -ForegroundColor Cyan
git config --global user.name "Wayne Eliot Blackmon"
git config --global user.email "wayne@example.com"

$sshPath = "$env:USERPROFILE\.ssh"
if (!(Test-Path $sshPath)) { New-Item -ItemType Directory -Path $sshPath }
ssh-keygen -t ed25519 -C "wayne@example.com" -f "$sshPath\id_ed25519" -N ""

# ---------------------------------------------------------------------
# 8. WSL package setup
# ---------------------------------------------------------------------
Write-Host "Installing WSL utilities..." -ForegroundColor Cyan
wsl -e bash -c "sudo apt update && sudo apt install -y build-essential curl unzip zip"

# ---------------------------------------------------------------------
# 9. Install IIS + Modules
# ---------------------------------------------------------------------
Write-Host "Installing IIS..." -ForegroundColor Cyan
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45 -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole -All -NoRestart

# ---------------------------------------------------------------------
# 10. URL Rewrite
# ---------------------------------------------------------------------
Write-Host "Installing URL Rewrite..." -ForegroundColor Cyan
$rewriteUrl = "https://download.microsoft.com/download/D/D/9/DD9B2E8C-0F3E-4D3C-8A2E-6C6F6B6B7C3E/rewrite_amd64.msi"
$rewriteInstaller = "$env:TEMP\urlrewrite.msi"
Invoke-WebRequest $rewriteUrl -OutFile $rewriteInstaller
Start-Process msiexec.exe -ArgumentList "/i `"$rewriteInstaller`" /quiet /norestart" -Wait

# ---------------------------------------------------------------------
# 11. .NET Hosting Bundle
# ---------------------------------------------------------------------
Write-Host "Installing .NET Hosting Bundle..." -ForegroundColor Cyan
$bundleUrl = "https://download.visualstudio.microsoft.com/download/pr/hosting-bundle-latest.exe"
$bundleInstaller = "$env:TEMP\hostingbundle.exe"
Invoke-WebRequest $bundleUrl -OutFile $bundleInstaller
Start-Process $bundleInstaller -ArgumentList "/quiet /norestart" -Wait

iisreset

# ---------------------------------------------------------------------
# 12. BitLocker
# ---------------------------------------------------------------------
Write-Host "Enabling BitLocker..." -ForegroundColor Cyan
Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -UsedSpaceOnly

# ---------------------------------------------------------------------
# 13. Done
# ---------------------------------------------------------------------
Write-Host "✅ CleanFeatures provisioning complete." -ForegroundColor Green
