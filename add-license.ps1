#!/usr/bin/env pwsh
# Create LICENSE file if it doesn't exist

$licensePath = "LICENSE"
$year = (Get-Date).Year
$author = "Wayne Blackmon"

if (Test-Path $licensePath) {
    Write-Host "LICENSE already exists."
    exit 0
}

@"
MIT License

Copyright (c) $year $author

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[MIT license text continues…]
"@ | Out-File -FilePath $licensePath -Encoding utf8

Write-Host "✔ LICENSE created."
