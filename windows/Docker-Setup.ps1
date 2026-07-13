# ============================================
# Full Docker Desktop Reset + Reinstall Script
# Windows PowerShell (Run as Administrator)
# Idempotent, deterministic, no ambiguity
# ============================================

Write-Host "Stopping Docker services..." -ForegroundColor Cyan
Stop-Service com.docker.service -ErrorAction SilentlyContinue

Write-Host "Killing Docker Desktop processes..." -ForegroundColor Cyan
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process "Docker" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Unregistering WSL distros..." -ForegroundColor Cyan
wsl --unregister docker-desktop 2>$null
wsl --unregister docker-desktop-data 2>$null

Write-Host "Removing Docker ProgramData..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "C:\ProgramData\Docker" -ErrorAction SilentlyContinue

Write-Host "Removing Docker AppData..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$Env:AppData\Docker" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$Env:LocalAppData\Docker" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$Env:LocalAppData\Docker Desktop" -ErrorAction SilentlyContinue

Write-Host "Removing Docker CLI contexts..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$Env:UserProfile\.docker" -ErrorAction SilentlyContinue

Write-Host "Removing Docker from Program Files..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "C:\Program Files\Docker" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\Program Files\Docker Desktop" -ErrorAction SilentlyContinue

Write-Host "Cleaning up shortcuts..." -ForegroundColor Cyan
Remove-Item -Force "$Env:Public\Desktop\Docker Desktop.lnk" -ErrorAction SilentlyContinue

Write-Host "Removing stale winget registrations..." -ForegroundColor Cyan
winget uninstall --id Docker.DockerDesktop --source winget --force 2>$null
winget uninstall "Docker Desktop" --force 2>$null

Write-Host "Checking for MSI-based Docker entries..." -ForegroundColor Cyan
$dockerMsi = Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*Docker*" }
if ($dockerMsi) {
    Write-Host "Removing MSI entry..." -ForegroundColor Yellow
    $dockerMsi.Uninstall() | Out-Null
}

Write-Host "Resetting winget package cache..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_*" -ErrorAction SilentlyContinue

Write-Host "Docker Desktop fully removed." -ForegroundColor Green
Write-Host "Reinstalling Docker Desktop via winget..." -ForegroundColor Cyan

winget install --id Docker.DockerDesktop --source winget --force

Write-Host "Docker Desktop reinstall complete." -ForegroundColor Green
Write-Host "Open Docker Desktop and enable WSL integration for your Ubuntu distro." -ForegroundColor Green
