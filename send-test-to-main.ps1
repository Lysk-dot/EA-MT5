param(
  [string]$ApiBase = "http://192.168.15.20:18001",
  [string]$Token = "changeme",
  [string]$Symbol = "TESTUSD"
)

$ErrorActionPreference = 'Stop'

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$payload = @(
  @{
    symbol    = $Symbol
    timeframe = 'M1'
    ts        = $ts
    open      = 1.2345
    high      = 1.2350
    low       = 1.2330
    close     = 1.2349
    volume    = 100
    kind      = 'bar'
    meta      = @{ source = 'svc-test'; note = 'manual test insert' }
  }
)

$json = $payload | ConvertTo-Json -Compress
$headers = @{ 'x-api-key' = $Token }

Write-Host "POST $ApiBase/ingest" -ForegroundColor Cyan
Write-Host "Payload: $json" -ForegroundColor DarkGray

try {
  $resp = Invoke-RestMethod -Uri ("$ApiBase/ingest") -Method Post -ContentType 'application/json' -Headers $headers -Body $json -TimeoutSec 10
  ($resp | ConvertTo-Json -Compress) | Write-Host
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
