# ================================
# Full Docker Desktop Uninstall Script (Windows)
# Idempotent, silent, deterministic
# ================================

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

Write-Host "Removing Docker Desktop from Program Files..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "C:\Program Files\Docker" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\Program Files\Docker Desktop" -ErrorAction SilentlyContinue

Write-Host "Cleaning up shortcuts..." -ForegroundColor Cyan
Remove-Item -Force "$Env:Public\Desktop\Docker Desktop.lnk" -ErrorAction SilentlyContinue

Write-Host "Docker Desktop fully removed." -ForegroundColor Green
Write-Host "You may now reinstall Docker Desktop cleanly." -ForegroundColor Green
