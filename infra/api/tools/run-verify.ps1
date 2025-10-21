param(
    [string]$Api = "http://192.168.15.20:18001",
    [string]$Token = "mt5_trading_secure_key_2025_prod",
    [int]$Timeout = 5
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'verify_main.py'
$python = 'python'
Write-Host "Verifying main API at $Api"
& $python $script --api $Api --token $Token --timeout $Timeout
if ($LASTEXITCODE -ne 0) {
    Write-Error "Verifier failed with exit code $LASTEXITCODE"
}
