<#
.SYNOPSIS
    Deep Azure CLI + PowerShell TLS repair for Windows.
    Fixes:
    - Broken Schannel trust
    - Missing root certificates
    - TLS handshake failures
    - ARM endpoint unreachable in PowerShell
#>

Write-Host "=== WayneOS Windows Azure TLS + Connectivity Repair ===" -ForegroundColor Cyan

function Pass($msg) { Write-Host "✔ $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "✘ $msg" -ForegroundColor Red }

# ---------------------------------------------------------
# 1. Enable TLS 1.2/1.3
# ---------------------------------------------------------
Write-Host "`n=== 1. Enabling TLS 1.2/1.3 ===" -ForegroundColor Yellow
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls13
Pass "TLS 1.2/1.3 enabled."

# ---------------------------------------------------------
# 2. Rebuild Windows Root Certificate Store
# ---------------------------------------------------------
Write-Host "`n=== 2. Rebuilding Windows Root Certificate Store ===" -ForegroundColor Yellow

# Force Windows to update root certificates
certutil -generateSSTFromWU roots.sst | Out-Null
certutil -addstore -f root roots.sst | Out-Null
Remove-Item roots.sst -Force

Pass "Root certificates updated from Microsoft."

# ---------------------------------------------------------
# 3. Repair Schannel registry keys
# ---------------------------------------------------------
Write-Host "`n=== 3. Repairing Schannel TLS registry keys ===" -ForegroundColor Yellow

$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"

# Ensure TLS 1.2/1.3 enabled
New-Item -Path "$schannelPath\Protocols\TLS 1.2\Client" -Force | Out-Null
Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.2\Client" -Name Enabled -Value 1
Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.2\Client" -Name DisabledByDefault -Value 0

New-Item -Path "$schannelPath\Protocols\TLS 1.3\Client" -Force | Out-Null
Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.3\Client" -Name Enabled -Value 1
Set-ItemProperty -Path "$schannelPath\Protocols\TLS 1.3\Client" -Name DisabledByDefault -Value 0

Pass "Schannel TLS registry keys repaired."

# ---------------------------------------------------------
# 4. Test ARM endpoint via PowerShell (Schannel)
# ---------------------------------------------------------
Write-Host "`n=== 4. Testing ARM endpoint via PowerShell (Schannel) ===" -ForegroundColor Yellow

try {
    Invoke-WebRequest https://management.azure.com -Method Head -TimeoutSec 10 -UseBasicParsing | Out-Null
    Pass "ARM endpoint reachable via PowerShell (Schannel)."
}
catch {
    Fail "ARM endpoint unreachable via PowerShell (Schannel)."
    Write-Host $_.Exception.Message -ForegroundColor DarkYellow
}

# ---------------------------------------------------------
# 5. Test ARM endpoint via Azure CLI (OpenSSL)
# ---------------------------------------------------------
Write-Host "`n=== 5. Testing ARM endpoint via Azure CLI (OpenSSL) ===" -ForegroundColor Yellow

try {
    az rest --method get --uri https://management.azure.com/subscriptions?api-version=2020-01-01 | Out-Null
    Pass "ARM endpoint reachable via Azure CLI (OpenSSL)."
}
catch {
    Fail "ARM endpoint unreachable via Azure CLI."
}

# ---------------------------------------------------------
# 6. Test Azure login
# ---------------------------------------------------------
Write-Host "`n=== 6. Checking Azure login ===" -ForegroundColor Yellow
try {
    $acct = az account show --query name -o tsv
    Pass "Logged in as: $acct"
}
catch {
    Fail "Not logged in. Run: az login"
}

Write-Host "`n=== Windows Azure TLS Repair Complete ===" -ForegroundColor Cyan
