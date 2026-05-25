#!/usr/bin/env pwsh
# Create README.md if it doesn't exist

$readmePath = "README.md"

if (Test-Path $readmePath) {
    Write-Host "README.md already exists."
    exit 0
}

$repoName = Split-Path -Leaf (Get-Location)

@"
# $repoName

A collection of scripts and utilities.

## Usage

Describe how to use the scripts in this repository.

## License

This project is licensed under the MIT License.
"@ | Out-File -FilePath $readmePath -Encoding utf8

Write-Host "✔ README.md created."
