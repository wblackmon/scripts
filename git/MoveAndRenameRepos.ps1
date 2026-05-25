# ================================
# Consolidate AZ-204 repos into azure/az204
# Using gh where possible, git only where required
# ================================

$base = "C:\Users\wayne\source\repos\wblackmon"
$azureRepo = "$base\azure"

# Ensure azure repo exists
if (-not (Test-Path $azureRepo)) {
    gh repo clone wblackmon/azure $azureRepo
}

Set-Location $azureRepo

# Create target folder
if (-not (Test-Path ".\az204")) {
    New-Item -ItemType Directory -Path ".\az204" | Out-Null
}

# Repo map: source → target folder name
$repos = @{
    "az204cosmosdb"      = "cosmosdb"
    "az204redis"         = "redis"
    "az204queuestorage"  = "queuestorage"
    "az204svcbus"        = "svcbus"
}

foreach ($repo in $repos.Keys) {

    $target = $repos[$repo]
    $clonePath = "$base\$repo"

    Write-Host "`n=== Processing $repo → $target ==="

    # Clone source repo using gh
    if (-not (Test-Path $clonePath)) {
        gh repo clone "wblackmon/$repo" $clonePath
    }

    # Add subtree (preserves history)
    git remote add $target $clonePath
    git subtree add --prefix="az204/$target" $target main --squash

    # Remove remote reference
    git remote remove $target
}

# Push updated azure repo
git add .
git commit -m "Imported AZ-204 repos into azure/az204"
git push

# Delete old repos from GitHub
foreach ($repo in $repos.Keys) {
    gh repo delete "wblackmon/$repo" --yes
}

Write-Host "`nAll AZ-204 repos consolidated and deleted successfully."
