#!/usr/bin/env bash
set -euo pipefail

repo_name="scripts"

# 1. Initialize git repo if missing
if [ ! -d .git ]; then
    git init
fi

# 2. Create initial commit if none exists
if ! git rev-parse --quiet --verify HEAD >/dev/null 2>&1; then
    git add .
    git commit -m "Initial commit"
fi

# 3. Add remote if missing
if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/${GITHUB_USER}/${repo_name}.git"
fi

# 4. Create GitHub repo and push
gh repo create "$repo_name" --source=. --remote=origin --private --push
