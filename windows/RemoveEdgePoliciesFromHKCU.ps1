# Remove Edge policies from HKCU
$pathCU = "HKCU:\Software\Policies\Microsoft\Edge"
if (Test-Path $pathCU) {
    Remove-Item $pathCU -Recurse -Force
}

# Remove Edge policies from HKLM
$pathLM = "HKLM:\Software\Policies\Microsoft\Edge"
if (Test-Path $pathLM) {
    Remove-Item $pathLM -Recurse -Force
}

Write-Host "All Edge policies removed. Restart Edge."
