param(
  [ValidateSet("install","start","stop","remove","status")] [string]$Action = "install",
  [string]$PythonPath,
  [string]$AllowedToken = "changeme"
)

# This script registers two Scheduled Tasks (run as SYSTEM at startup) to behave like services:
# - EA-API-Lite: FastAPI + SQLite on 127.0.0.1:18002
# - EA-Edge-Relay: FastAPI relay on 127.0.0.1:18001
# It also supports start/stop/remove/status operations.

<#
Script movido para scripts/util/ para organização.
#>
$ErrorActionPreference = 'Stop'

function Resolve-Python {
  param([string]$Override)
  if($Override){ return $Override }
  $py = Get-Command python -ErrorAction SilentlyContinue
  if($py){ return $py.Path }
  throw "Python not found in PATH. Install Python or pass -PythonPath 'C:\\Path\\to\\python.exe'"
}

# Base directories
$ScriptDir = Split-Path -Parent $PSCommandPath
$ApiDir    = Join-Path $ScriptDir 'infra\api'
$RelayDir  = Join-Path $ScriptDir 'infra\edge-relay'

# Task names
$ApiTaskName   = 'EA-API-Lite'
$RelayTaskName = 'EA-Edge-Relay'

# Compose commands
$PythonExe = Resolve-Python -Override $PythonPath

# Use explicit PowerShell to set env and working directory, then invoke python
# Call service runner scripts which ensure dependencies and start servers
$ApiCmd   = "& `"$PSHOME\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$ApiDir\service-run-api.ps1`" -AllowedToken `"$AllowedToken`""
$RelayCmd = "& `"$PSHOME\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$RelayDir\service-run-relay.ps1`""

function New-ServiceTask {
  param(
    [string]$Name,
    [string]$Command
  )
  Write-Host "[+] Creating scheduled task: $Name" -ForegroundColor Cyan
  $action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `$ErrorActionPreference='Stop'; $Command"
  $trigger  = New-ScheduledTaskTrigger -AtStartup
  $principal= New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
  try {
    # If exists, update; else register
    $existing = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if($existing){
      Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Description "Autostart service for $Name" | Out-Null
  } catch {
    throw "Failed to register task ${Name}: $($_.Exception.Message)"
  }
}

function Start-ServiceTask {
  param([string]$Name)
  <# Este script foi movido para scripts/util/setup-windows-services.ps1 para organização da raiz. #>
  if ($PSScriptRoot -notlike '*scripts*') {
    $newPath = Join-Path $PSScriptRoot 'scripts\util\setup-windows-services.ps1'
    if (Test-Path $newPath) { . $newPath; exit }
  }
  Write-Host "[*] Starting: $Name" -ForegroundColor Green
  Start-ScheduledTask -TaskName $Name | Out-Null
}
function Stop-ServiceTask {
  param([string]$Name)
  Write-Host "[*] Stopping: $Name" -ForegroundColor Yellow
  Stop-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue | Out-Null
}
function Remove-ServiceTask {
  param([string]$Name)
  Write-Host "[-] Removing: $Name" -ForegroundColor Red
  Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

function Show-Status {
  param([string]$Name)
  $t = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
  if($t){
    $state = ($t | Get-ScheduledTaskInfo).State
    Write-Host ("{0,-20} {1}" -f $Name, $state)
  } else {
    Write-Host ("{0,-20} NOT INSTALLED" -f $Name) -ForegroundColor DarkGray
  }
}

switch($Action){
  'install' {
    New-ServiceTask -Name $ApiTaskName -Command $ApiCmd
    New-ServiceTask -Name $RelayTaskName -Command $RelayCmd
    # Start now
    Start-ServiceTask -Name $ApiTaskName
    Start-ServiceTask -Name $RelayTaskName
    Start-Sleep -Seconds 4
    Write-Host "\nStatus:" -ForegroundColor Gray
    Show-Status -Name $ApiTaskName
    Show-Status -Name $RelayTaskName
  }
  'start' {
    Start-ServiceTask -Name $ApiTaskName
    Start-ServiceTask -Name $RelayTaskName
    Start-Sleep -Seconds 2
    Show-Status -Name $ApiTaskName
    Show-Status -Name $RelayTaskName
  }
  'stop' {
    Stop-ServiceTask -Name $ApiTaskName
    Stop-ServiceTask -Name $RelayTaskName
    Start-Sleep -Seconds 1
    Show-Status -Name $ApiTaskName
    Show-Status -Name $RelayTaskName
  }
  'remove' {
    Stop-ServiceTask -Name $ApiTaskName
    Stop-ServiceTask -Name $RelayTaskName
    Remove-ServiceTask -Name $ApiTaskName
    Remove-ServiceTask -Name $RelayTaskName
    Write-Host "All tasks removed."
  }
  'status' {
    Show-Status -Name $ApiTaskName
    Show-Status -Name $RelayTaskName
  }
}
