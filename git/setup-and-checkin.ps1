param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

Write-Host "=== AZ-204 Repo Setup + GitHub Repo Creation + Check-In ===" -ForegroundColor Cyan

$RepoPath = "C:\Users\wayne\source\repos\azure\az204"
$RepoName = "azure"
$GitHubUser = "wblackmon"
$RemoteUrl = "https://github.com/$GitHubUser/$RepoName.git"
$Token = $env:GITHUB_TOKEN

if (-not $Token) {
    Write-Host "ERROR: GITHUB_TOKEN environment variable not set." -ForegroundColor Red
    exit 1
}

# Ensure repo folder exists
if (-not (Test-Path $RepoPath)) {
    Write-Host "ERROR: Repo path not found: $RepoPath" -ForegroundColor Red
    exit 1
}

Set-Location $RepoPath
Write-Host "Repo: $RepoPath"

# --- 1. Create GitHub repo if missing ---
Write-Host "Checking if GitHub repo exists..."

$repoCheck = Invoke-RestMethod `
    -Headers @{ Authorization = "token $Token" } `
    -Uri "https://api.github.com/repos/$GitHubUser/$RepoName" `
    -Method GET `
    -ErrorAction SilentlyContinue

if (-not $repoCheck) {
    Write-Host "GitHub repo does not exist. Creating it now..." -ForegroundColor Yellow

    $body = @{
        name = $RepoName
        private = $false
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Headers @{ Authorization = "token $Token" } `
        -Uri "https://api.github.com/user/repos" `
        -Method POST `
        -Body $body

    Write-Host "GitHub repo created: $RemoteUrl" -ForegroundColor Green
}
else {
    Write-Host "GitHub repo already exists." -ForegroundColor Green
}

# --- 2. Sanitize secrets ---
Write-Host "Sanitizing secrets..."

$patterns = @(
    "AccountKey=",
    "PrimaryKey=",
    "SharedAccessKey=",
    "DefaultEndpointsProtocol=",
    "EventGrid",
    "Cosmos"
)

Get-ChildItem -Recurse -File | ForEach-Object {
    $content = Get-Content $_.FullName
    $modified = $false

    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $content = $content -replace $pattern, "<REDACTED>"
            $modified = $true
        }
    }

    if ($modified) {
        Write-Host "  Redacted secrets in: $($_.FullName)"
        Set-Content -Path $_.FullName -Value $content
    }
}

# --- 3. Initialize repo if needed ---
if (-not (Test-Path ".git")) {
    Write-Host "Initializing new Git repo..."
    git init
    git branch -M main
}

# --- 4. Add remote if missing ---
$remotes = git remote
if ($remotes -notcontains "origin") {
    Write-Host "Adding remote origin..."
    git remote add origin $RemoteUrl
}

# --- 5. Stage everything ---
Write-Host "Staging changes..."
git add .

# --- 6. Commit ---
Write-Host "Committing..."
git commit -m "$Message" --allow-empty

# --- 7. Push cleanly ---
Write-Host "Pushing to GitHub..."
git push -u origin main --force

Write-Host "=== Setup + Repo Creation + Check-In Complete ===" -ForegroundColor Green
