param()

# ---------------------------------------------
# CONFIG
# ---------------------------------------------
$AzureDir = "C:\Users\wayne\source\repos\azure"
$TargetDir = Join-Path $AzureDir "az204"

$Repos = @(
    "az204svcbus"
    "az204cosmosdb"
    "az204queuestorage"
    "az204redis"
    "az204servicebus"
)

# ---------------------------------------------
# Function: delete GitHub repo
# ---------------------------------------------
function Remove-GitHubRepo {
    param([string]$RepoName)

    Write-Host "Deleting GitHub repo: wblackmon/$RepoName"
    gh repo delete "wblackmon/$RepoName" --yes
}

# ---------------------------------------------
# Ensure target folder exists
# ---------------------------------------------
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

# ---------------------------------------------
# Main loop
# ---------------------------------------------
foreach ($repo in $Repos) {
    # Remove the az204 prefix
    $newname = $repo -replace "^az204", ""

    Write-Host "---------------------------------------------"
    Write-Host "Processing $repo → $newname"
    Write-Host "---------------------------------------------"

    $Destination = Join-Path $TargetDir $newname

    gh repo clone "wblackmon/$repo" $Destination

    Write-Host "Cloned into: $Destination"
}

Write-Host ""
Write-Host "All repos cloned into $TargetDir"
Write-Host "Use Remove-GitHubRepo <name> to delete originals."
