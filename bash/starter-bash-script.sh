#!/bin/bash

# Exit on error
set -e

# Variables
LOCATION="eastus"
RG_NAME="MyResourceGroup"

echo "=== Azure CLI Starter Script ==="

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI not found. Please install it first: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
echo "Logging in to Az
ure..."
az login --output none

# Show current subscription
echo "Current subscription:"
az account show --query "{Name:name, Id:id}" -o table

# Create a resource group
echo "Creating resource group: $RG_NAME in $LOCATION..."
az group create --name "$RG_NAME" --location "$LOCATION" --output table

# List all resource groups
echo "Listing all resource groups..."
az group list --query "[].{Name:name, Location:location}" -o table

# Delete the resource group (optional)
read -r -p "Do you want to delete $RG_NAME? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
    echo "Deleting resource group: $RG_NAME..."
    az group delete --name "$RG_NAME" --yes --no-wait
    echo "Delete request submitted."
else
    echo "Skipping deletion."
fi

echo "=== Script Completed ==="
