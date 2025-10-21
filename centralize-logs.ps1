<#
  Centraliza logs de API, Relay e MT5 em um arquivo único rolling.
  - Junta infra\logs\api.log e infra\logs\relay.log com Journal do MT5.
  - Mantém um arquivo central em logs\central.log (rotaciona ~20MB).
  Use com agendador (a cada 1-5 min) ou execute manualmente.
#>
[<#
Script movido para scripts/util/ para organização.
#>]
[CmdletBinding()]
param(
  [string]$Mt5LogsDir = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\logs",
  [int]$LookbackMinutes = 5
)

$ErrorActionPreference = 'SilentlyContinue'
$BaseDir = Split-Path -Parent $PSCommandPath
$InfraDir = Join-Path $BaseDir 'infra'
$CentralDir = Join-Path $InfraDir 'logs'
if(-not (Test-Path $CentralDir)){ New-Item -ItemType Directory -Path $CentralDir | Out-Null }

$ApiLog = Join-Path $CentralDir 'api.log'
$RelayLog = Join-Path $CentralDir 'relay.log'
$Central = Join-Path $CentralDir 'central.log'

# Rotation ~20MB
if(Test-Path $Central){
  $size = (Get-Item $Central).Length
  if($size -gt 20MB){
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item $Central "$Central.$stamp.bak" -ErrorAction SilentlyContinue
    Clear-Content $Central -ErrorAction SilentlyContinue
  }
}

function Append-Lines {
  param([string]$Source,[string[]]$Lines)
  foreach($l in $Lines){ "[$(Get-Date -Format 's')] $Source | $l" | Out-File -Append -FilePath $Central -Encoding UTF8 }
}

# Last minutes from API/Relay logs (tail by time approximation)
foreach($file in @($ApiLog,$RelayLog)){
  if(Test-Path $file){
    $lines = Get-Content $file -Tail 500
    Append-Lines -Source (Split-Path -Leaf $file) -Lines $lines
  }
}

# MT5 Journal last file
try {
  $latest = Get-ChildItem -Path $Mt5LogsDir -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){
    $since = (Get-Date).AddMinutes(-$LookbackMinutes)
    $sel = Get-Content $latest.FullName | Select-Object -Last 200
    Append-Lines -Source ("MT5:" + $latest.Name) -Lines $sel
  }
} catch {}

Write-Host "Central log updated: $Central" -ForegroundColor Green
