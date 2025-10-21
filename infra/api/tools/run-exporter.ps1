param(
    [string]$Api = "http://192.168.15.20:18001",
    [string]$Token = "mt5_trading_secure_key_2025_prod",
    [int]$PageSize = 1000,
    [int]$Batch = 200,
    [switch]$All = $true,
    [switch]$SinceLastHour
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'export_to_main.py'

$python = 'python'

$common = @(
    "--api", $Api,
    "--token", $Token,
    "--page-size", $PageSize,
    "--batch", $Batch
)

if ($SinceLastHour) {
    $args = $common + @('--limit','2000','--since-minutes','60')
} elseif ($All) {
    $args = $common + @('--all')
} else {
    $args = $common + @('--limit','500')
}

Write-Host "Running exporter: $script $($args -join ' ')"
& $python $script @args
if ($LASTEXITCODE -ne 0) {
    Write-Error "Exporter failed with exit code $LASTEXITCODE"
}
