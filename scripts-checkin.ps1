#!/usr/bin/env pwsh
# Deterministic PowerShell check-in script

param(
    [string]$Message = "update"
)

# -----------------------------
# 1. Ensure repo exists
# -----------------------------
if (-not (Test-Path ".git")) {
    Write-Host "Initializing git repo..."
    git init
}

# -----------------------------
# 2. Ensure initial commit exists
# -----------------------------
$hasCommit = git rev-parse --quiet --verify HEAD 2>$null
if (-not $hasCommit) {
    Write-Host "Creating initial commit..."
    git add .
    git commit -m "Initial commit"
}

# -----------------------------
# 3. Ensure remote exists
# -----------------------------
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Write-Host "❌ No remote found."
    Write-Host "Add one with:"
    Write-Host "  git remote add origin https://github.com/<user>/<repo>.git"
    exit 1
}

# -----------------------------
# 4. Determine current branch
# -----------------------------
$branch = git rev-parse --abbrev-ref HEAD

if (-not $branch -or $branch -eq "HEAD") {
    Write-Host "No branch detected. Creating 'main'..."
    git checkout -b main
    $branch = "main"
}

# -----------------------------
# 5. Check if upstream exists (quote @{u})
# -----------------------------
$hasUpstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null

if (-not $hasUpstream) {
    Write-Host "No upstream branch. First push required."
    git push -u origin $branch
    Write-Host "✔ Upstream created."
}

# -----------------------------
# 6. Fetch + rebase (only if upstream exists)
# -----------------------------
Write-Host "Fetching latest..."
git fetch origin $branch

Write-Host "Rebasing..."
git rebase origin/$branch
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Rebase failed. Resolve conflicts and re-run."
    exit 1
}

# -----------------------------
# 7. Commit changes
# -----------------------------
git add -A
if (git diff --cached --quiet) {
    Write-Host "No changes to commit."
} else {
    Write-Host "Committing..."
    git commit -m $Message
}

# -----------------------------
# 8. Push
# -----------------------------
Write-Host "Pushing to origin/$branch..."
git push origin $branch

Write-Host "✔ Check-in complete."
