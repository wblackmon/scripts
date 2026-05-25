#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# CONFIG
# ---------------------------------------------
AZURE_DIR="/mnt/c/Users/wayne/source/repos/azure"
TARGET_DIR="$AZURE_DIR/az204"

# Repos to process
REPOS=(
  "az204svcbus"
  "az204cosmosdb"
  "az204queuestorage"
  "az204redis"
  "az204servicebus"
)

# ---------------------------------------------
# Function: delete GitHub repo
# ---------------------------------------------
delete_repo() {
    local repo="$1"
    echo "Deleting GitHub repo: wblackmon/$repo"
    gh repo delete "wblackmon/$repo" --yes
}

# ---------------------------------------------
# Ensure target folder exists
# ---------------------------------------------
mkdir -p "$TARGET_DIR"

# ---------------------------------------------
# Main loop
# ---------------------------------------------
for repo in "${REPOS[@]}"; do
    newname="${repo#az204}"   # remove prefix

    echo "---------------------------------------------"
    echo "Processing $repo → $newname"
    echo "---------------------------------------------"

    gh repo clone "wblackmon/$repo" "$TARGET_DIR/$newname"

    echo "Cloned into: $TARGET_DIR/$newname"
done

echo ""
echo "All repos cloned into $TARGET_DIR"
echo "Use delete_repo <name> to delete originals."
