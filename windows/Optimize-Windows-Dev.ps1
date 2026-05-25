<#  
    Windows 11 Debloat & Dev Optimization Script (Single File)
    Author: Wayne Eliot Blackmon
    Purpose: Reduce bloat, disable telemetry, remove ads, preserve Weather,
             harden Edge, optimize for development & research, and provide rollback.
#>

# ---------------------------
#  Helper: Require Admin
# ---------------------------
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Run PowerShell as Administrator."
    Break
}

# ---------------------------
#  Backup Registry Values
# ---------------------------
Function Backup-RegistryValues {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,

        [Parameter(Mandatory=$true)]
        [hashtable]$RegistryMap
    )

    $backup = @{}

    foreach ($path in $RegistryMap.Keys) {
        foreach ($name in $RegistryMap[$path]) {
            if (Test-Path $path) {
                try {
                    $value = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop |
                             Select-Object -ExpandProperty $name
                    $backup["$path|$name"] = $value
                } catch {
                    $backup["$path|$name"] = $null
                }
            } else {
                $backup["$path|$name"] = $null
            }
        }
    }

    $backup | ConvertTo-Json | Out-File $BackupPath -Encoding UTF8
}

# ---------------------------
#  Restore Registry Values
# ---------------------------
Function Restore-RegistryValues {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath
    )

    if (-not (Test-Path $BackupPath)) {
        Write-Host "No backup found." -ForegroundColor Red
        return
    }

    $backup = Get-Content $BackupPath | ConvertFrom-Json

    foreach ($key in $backup.PSObject.Properties.Name) {
        $parts = $key -split "\|"
        $path = $parts[0]
        $name = $parts[1]
        $value = $backup.$key

        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        if ($value -eq $null) {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        } else {
            Set-ItemProperty -Path $path -Name $name -Value $value -Force
        }
    }

    Write-Host "Registry values restored." -ForegroundColor Green
}

# ---------------------------
#  Disable Telemetry
# ---------------------------
Function Disable-Telemetry {
    Write-Host "Disabling telemetry…" -ForegroundColor Cyan

    $telemetryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    )

    foreach ($path in $telemetryPaths) {
        If (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -Force
    }

    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    )

    foreach ($task in $tasks) {
        schtasks /Change /TN $task /Disable 2>$null
    }

    Write-Host "Telemetry disabled." -ForegroundColor Green
}

# ---------------------------
#  Remove Bloatware (Weather preserved)
# ---------------------------
Function Remove-Bloatware {
    Write-Host "Removing unnecessary Windows apps…" -ForegroundColor Cyan

    $bloat = @(
        "Microsoft.BingNews",
        # "Microsoft.BingWeather",   # Weather preserved
        "Microsoft.GamingApp",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )

    foreach ($app in $bloat) {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $app} |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }

    Write-Host "Bloatware removed." -ForegroundColor Green
}

# ---------------------------
#  Disable Advertising
# ---------------------------
Function Disable-Advertising {
    Write-Host "Disabling Windows advertising…" -ForegroundColor Cyan

    $adSettings = @{
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" = @{
            "TailoredExperiencesWithDiagnosticDataEnabled" = 0
        }
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" = @{
            "SystemPaneSuggestionsEnabled" = 0
            "SubscribedContent-338393Enabled" = 0
            "SubscribedContent-353694Enabled" = 0
            "SubscribedContent-353696Enabled" = 0
            "SubscribedContent-310093Enabled" = 0
            "SoftLandingEnabled" = 0
            "RotatingLockScreenEnabled" = 0
            "RotatingLockScreenOverlayEnabled" = 0
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" = @{
            "DisableConsumerFeatures" = 1
        }
    }

    foreach ($path in $adSettings.Keys) {
        If (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        foreach ($name in $adSettings[$path].Keys) {
            Set-ItemProperty -Path $path -Name $name -Value $adSettings[$path][$name] -Force
        }
    }

    Write-Host "Advertising disabled." -ForegroundColor Green
}

# ---------------------------
#  Disable Data Sharing
# ---------------------------
Function Disable-DataSharing {
    Write-Host "Disabling data sharing toggles…" -ForegroundColor Cyan

    $paths = @{
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" = @{
            "LocationServicesEnabled" = 0
            "LetAppsAccessLocation" = 0
            "LetAppsAccessAdvertisingId" = 0
        }
    }

    foreach ($path in $paths.Keys) {
        If (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        foreach ($name in $paths[$path].Keys) {
            Set-ItemProperty -Path $path -Name $name -Value $paths[$path][$name] -Force
        }
    }

    Write-Host "Data sharing disabled." -ForegroundColor Green
}

# ---------------------------
#  Harden Microsoft Edge
# ---------------------------
Function Disable-EdgeBloat {
    Write-Host "Hardening Microsoft Edge…" -ForegroundColor Cyan

    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $edgePolicyPath)) {
        New-Item -Path $edgePolicyPath -Force | Out-Null
    }

    $edgeSettings = @{
        "MetricsReportingEnabled" = 0
        "PersonalizationReportingEnabled" = 0
        "UserFeedbackAllowed" = 0
        "BackgroundModeEnabled" = 0
        "StartupBoostEnabled" = 0
        "ShoppingEnabled" = 0
        "CouponsEnabled" = 0
        "PriceComparisonEnabled" = 0
        "EdgeShoppingAssistantEnabled" = 0
        "HubsSidebarEnabled" = 0
        "DiscoverEnabled" = 0
        "WebWidgetAllowed" = 0
        "AutofillAddressEnabled" = 0
        "AutofillCreditCardEnabled" = 0
        "AutofillPaymentInstrumentEnabled" = 0
        "SearchSuggestEnabled" = 0
        "PreloadNewTabPage" = 0
        "PreloadStartPage" = 0
        "FollowEnabled" = 0
        "PromotionalTabsEnabled" = 0
        "ShowRecommendationsEnabled" = 0
        "ShowMicrosoftRewards" = 0
    }

    foreach ($name in $edgeSettings.Keys) {
        Set-ItemProperty -Path $edgePolicyPath -Name $name -Value $edgeSettings[$name] -Force
    }

    Write-Host "Microsoft Edge hardened." -ForegroundColor Green
}

# ---------------------------
#  Optimize Edge for Dev & Research (with REG_MULTI_SZ fix)
# ---------------------------
Function Optimize-EdgeForDev {
    Write-Host "Optimizing Microsoft Edge for development and research…" -ForegroundColor Cyan

    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $edgePolicyPath)) {
        New-Item -Path $edgePolicyPath -Force | Out-Null
    }

    # Values that can be written normally
    $devSettings = @{
        "RestoreOnStartup"          = 4
        "DeveloperToolsAvailability" = 0   # DevTools enabled
        "AllowInspectElement"        = 1   # Inspect enabled
        "HideFirstRunExperience"     = 1
        "ShowRecommendationsEnabled" = 0
        "PromotionalTabsEnabled"     = 0
        "ShowMicrosoftRewards"       = 0
        "SearchSuggestEnabled"       = 0
        "StartupBoostEnabled"        = 0
        "BackgroundModeEnabled"      = 0
        "PreloadNewTabPage"          = 0
        "PreloadStartPage"           = 0
        "AlwaysOpenPdfExternally"    = 0
        "SmartScreenEnabled"         = 1
        "PasswordManagerEnabled"     = 0
        "AutofillAddressEnabled"     = 0
        "AutofillCreditCardEnabled"  = 0
    }

    foreach ($name in $devSettings.Keys) {
        Set-ItemProperty -Path $edgePolicyPath -Name $name -Value $devSettings[$name] -Force
    }

    # Handle RestoreOnStartupURLs as REG_MULTI_SZ
    New-ItemProperty -Path $edgePolicyPath `
        -Name "RestoreOnStartupURLs" `
        -Value @(
            "https://learn.microsoft.com",
            "https://github.com",
            "https://copilot.microsoft.com"
        ) `
        -PropertyType MultiString `
        -Force | Out-Null

    Write-Host "Edge optimized for development and research." -ForegroundColor Green
}

# ---------------------------
#  Rollback All Changes
# ---------------------------
Function Rollback-All {
    Write-Host "Rolling back all changes…" -ForegroundColor Yellow

    $backupFile = "C:\Windows11-Optimization-Backup\edge_and_privacy_backup.json"

    Restore-RegistryValues -BackupPath $backupFile

    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    )

    foreach ($task in $tasks) {
        schtasks /Change /TN $task /Enable 2>$null
    }

    Write-Host "Rollback complete." -ForegroundColor Green
}

# ---------------------------
#  Backup registry before changes
# ---------------------------
$backupDir = "C:\Windows11-Optimization-Backup"
if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory | Out-Null }

$backupFile = "$backupDir\edge_and_privacy_backup.json"

$registryMap = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" = @("AllowTelemetry")
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @("AllowTelemetry")
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" = @(
        "TailoredExperiencesWithDiagnosticDataEnabled",
        "LocationServicesEnabled",
        "LetAppsAccessLocation",
        "LetAppsAccessAdvertisingId"
    )
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" = @(
        "SystemPaneSuggestionsEnabled",
        "SubscribedContent-338393Enabled",
        "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled",
        "SubscribedContent-310093Enabled",
        "SoftLandingEnabled",
        "RotatingLockScreenEnabled",
        "RotatingLockScreenOverlayEnabled"
    )
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" = @("DisableConsumerFeatures")
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge" = @(
        "MetricsReportingEnabled",
        "PersonalizationReportingEnabled",
        "UserFeedbackAllowed",
        "BackgroundModeEnabled",
        "StartupBoostEnabled",
        "ShoppingEnabled",
        "CouponsEnabled",
        "PriceComparisonEnabled",
        "EdgeShoppingAssistantEnabled",
        "HubsSidebarEnabled",
        "DiscoverEnabled",
        "WebWidgetAllowed",
        "AutofillAddressEnabled",
        "AutofillCreditCardEnabled",
        "AutofillPaymentInstrumentEnabled",
        "SearchSuggestEnabled",
        "PreloadNewTabPage",
        "PreloadStartPage",
        "FollowEnabled",
        "PromotionalTabsEnabled",
        "ShowRecommendationsEnabled",
        "ShowMicrosoftRewards",
        "RestoreOnStartup",
        "DeveloperToolsAvailability",
        "AllowInspectElement",
        "AlwaysOpenPdfExternally",
        "SmartScreenEnabled",
        "PasswordManagerEnabled"
        # RestoreOnStartupURLs handled separately
    )
}

Backup-RegistryValues -BackupPath $backupFile -RegistryMap $registryMap

# ---------------------------
#  Main Menu
# ---------------------------
Write-Host "`n=== Windows 11 Optimization Menu ===" -ForegroundColor Yellow
Write-Host "1. Disable Telemetry"
Write-Host "2. Remove Bloatware (Weather preserved)"
Write-Host "3. Disable Advertising"
Write-Host "4. Disable Data Sharing"
Write-Host "5. Harden Microsoft Edge"
Write-Host "6. Optimize Edge for Development & Research"
Write-Host "7. Run ALL"
Write-Host "8. Rollback All Changes"
Write-Host "----------------------------------------------"

$choice = Read-Host "Select an option"

switch ($choice) {
    "1" { Disable-Telemetry }
    "2" { Remove-Bloatware }
    "3" { Disable-Advertising }
    "4" { Disable-DataSharing }
    "5" { Disable-EdgeBloat }
    "6" { Optimize-EdgeForDev }
    "7" {
        Disable-Telemetry
        Remove-Bloatware
        Disable-Advertising
        Disable-DataSharing
        Disable-EdgeBloat
        Optimize-EdgeForDev
    }
    "8" { Rollback-All }
    default { Write-Host "Invalid selection." -ForegroundColor Red }
}

Write-Host "`nCompleted." -ForegroundColor Green
