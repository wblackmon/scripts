#!/bin/bash
set -e

# chmod +x azcopy_blob_containers.sh

# Ensure script is executable (self-healing)
if [ ! -x "$0" ]; then
    echo "Fixing script permissions..."
    chmod +x "$0"
fi

ACCOUNT="az204storageacct01"
SRC_CONTAINER="container1"
DEST_CONTAINER="container2"
BLOB_NAME="ResourceGroupDelete-All.ps1"
EXPIRY="2026-12-31T23:59Z"

echo "Generating SAS token for source blob..."
SOURCE_SAS=$(az storage blob generate-sas \
  --account-name "$ACCOUNT" \
  --container-name "$SRC_CONTAINER" \
  --name "$BLOB_NAME" \
  --permissions r \
  --expiry "$EXPIRY" \
  --https-only \
  --output tsv)

echo "Generating SAS token for destination container..."
DEST_SAS=$(az storage container generate-sas \
  --account-name "$ACCOUNT" \
  --name "$DEST_CONTAINER" \
  --permissions w \
  --expiry "$EXPIRY" \
  --https-only \
  --output tsv)

SRC_URL="https://${ACCOUNT}.blob.core.windows.net/${SRC_CONTAINER}/${BLOB_NAME}?${SOURCE_SAS}"
DEST_URL="https://${ACCOUNT}.blob.core.windows.net/${DEST_CONTAINER}/${BLOB_NAME}?${DEST_SAS}"

echo "Copying blob with AzCopy..."
azcopy copy "$SRC_URL" "$DEST_URL"

echo "Done."