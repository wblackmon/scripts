# Define your tenant ID
$TenantId = "73664036-e141-4caa-ad0e-5f4a014c7ee8"

Write-Host "Initiating Azure login for tenant $($TenantId) with MFA support..."
az login --tenant $TenantId --use-device-code | Out-Null

Write-Host ""
Write-Host "Subscriptions in tenant $($TenantId):"
$subscriptions = az account list --output json | ConvertFrom-Json

foreach ($sub in $subscriptions) {
    Write-Host "----------------------------------------"
    Write-Host "Name:           $($sub.name)"
    Write-Host "SubscriptionId: $($sub.id)"
    Write-Host "TenantId:       $($sub.tenantId)"
    Write-Host "State:          $($sub.state)"
    Write-Host "IsDefault:      $($sub.isDefault)"
}
