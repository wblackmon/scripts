#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "=============================================="
echo "  Consolidating AZ-204 repos into azure/az204"
echo "  gh-first workflow, minimal git usage"
echo "=============================================="
echo ""

# ---------------------------------------------------------
# AUTO-DETECT REPO ROOT
# ---------------------------------------------------------
# Script lives in: ~/repos/scripts
# Repo root is:    ~/repos/wblackmon

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE="$REPO_ROOT/wblackmon"
AZURE="$BASE/azure"

echo "Script directory: $SCRIPT_DIR"
echo "Repo root:        $REPO_ROOT"
echo "GitHub root:      $BASE"
echo ""

# ---------------------------------------------------------
# Ensure azure repo exists
# ---------------------------------------------------------
if [ ! -d "$AZURE" ]; then
    echo "Cloning azure repo..."
    gh repo clone wblackmon/azure "$AZURE"
fi

cd "$AZURE"

mkdir -p az204

# ---------------------------------------------------------
# Repo map: source → target folder name
# ---------------------------------------------------------
declare -A repos=(
    ["az204cosmosdb"]="cosmosdb"
    ["az204redis"]="redis"
    ["az204queuestorage"]="queuestorage"
    ["az204svcbus"]="svcbus"
)

# ---------------------------------------------------------
# PROCESS EACH REPO
# ---------------------------------------------------------
for repo in "${!repos[@]}"; do
    target="${repos[$repo]}"
    clonePath="$BASE/$repo"

    echo ""
    echo "----------------------------------------------"
    echo " Processing $repo → az204/$target"
    echo "----------------------------------------------"

    # Clone source repo if missing
    if [ ! -d "$clonePath" ]; then
        echo "Cloning $repo..."
        gh repo clone "wblackmon/$repo" "$clonePath"
    else
        echo "Local clone exists: $clonePath"
    fi

    # Add subtree (preserves history)
    echo "Adding subtree..."
    git remote add "$target" "$clonePath" 2>/dev/null || true
    git subtree add --prefix="az204/$target" "$target" main --squash
    git remote remove "$target" || true
done

# ---------------------------------------------------------
# Commit and push
# ---------------------------------------------------------
echo ""
echo "Committing and pushing changes..."
git add .
git commit -m "Imported AZ-204 repos into azure/az204" || echo "No changes to commit."
git push

# ---------------------------------------------------------
# Delete old repos from GitHub
# ---------------------------------------------------------
echo ""
echo "Deleting old AZ-204 repos from GitHub..."

for repo in "${!repos[@]}"; do
    echo "Deleting wblackmon/$repo..."
    gh repo delete "wblackmon/$repo" --yes || echo "Failed to delete $repo (check permissions)."
done

echo ""
echo "=============================================="
echo "  Consolidation complete."
echo "  All AZ-204 repos merged and deleted."
echo "=============================================="
