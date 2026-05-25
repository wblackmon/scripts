$path = "$env:USERPROFILE\vscode-extensions.txt"

Write-Host "Collecting VS Code extensions..."
$extensions = code --list-extensions --show-versions | Sort-Object

Write-Host "Writing to $path"
$extensions | Out-File $path

Write-Host "Opening file in Notepad..."
notepad $path
