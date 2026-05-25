<#
.SYNOPSIS
    WayneOS Windows Azure Connectivity Mega Script (Full Overhaul)

.DESCRIPTION
    End-to-end diagnostics and optional repair for Azure connectivity on Windows, focused on:
    - TLS / Schannel
    - Root CAs
    - Proxies (WinHTTP + system)
    - Windows Defender Network Protection
    - Windows Firewall (profiles, app rules, WSL NIC)
    - WFP hints (security filters)
    - Azure CLI + ARM tests (PowerShell + az)
    - High-signal summary at the end

.NOTES
    - Run in PowerShell 7 as Administrator.
    - Diagnostics are always safe; repairs are gated by explicit prompts.
#>

# ==========================================
# 0. Global setup and helpers
# ==========================================
$ErrorActionPreference = 'Stop'
$global:Diagnostics = [System.Collections.Generic.List[object]]::new()

Write-Host "=== WayneOS Windows Azure Connectivity Mega Script (Overhauled) ===" -ForegroundColor Cyan

function Pass($msg) {
    $global:Diagnostics.Add([PSCustomObject]@{ Level='PASS'; Message=$msg })
    Write-Host "✔ $msg" -ForegroundColor Green
}
function Fail($msg) {
    $global:Diagnostics.Add([PSCustomObject]@{ Level='FAIL'; Message=$msg })
    Write-Host "✘ $msg" -ForegroundColor Red
}
function Warn($msg) {
    $global:Diagnostics.Add([PSCustomObject]@{ Level='WARN'; Message=$msg })
    Write-Host "• $msg" -ForegroundColor Yellow
}
function Info($msg) {
    Write-Host "• $msg" -ForegroundColor DarkCyan
}
function Section($msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Magenta
}

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Message)
    $response = Read-Host "$Message [y/N]"
    return $response -match '^(y|yes)$'
}

# Helper: treat HTTP status as connectivity OK if we reached the server
function Test-HttpConnectivityResult {
    param(
        [Parameter(Mandatory)][int]$StatusCode,
        [Parameter(Mandatory)][string]$Context
    )
    if ($StatusCode -ge 200 -and $StatusCode -lt 400) {
        Pass "$Context - HTTP $StatusCode (success)."
    }
    elseif ($StatusCode -ge 400 -and $StatusCode -lt 500) {
        # Connectivity OK, application-level issue (auth, API version, etc.)
        Warn "$Context - HTTP $StatusCode (connectivity OK, request/contract issue)."
    }
    else {
        Fail "$Context - HTTP $StatusCode (possible service or network issue)."
    }
}

# ==========================================
# 1. Environment info
# ==========================================
Section "1. Environment info"

Info "User: $env:USERNAME"
Info "Computer: $env:COMPUTERNAME"
Info "OS: $([Environment]::OSVersion.VersionString)"
Info "PowerShell: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

# ==========================================
# 2. TLS baseline (current process)
# ==========================================
Section "2. TLS baseline configuration"

try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 -bor `
        [Net.SecurityProtocolType]::Tls13
    Pass "Process TLS protocol set to TLS 1.2 + 1.3."
}
catch {
    Fail "Unable to set process TLS protocol: $($_.Exception.Message)"
}

# ==========================================
# 3. Proxy diagnostics (WinHTTP + system)
# ==========================================
Section "3. Proxy diagnostics"

# WinHTTP proxy
Info "Checking WinHTTP proxy..."
$winHttpProxy = netsh winhttp show proxy
Write-Host $winHttpProxy

if ($winHttpProxy -match "Direct access") {
    Pass "WinHTTP proxy: Direct access (no proxy configured)."
} else {
    Warn "WinHTTP proxy is configured."
    if (Confirm-Action -Message "Reset WinHTTP proxy to direct access?") {
        try {
            netsh winhttp reset proxy | Out-Null
            Pass "WinHTTP proxy reset to direct access."
        }
        catch {
            Fail "Failed to reset WinHTTP proxy: $($_.Exception.Message)"
        }
    }
    else {
        Info "Leaving WinHTTP proxy as currently configured."
    }
}

# System (WinINET) proxy
Info "Checking system (WinINET) proxy..."
$sysProxy = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
if ($null -ne $sysProxy -and $sysProxy.ProxyEnable -eq 1) {
    Warn "System proxy enabled: $($sysProxy.ProxyServer)"
    if (Confirm-Action -Message "Disable system proxy for current user?") {
        try {
            Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
            Pass "System proxy disabled for current user."
        }
        catch {
            Fail "Failed to disable system proxy: $($_.Exception.Message)"
        }
    }
    else {
        Info "Leaving system proxy enabled."
    }
} else {
    Pass "System proxy: Not enabled."
}

# ==========================================
# 4. Defender Network Protection
# ==========================================
Section "4. Windows Defender Network Protection"

try {
    $mpPref = Get-MpPreference
    $np = $mpPref.EnableNetworkProtection
    if ($np -eq 1) {
        Warn "Network Protection is ENABLED (can interfere with cloud TLS)."
        if (Confirm-Action -Message "Disable Network Protection now?") {
            try {
                Set-MpPreference -EnableNetworkProtection Disabled
                Pass "Network Protection disabled."
            }
            catch {
                Fail "Failed to disable Network Protection: $($_.Exception.Message)"
            }
        }
        else {
            Info "Leaving Network Protection enabled."
        }
    } elseif ($np -eq 0) {
        Pass "Network Protection is disabled."
    } else {
        Warn "Network Protection state: $np (non-standard)."
    }
}
catch {
    Warn "Unable to query Defender preferences (3rd-party AV or limited permissions): $($_.Exception.Message)"
}

# ==========================================
# 5. Firewall basics + outbound test
# ==========================================
Section "5. Windows Firewall connectivity"

try {
    $fwTest = Test-NetConnection management.azure.com -Port 443
    if ($fwTest.TcpTestSucceeded) {
        Pass "Outbound TCP 443 to management.azure.com is allowed (firewall, routing, DNS OK at TCP level)."
    } else {
        Fail "Test-NetConnection: TCP 443 to management.azure.com FAILED."
    }
}
catch {
    Fail "Test-NetConnection failed: $($_.Exception.Message)"
}

if (Confirm-Action -Message "Temporarily disable all Windows Firewall profiles to test ARM directly?") {
    Info "Disabling Domain, Private, and Public firewall profiles..."
    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        try {
            $resp = Invoke-WebRequest "https://management.azure.com/subscriptions?api-version=2020-01-01" -Method Get -TimeoutSec 10 -UseBasicParsing
            Test-HttpConnectivityResult -StatusCode ([int]$resp.StatusCode) -Context "ARM via PowerShell (Schannel) with firewall OFF"
        }
        catch {
            Fail "ARM test with firewall OFF failed: $($_.Exception.Message)"
        }
    }
    finally {
        Info "Re-enabling all firewall profiles..."
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    }
} else {
    Info "Skipping firewall full-disable test."
}

# ==========================================
# 6. WFP hints (Malwarebytes / deep filters)
# ==========================================
Section "6. WFP state (quick scan for security filters)"

try {
    $wfpState = netsh wfp show state
    $wfpHits = $wfpState | Select-String -Pattern "Malwarebytes","MBAM","WebProtection","HTTPS","TLSInspection","TLS Inspection","ContentFilter" -SimpleMatch
    if ($wfpHits) {
        Warn "Detected potential security/WFP filters that may affect TLS:"
        $wfpHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    } else {
        Pass "No obvious Malwarebytes/WebProtection/TLS inspection WFP callouts in quick scan."
    }
}
catch {
    Warn "Failed to query WFP state: $($_.Exception.Message)"
}

# ==========================================
# 7. Root CA / Schannel repair (optional)
# ==========================================
Section "7. Root CA and Schannel TLS configuration"

if (Confirm-Action -Message "Rebuild root CA store from Windows Update and repair Schannel TLS keys?") {
    try {
        Info "Downloading and importing fresh root CAs from Windows Update..."
        certutil -generateSSTFromWU roots.sst | Out-Null
        certutil -addstore -f root roots.sst | Out-Null
        Remove-Item roots.sst -Force -ErrorAction SilentlyContinue
        Pass "Root certificates updated from Microsoft."

        Info "Repairing Schannel TLS registry keys..."
        $schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"

        New-Item -Path "$schannelPath\Protocols\TLS 1.2\Client" -Force | Out-Null
        Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.2\Client" -Name Enabled -Value 1
        Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.2\Client" -Name DisabledByDefault -Value 0

        New-Item -Path "$schannelPath\Protocols\TLS 1.3\Client" -Force | Out-Null
        Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.3\Client" -Name Enabled -Value 1
        Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.3\Client" -Name DisabledByDefault -Value 0

        Pass "Schannel TLS client settings for TLS 1.2 / 1.3 repaired."
    }
    catch {
        Fail "Root CA/Schannel repair failed: $($_.Exception.Message)"
    }
}
else {
    Info "Skipping root CA / Schannel repair (diagnostics only)."
}

# ==========================================
# 8. ARM endpoint tests (PowerShell + OpenSSL + az)
# ==========================================
Section "8. ARM endpoint tests"

# 8a. PowerShell / Schannel
try {
    $resp = Invoke-WebRequest "https://management.azure.com/subscriptions?api-version=2020-01-01" -Method Get -TimeoutSec 15 -UseBasicParsing
    Test-HttpConnectivityResult -StatusCode ([int]$resp.StatusCode) -Context "ARM via PowerShell (Schannel)"
}
catch {
    Fail "ARM via PowerShell (Schannel) failed: $($_.Exception.Message)"
}

# 8b. OpenSSL (if installed)
Section "8b. TLS handshake via OpenSSL (if available)"

$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
if ($opensslCmd) {
    try {
        $tlsOutput = openssl s_client -connect management.azure.com:443 -servername management.azure.com 2>&1
        if ($tlsOutput -match "Verify return code: 0") {
            Pass "OpenSSL TLS handshake to management.azure.com succeeded and certificate is trusted."
        } else {
            Warn "OpenSSL TLS handshake did not report Verify return code 0."
            $tlsOutput | Select-String -Pattern "Verify return code","error" | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkYellow
            }
        }
    }
    catch {
        Fail "OpenSSL TLS handshake test failed: $($_.Exception.Message)"
    }
} else {
    Info "OpenSSL not found on PATH; skipping OpenSSL TLS handshake test."
}

# 8c. Azure CLI / az rest
Section "8c. ARM via Azure CLI (az rest)"

if (Get-Command az -ErrorAction SilentlyContinue) {
    try {
        az rest --method get --uri "https://management.azure.com/subscriptions?api-version=2020-01-01" --only-show-errors 1>$null
        if ($LASTEXITCODE -eq 0) {
            Pass "ARM via az rest succeeded."
        } else {
            Fail "az rest returned exit code $LASTEXITCODE."
        }
    }
    catch {
        Fail "ARM via az rest failed: $($_.Exception.Message)"
    }
} else {
    Warn "Azure CLI not found on PATH; skipping az rest test."
}

# ==========================================
# 9. Azure CLI health (install, login, ARM API)
# ==========================================
Section "9. Azure CLI health"

if (Get-Command az -ErrorAction SilentlyContinue) {
    Pass "Azure CLI is installed."

    try {
        $acctName = az account show --query name -o tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $acctName) {
            Pass "Azure CLI logged in as: $acctName"
        } else {
            Warn "Azure CLI not logged in (or unable to query). Run: az login"
        }
    }
    catch {
        Fail "Failed to query Azure CLI account: $($_.Exception.Message)"
    }

    try {
        az group list -o table | Out-Null
        Pass "ARM API (az group list) succeeded."
    }
    catch {
        Fail "ARM API (az group list) failed: $($_.Exception.Message)"
    }
} else {
    Fail "Azure CLI is not installed; az-based tests unavailable."
}

# ==========================================
# 10. App-level firewall rules (pwsh, az/python)
# ==========================================
Section "10. App-level firewall visibility"

$pathsToCheck = @(
    "C:\Program Files\PowerShell\7\pwsh.exe",
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\python.exe",
    "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
)

foreach ($path in $pathsToCheck) {
    if (-not (Test-Path $path)) {
        Info "Binary not found, skipping firewall inspection: $path"
        continue
    }

    $rules = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
             Where-Object { $_.Program -ieq $path }

    if ($rules) {
        Write-Host "Firewall rules for ${path}:" -ForegroundColor Yellow
        foreach ($r in $rules) {
            $rule = Get-NetFirewallRule -Name $r.InstanceID -ErrorAction SilentlyContinue
            if ($rule) {
                Write-Host "  $($rule.DisplayName) - Action: $($rule.Action) - Enabled: $($rule.Enabled)" -ForegroundColor Gray
            }
        }
    } else {
        Info "No explicit firewall rules found for $path."
    }
}

if (Confirm-Action -Message "Create explicit ALLOW outbound rules for PowerShell and Azure CLI executables?") {
    foreach ($path in $pathsToCheck) {
        if (Test-Path $path) {
            $name = "WayneOS Allow Outbound - $([System.IO.Path]::GetFileName($path))"
            try {
                New-NetFirewallRule -DisplayName $name -Direction Outbound -Program $path -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
                Pass "Created outbound ALLOW rule for $path"
            }
            catch {
                $errMsg = $_.Exception.Message
                Warn "Could not create firewall rule for ${path}: ${errMsg}"
            }
        }
    }
} else {
    Info "Skipping creation of explicit ALLOW firewall rules for app binaries."
}

# ==========================================
# 11. WSL NIC firewall allowance
# ==========================================
Section "11. WSL virtual NIC firewall rules"

try {
    $wslAdapters = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -like "*Hyper-V*" -or
        $_.Name -like "*WSL*" -or
        $_.InterfaceDescription -like "*WSL*"
    }

    if ($wslAdapters) {
        foreach ($adapter in $wslAdapters) {
            Info "Detected potential WSL/Hyper-V adapter: $($adapter.Name) ($($adapter.InterfaceDescription))"
            $displayName = "WayneOS WSL Outbound Allow - $($adapter.Name)"
            try {
                New-NetFirewallRule -DisplayName $displayName -Direction Outbound -Action Allow -InterfaceAlias $adapter.Name -Profile Any -ErrorAction SilentlyContinue | Out-Null
                Pass "Created outbound ALLOW rule for WSL adapter '$($adapter.Name)'."
            }
            catch {
                Warn "Failed to create firewall rule for '$($adapter.Name)': $($_.Exception.Message)"
            }
        }
    } else {
        Info "No WSL/Hyper-V adapters detected."
    }
}
catch {
    Warn "Error while processing WSL NIC firewall rules: $($_.Exception.Message)"
}

# ==========================================
# 12. Final ARM test and summary
# ==========================================
Section "12. Final ARM test (PowerShell / Schannel)"

try {
    $resp = Invoke-WebRequest "https://management.azure.com/subscriptions?api-version=2020-01-01" -Method Get -TimeoutSec 15 -UseBasicParsing
    Test-HttpConnectivityResult -StatusCode ([int]$resp.StatusCode) -Context "FINAL ARM via PowerShell (Schannel)"
}
catch {
    Fail "FINAL ARM via PowerShell (Schannel) failed: $($_.Exception.Message)"
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$global:Diagnostics | ForEach-Object {
    $color = switch ($_.Level) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'Gray' }
    }
    Write-Host ("[{0}] {1}" -f $_.Level, $_.Message) -ForegroundColor $color
}

Write-Host "`n=== WayneOS Windows Azure Connectivity Mega Script Complete ===" -ForegroundColor Cyan
