param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

Write-Host "Normalizing attributes..." -ForegroundColor Cyan
attrib -s -h -r $Path /S /D 2>$null

Write-Host "Taking ownership recursively..." -ForegroundColor Cyan
takeown /F $Path /R /D Y | Out-Null

Write-Host "Granting full control to current user recursively..." -ForegroundColor Cyan
$me = "$env:USERNAME"
icacls $Path /grant "${me}:(OI)(CI)F" /T | Out-Null

Write-Host "Done. You now have full control of:`n$Path" -ForegroundColor Green
