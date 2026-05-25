$root = "C:\Users\wayne\source\repos\azure\az204"

Get-ChildItem -Path $root -Directory | ForEach-Object {
    $oldName = $_.Name

    # Only rename folders that START with "az204"
    if ($oldName -like "az204*") {

        # Remove the prefix
        $newName = $oldName -replace "^az204", ""

        # Trim leading dashes, underscores, or spaces if present
        $newName = $newName.TrimStart("-", "_", " ")

        # Build full paths
        $oldPath = $_.FullName
        $newPath = Join-Path $root $newName

        # Avoid collisions
        if (-not (Test-Path $newPath)) {
            Write-Host "Renaming '$oldName' → '$newName'" -ForegroundColor Green
            Rename-Item -Path $oldPath -NewName $newName
        }
        else {
            Write-Host "Skipping '$oldName' — target '$newName' already exists" -ForegroundColor Yellow
        }
    }
}
