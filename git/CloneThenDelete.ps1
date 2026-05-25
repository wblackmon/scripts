# ================================
# Clone → Verify → Delete Script
# ================================

$repos = @(
    "WordParser",
    "AmountToWords",
    "SharpEcho.CodeChallenge"
)

$localRoot = "C:\Users\wayne\source\repos\CodeChallenges"
$githubUser = "wblackmon"   # change if needed

Write-Host "=== Processing Code Challenge Repos ===" -ForegroundColor Cyan

# Ensure local folder exists
if (-not (Test-Path $localRoot)) {
    Write-Host "Creating local folder: $localRoot" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $localRoot | Out-Null
}

foreach ($repo in $repos) {

    $localPath = Join-Path $localRoot $repo
    $ghRepo = "$githubUser/$repo"

    Write-Host "`n--- $repo ---" -ForegroundColor Magenta

    # 1. Clone if missing
    if (-not (Test-Path $localPath)) {
        Write-Host "Cloning $ghRepo → $localPath" -ForegroundColor Green
        gh repo clone $ghRepo $localPath
    }
    else {
        Write-Host "Local clone already exists → $localPath" -ForegroundColor Yellow
    }

    # 2. Verify clone succeeded
    if (-not (Test-Path (Join-Path $localPath ".git"))) {
        Write-Host "ERROR: Clone failed or folder is not a git repo. Skipping delete." -ForegroundColor Red
        continue
    }

    Write-Host "Clone verified." -ForegroundColor Green

    # 3. Delete from GitHub
    Write-Host "Deleting GitHub repo: $ghRepo" -ForegroundColor Yellow
    gh repo delete $ghRepo --yes
}

Write-Host "`n=== Completed Successfully ===" -ForegroundColor Cyan
