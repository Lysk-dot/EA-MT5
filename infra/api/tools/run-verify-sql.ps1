param(
    [string]$Api = "http://192.168.15.20:18001",
    [string]$Token = "mt5_trading_secure_key_2025_prod",
    [string]$DbHost = "192.168.15.20",
    [int]$DbPort = 5432,
    [string]$DbName = "mt5_trading",
    [string]$DbUser = "trader",
    [string]$DbPass = "trader123",
    [int]$DbMinutes = 60,
    [int]$Timeout = 5
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'verify_main.py'
$python = 'python'
Write-Host "Verificando API e banco principal (${DbHost}:${DbPort}/${DbName})"
& $python $script --api $Api --token $Token --timeout $Timeout --db-host $DbHost --db-port $DbPort --db-name $DbName --db-user $DbUser --db-pass $DbPass --db-minutes $DbMinutes
if ($LASTEXITCODE -ne 0) {
    Write-Error "Verifier failed with exit code $LASTEXITCODE"
}