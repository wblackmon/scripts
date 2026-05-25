<# 
    Alienware Command Center 5.x – Full Removal Script
    -------------------------------------------------
    Operations:
      1. Verify elevation
      2. Uninstall MSI-based components
      3. Uninstall MSIX/Store packages
      4. Stop and remove related services
      5. Remove AlienFX / AWCC-related drivers
      6. (Optional) Reset WindowsApps permissions
      7. Delete all related folders

    Safe to re-run (idempotent); logs each action with result.
#>

# -------------------------------
# Config
# -------------------------------

# Set this to $false if you do NOT want WindowsApps permissions touched
$ResetWindowsAppsPermissions = $true

# -------------------------------
# Helper: Logging
# -------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# -------------------------------
# Helper: Elevation Check
# -------------------------------

function Assert-Elevation {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "This script must be run as Administrator. Exiting." "ERROR"
        exit 1
    }

    Write-Log "Elevation confirmed (running as Administrator)." "INFO"
}

# -------------------------------
# Step 1: Uninstall MSI + Store Packages
# -------------------------------

function Remove-AWCCPackages {
    Write-Log "=== Step 1: Uninstalling Alienware Command Center components (MSI + Store) ===" "INFO"

    # MSI-based packages
    $msiNames = @(
        "Alienware Command Center",
        "Alienware OC Controls",
        "Alienware Sound Center",
        "Alienware AlienFX",
        "Dell SupportAssist",
        "Dell SupportAssist OS Recovery Plugin for Dell Update"
    )

    foreach ($name in $msiNames) {
        $pkg = Get-WmiObject Win32_Product -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like "*$name*" }

        if ($pkg) {
            foreach ($p in $pkg) {
                Write-Log "Uninstalling MSI package: $($p.Name)" "INFO"
                try {
                    $result = $p.Uninstall()
                    Write-Log "Uninstall result code: $result" "INFO"
                }
                catch {
                    Write-Log "Failed to uninstall MSI package '$($p.Name)': $($_.Exception.Message)" "WARN"
                }
            }
        }
        else {
            Write-Log "MSI package not found (skipping): $name" "INFO"
        }
    }

    # MSIX / Store packages
    Write-Log "Removing MSIX/Store packages matching Alienware/AWCC patterns." "INFO"

    $patterns = @(
        "Alienware",
        "AWCC",
        "AlienFX",
        "DellInc.Alienware",
        "DellInc.AlienwareCommandCenter",
        "DellInc.AlienwareOCControls"
    )

    foreach ($pattern in $patterns) {
        $pkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern }
        if ($pkgs) {
            foreach ($p in $pkgs) {
                Write-Log "Removing Store package: $($p.Name)" "INFO"
                try {
                    Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Log "Successfully removed Store package: $($p.Name)" "INFO"
                }
                catch {
                    Write-Log "Failed to remove Store package '$($p.Name)': $($_.Exception.Message)" "WARN"
                }
            }
        }
        else
        {
            Write-Log "No Store packages found for pattern: $pattern" "INFO"
        }
    }
}

# -------------------------------
# Step 2: Stop & Remove Services + Drivers
# -------------------------------

function Remove-AWCCServicesAndDrivers {
    Write-Log "=== Step 2: Stopping and removing Alienware/ AWCC services ===" "INFO"

    $services = @(
        "AWCCService",
        "AWCC.Service",
        "Alienware Command Center",
        "AlienFX Device Service",
        "OCControls",
        "AWCC.Background"
    )

    foreach ($svc in $services) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Write-Log "Stopping service: $svc" "INFO"
            try {
                Stop-Service -Name $svc -Force -ErrorAction Stop
                Write-Log "Service stopped: $svc" "INFO"
            }
            catch {
                Write-Log "Failed to stop service '$svc': $($_.Exception.Message)" "WARN"
            }

            Write-Log "Deleting service: $svc" "INFO"
            try {
                sc.exe delete $svc | Out-Null
                Write-Log "Service deleted: $svc" "INFO"
            }
            catch {
                Write-Log "Failed to delete service '$svc': $($_.Exception.Message)" "WARN"
            }
        }
        else {
            Write-Log "Service not found (skipping): $svc" "INFO"
        }
    }

    Write-Log "=== Step 2b: Removing AlienFX / AWCC-related drivers ===" "INFO"

    $driverPatterns = @("AlienFX", "AWCC", "OCControls")

    foreach ($pattern in $driverPatterns) {
        Write-Log "Scanning drivers for pattern: $pattern" "INFO"
        pnputil /enum-drivers | Select-String $pattern | ForEach-Object {
            if ($_ -match "Published Name : (oem\d+\.inf)") {
                $inf = $matches[1]
                Write-Log "Removing driver: $inf (pattern: $pattern)" "INFO"
                try {
                    pnputil /delete-driver $inf /uninstall /force | Out-Null
                    Write-Log "Driver removed: $inf" "INFO"
                }
                catch {
                    Write-Log "Failed to remove driver '$inf': $($_.Exception.Message)" "WARN"
                }
            }
        }
    }
}

# -------------------------------
# Step 3: Reset WindowsApps Permissions (Optional)
# -------------------------------

function Reset-WindowsAppsPermissions {
    if (-not $ResetWindowsAppsPermissions) {
        Write-Log "WindowsApps permission reset is disabled by configuration. Skipping." "INFO"
        return
    }

    Write-Log "=== Step 3: Resetting WindowsApps permissions (optional) ===" "INFO"

    $wa = "C:\Program Files\WindowsApps"

    if (Test-Path $wa) {
        try {
            Write-Log "Taking ownership of WindowsApps..." "INFO"
            takeown /f "$wa" /r /d y | Out-Null

            Write-Log "Granting Administrators full control on WindowsApps..." "INFO"
            icacls "$wa" /grant administrators:F /t | Out-Null

            Write-Log "WindowsApps permissions reset complete." "INFO"
        }
        catch {
            Write-Log "Failed to reset WindowsApps permissions: $($_.Exception.Message)" "WARN"
        }
    }
    else {
        Write-Log "WindowsApps folder not found. Skipping permission reset." "INFO"
    }
}

# -------------------------------
# Step 4: Delete AWCC-related Folders
# -------------------------------

function Remove-AWCCFolders {
    Write-Log "=== Step 4: Deleting Alienware Command Center folders ===" "INFO"

    $paths = @(
        "C:\Program Files\Alienware\Command Center",
        "C:\Program Files (x86)\Alienware\Command Center",
        "$env:APPDATA\Alienware",
        "$env:LOCALAPPDATA\Alienware",
        "$env:PROGRAMDATA\Alienware",
        "$env:USERPROFILE\Documents\AlienFX",
        "$env:USERPROFILE\Documents\Alienware TactX"
    )

    # WindowsApps entries (Store-based AWCC components)
    $windowsApps = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $windowsApps) {
        try {
            $waDirs = Get-ChildItem $windowsApps -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "alienware|awcc|alienfx|dell.*commandcenter" } |
                Select-Object -ExpandProperty FullName

            if ($waDirs) {
                $paths += $waDirs
            }
        }
        catch {
            Write-Log "Failed to enumerate WindowsApps subfolders: $($_.Exception.Message)" "WARN"
        }
    }

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Log "Removing folder: $p" "INFO"
            try {
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
                Write-Log "Folder removed: $p" "INFO"
            }
            catch {
                Write-Log "Failed to remove folder '$p': $($_.Exception.Message)" "WARN"
            }
        }
        else {
            Write-Log "Folder not found (skipping): $p" "INFO"
        }
    }
}

# -------------------------------
# Orchestration
# -------------------------------

Write-Log "Starting Alienware Command Center 5.x full removal script." "INFO"

Assert-Elevation

$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Remove-AWCCPackages
    Remove-AWCCServicesAndDrivers
    Reset-WindowsAppsPermissions
    Remove-AWCCFolders
}
catch {
    Write-Log "Unexpected failure: $($_.Exception.Message)" "ERROR"
}

$overallStopwatch.Stop()
Write-Log ("Alienware Command Center removal sequence completed in {0:n1} seconds." -f $overallStopwatch.Elapsed.TotalSeconds) "INFO"
Write-Log "You may want to reboot to ensure all drivers and services are fully unloaded." "INFO"
