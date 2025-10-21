param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSCommandPath
Set-Location $ScriptDir

## Central logs dir
$CentralLogs = Join-Path (Split-Path -Parent $ScriptDir) 'logs'
if(-not (Test-Path $CentralLogs)){ New-Item -ItemType Directory -Path $CentralLogs | Out-Null }
$RelayLog = Join-Path $CentralLogs 'relay.log'

function Get-PythonExe {
  if($env:PYTHON_EXE -and (Test-Path $env:PYTHON_EXE)){ return $env:PYTHON_EXE }
  $candidates = @(
    "C:\\Program Files\\Python312\\python.exe",
    "C:\\Program Files\\Python311\\python.exe",
    "C:\\Program Files\\Python310\\python.exe",
    "C:\\Program Files (x86)\\Python312\\python.exe"
  )
  foreach($p in $candidates){ if(Test-Path $p){ return $p } }
  $py = Get-Command python -ErrorAction SilentlyContinue
  if($py){ return $py.Path }
  throw "Python executable not found. Install Python system-wide or set PYTHON_EXE env var."
}

$PythonExe = Get-PythonExe

function Ensure-PyModules {
  param([string[]]$Modules)
  $missing = @()
  foreach($m in $Modules){
    $code = "import $m"
    & $PythonExe -c $code 2>$null
    if($LASTEXITCODE -ne 0){ $missing += $m }
  }
  if($missing.Count -gt 0){
    Write-Host "[deps] installing: $($missing -join ', ')" -ForegroundColor Yellow
    & $PythonExe -m pip install --upgrade pip | Out-Null
    & $PythonExe -m pip install fastapi uvicorn httpx python-dotenv | Out-Null
  }
}

Ensure-PyModules -Modules @('fastapi','uvicorn','httpx','dotenv')

Write-Host "[relay] starting uvicorn on 127.0.0.1:18001" -ForegroundColor Cyan

# Lightweight log rotation (keep ~10MB)
if(Test-Path $RelayLog){
  $size = (Get-Item $RelayLog).Length
  if($size -gt 10MB){
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item $RelayLog "$RelayLog.$stamp.bak" -ErrorAction SilentlyContinue
    Clear-Content $RelayLog -ErrorAction SilentlyContinue
  }
}

# Startup marker
"$(Get-Date -AsUtc).ToString('o')`tRELAY starting on 18001" | Out-File -Append -FilePath $RelayLog -Encoding UTF8

# Start relay and tee output to log
& $PythonExe -m uvicorn app.main:app --host 127.0.0.1 --port 18001 --workers 1 *>> $RelayLog
