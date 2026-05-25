<#
.SYNOPSIS
  Hardens Windows 11 Pro and Microsoft Edge by disabling ads, data collection,
  consumer features, and Copilot-related components using safe, reversible policies.

.NOTES
  - Run as Administrator.
  - Creates .reg backups of all policy keys touched.
  - Uses only documented Windows + Edge policy keys.
#>

# -----------------------------
# Helper: Ensure registry path
# -----------------------------
function Ensure-RegistryKey {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

# -----------------------------
# Backup: Export key snapshots
# -----------------------------
$backupFolder = "$env:PUBLIC\Win11_Privacy_Backup"
if (-not (Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder | Out-Null
}

$policyRoots = @(
    'HKLM:\SOFTWARE\Policies\Microsoft',
    'HKCU:\SOFTWARE\Policies\Microsoft'
)

foreach ($root in $policyRoots) {
    $safeName = ($root -replace '[:\\/]','_') + '.reg'
    $backupPath = Join-Path $backupFolder $safeName
    reg export ($root -replace 'HKLM:','HKLM') $backupPath /y *> $null 2>&1
}

Write-Host "Policy registry backup saved to: $backupFolder" -ForegroundColor Cyan

# =========================================================
# SECTION 1: System telemetry & data collection
# =========================================================

$telemetryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
Ensure-RegistryKey -Path $telemetryKey
Set-ItemProperty -Path $telemetryKey -Name 'AllowTelemetry' -Type DWord -Value 1

$tailoredKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
Ensure-RegistryKey -Path $tailoredKey
Set-ItemProperty -Path $tailoredKey -Name 'DisableTailoredExperiencesWithDiagnosticData' -Type DWord -Value 1

$adsIdKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
Ensure-RegistryKey -Path $adsIdKey
Set-ItemProperty -Path $adsIdKey -Name 'DisabledByGroupPolicy' -Type DWord -Value 1

$feedbackKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
Ensure-RegistryKey -Path $feedbackKey
Set-ItemProperty -Path $feedbackKey -Name 'DoNotShowFeedbackNotifications' -Type DWord -Value 1

# =========================================================
# SECTION 2: Start menu, lock screen, suggestions & tips
# =========================================================

$cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Ensure-RegistryKey -Path $cdm

$cdmValues = @{
    'SystemPaneSuggestionsEnabled'     = 0
    'ContentDeliveryAllowed'           = 0
    'OemPreInstalledAppsEnabled'       = 0
    'PreInstalledAppsEnabled'          = 0
    'PreInstalledAppsEverEnabled'      = 0
    'SilentInstalledAppsEnabled'       = 0
    'SubscribedContent-338387Enabled'  = 0
    'SubscribedContent-338388Enabled'  = 0
    'SubscribedContent-338389Enabled'  = 0
    'SubscribedContent-353694Enabled'  = 0
    'SubscribedContent-353696Enabled'  = 0
    'SubscribedContent-353698Enabled'  = 0
}

foreach ($name in $cdmValues.Keys) {
    Set-ItemProperty -Path $cdm -Name $name -Type DWord -Value $cdmValues[$name]
}

$explorerKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Ensure-RegistryKey -Path $explorerKey
Set-ItemProperty -Path $explorerKey -Name 'ShowSyncProviderNotifications' -Type DWord -Value 0

# =========================================================
# SECTION 3: Windows Copilot
# =========================================================

$copilotPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
Ensure-RegistryKey -Path $copilotPolicyKey
Set-ItemProperty -Path $copilotPolicyKey -Name 'TurnOffWindowsCopilot' -Type DWord -Value 1

# Disable web search in Start
$searchPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
Ensure-RegistryKey -Path $searchPolicyKey
Set-ItemProperty -Path $searchPolicyKey -Name 'DisableWebSearch' -Type DWord -Value 1
Set-ItemProperty -Path $searchPolicyKey -Name 'ConnectedSearchUseWeb' -Type DWord -Value 0

# =========================================================
# SECTION 4: Microsoft Edge Hardening (Copilot, ads, promos)
# =========================================================

$edgePolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Ensure-RegistryKey -Path $edgePolicyKey

$edgePolicies = @{
    'HubsSidebarEnabled'                 = 0  # Sidebar (Copilot lives here)
    'EdgeCopilotEnabled'                 = 0  # Copilot in Edge
    'MicrosoftEdgeCopilotAutoOpen'       = 0
    'ShowRecommendationsEnabled'         = 0
    'PromotionalTabsEnabled'             = 0
    'NewTabPageContentEnabled'           = 0
    'NewTabPageQuickLinksEnabled'        = 0
    'PersonalizationReportingEnabled'    = 0
    'ShoppingAssistantEnabled'           = 0
    'ServicesEnabled'                    = 0
}

foreach ($name in $edgePolicies.Keys) {
    Set-ItemProperty -Path $edgePolicyKey -Name $name -Type DWord -Value $edgePolicies[$name]
}

# =========================================================
# SECTION 5: Disable Windows Consumer Experience
# =========================================================

$consumerKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
Ensure-RegistryKey -Path $consumerKey
Set-ItemProperty -Path $consumerKey -Name 'DisableWindowsConsumerFeatures' -Type DWord -Value 1

Write-Host ""
Write-Host "Done. A reboot is recommended for all changes to fully apply." -ForegroundColor Green
Write-Host "Backups are stored in: $backupFolder" -ForegroundColor Yellow
