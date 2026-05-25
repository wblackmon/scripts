# Ensure we're in the correct folder
$repoName = "scripts"

# 1. Initialize git repo if missing
if (-not (Test-Path ".git")) {
    git init
}

# 2. Create initial commit if none exists
$hasCommit = git rev-parse --quiet --verify HEAD 2>$null
if (-not $hasCommit) {
    git add .
    git commit -m "Initial commit"
}

# 3. Add remote if missing
$remoteExists = git remote get-url origin 2>$null
if (-not $remoteExists) {
    git remote add origin "https://github.com/$env:GITHUB_USER/$repoName.git"
}

# 4. Create GitHub repo and push
gh repo create $repoName --source=. --remote=origin --private --push
