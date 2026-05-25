#!/bin/bash
TENANT_ID="73664036-e141-4caa-ad0e-5f4a014c7ee8"

echo "🔐 Authenticating with MFA support..."
az login --tenant "$TENANT_ID" --use-device-code

echo "📦 Listing subscriptions for tenant $TENANT_ID..."
az account list --output table
