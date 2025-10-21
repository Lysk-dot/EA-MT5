param(
  [string]$BindHost = "127.0.0.1",
  [int]$BindPort = 18001,
  [string]$RemoteIngest = "http://192.168.15.20:18001/ingest",
  [string]$RemoteTick = "http://192.168.15.20:18001/ingest/tick",
  [string]$RemoteToken = "changeme"
)

Write-Host "";
Write-Host " Configurando Edge Relay local..." -ForegroundColor Cyan
$relayRoot = Join-Path $PSScriptRoot 'infra/edge-relay'
$venvPath = Join-Path $relayRoot '.venv'
$queuePath = Join-Path $relayRoot 'queue'

if(!(Test-Path $relayRoot)){ throw "Pasta $relayRoot não encontrada" }
if(!(Test-Path $queuePath)){ New-Item -ItemType Directory -Path $queuePath | Out-Null }

<#
Script movido para scripts/util/ para organização.
#>
<# Este script foi movido para scripts/util/setup-edge-relay.ps1 para organização da raiz. #>
if ($PSScriptRoot -notlike '*scripts*') {
  $newPath = Join-Path $PSScriptRoot 'scripts\util\setup-edge-relay.ps1'
  if (Test-Path $newPath) { . $newPath; exit }
}
# Create venv
if(!(Test-Path $venvPath)){
  Write-Host " Criando ambiente virtual..." -ForegroundColor Yellow
  $pythonCmd = $null
  if(Get-Command python -ErrorAction SilentlyContinue){ $pythonCmd = 'python' }
  elseif(Get-Command py -ErrorAction SilentlyContinue){ $pythonCmd = 'py' }
  if(-not $pythonCmd){ throw "Python não encontrado. Instale o Python 3.x e tente novamente." }
  & $pythonCmd -m venv "$venvPath"
}

# Activate venv
$activate = Join-Path $venvPath 'Scripts/Activate.ps1'
. "$activate"

# Install deps
Write-Host " Instalando dependências..." -ForegroundColor Yellow
pip install --upgrade pip | Out-Null
pip install -r (Join-Path $relayRoot 'requirements.txt')

# Export env vars to current session
$env:RELAY_HOST = $BindHost
$env:RELAY_PORT = "$BindPort"
$env:REMOTE_INGEST = $RemoteIngest
$env:REMOTE_TICK = $RemoteTick
$env:REMOTE_TOKEN = $RemoteToken
$env:QUEUE_DIR = $queuePath

# Move to relay root so module path app.main resolves
Set-Location $relayRoot

# Print start info without variable parsing issues
Write-Host (" Iniciando Edge Relay em http://{0}:{1} ..." -f $BindHost, $BindPort) -ForegroundColor Green

# Start server
uvicorn app.main:app --host $BindHost --port $BindPort --workers 1
