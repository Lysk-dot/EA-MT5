param(
  [string]$LinuxHost = "192.168.15.20",
  [int]$SshPort = 22,
  [string]$ApiUrl = "http://192.168.15.20:18001/health",
  [int]$ApiTimeoutSec = 3,
  [string]$DbHost = "192.168.15.20",
  [int]$DbPort = 5432,
  [string]$DbUser,
  [string]$DbName,
  [string]$DbPassword
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Result {
  param([string]$Label,[bool]$Ok,[string]$Info)
  if($Ok){ Write-Host ("[OK] {0} - {1}" -f $Label,$Info) -ForegroundColor Green }
  else   { Write-Host ("[!!] {0} - {1}" -f $Label,$Info) -ForegroundColor Red }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " VERIFICAÇÃO DE CONEXÃO" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
Write-Host ("Alvo Linux: {0} (ssh:{1})" -f $LinuxHost,$SshPort) -ForegroundColor Gray
Write-Host ("API URL:     {0}" -f $ApiUrl) -ForegroundColor Gray
Write-Host ("DB:          {0}:{1}" -f $DbHost,$DbPort) -ForegroundColor Gray
if($DbUser -and $DbName){ Write-Host ("DB Cred:     {0}@{1}" -f $DbUser,$DbName) -ForegroundColor Gray }
Write-Host "" 

# 1) Ping host
try {
  $ping = Test-Connection -ComputerName $LinuxHost -Count 1 -Quiet
  Write-Result "Ping Linux" $ping (if($ping){"ok"}else{"falha"})
} catch { Write-Result "Ping Linux" $false "erro" }

# 2) SSH TCP check
try {
  $ssh = Test-NetConnection -ComputerName $LinuxHost -Port $SshPort
  $lat = $null
  if($ssh.PingSucceeded -and $ssh.PingReplyDetails){ $lat = $ssh.PingReplyDetails.RoundtripTime }
  $info = if($lat -ne $null){ "latência=${lat}ms" } else { "porta ${SshPort}" }
  Write-Result "SSH TCP" $ssh.TcpTestSucceeded $info
} catch { Write-Result "SSH TCP" $false "erro" }

# 3) API health
try {
  $api = Invoke-RestMethod -Uri $ApiUrl -TimeoutSec $ApiTimeoutSec
  $ok = $true
  $info = "respondeu"
  if($api -and $api.ok -ne $null){ $info += (" | ok={0}" -f $api.ok) }
  Write-Result "API Health" $ok $info
} catch {
  Write-Result "API Health" $false ("sem resposta em {0}s" -f $ApiTimeoutSec)
}

# 4) DB TCP check
try {
  $db = Test-NetConnection -ComputerName $DbHost -Port $DbPort
  Write-Result "DB TCP" $db.TcpTestSucceeded ("porta {0}" -f $DbPort)
} catch {
  Write-Result "DB TCP" $false "erro"
}

# 5) DB deep check (optional via psql)
$psql = Get-Command psql -ErrorAction SilentlyContinue
if($psql -and $DbUser -and $DbName){
  Write-Host "Executando teste psql (select 1)..." -ForegroundColor DarkGray
  $env:PGPASSWORD = $DbPassword
  $psqlPath = $psql.Path
  $out = & $psqlPath -h $DbHost -p $DbPort -U $DbUser -d $DbName -c "select 1;" 2>$null
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  $deepOk = ($LASTEXITCODE -eq 0)
  Write-Result "DB psql" $deepOk (if($deepOk){"ok"}else{"falha (psql)"})
} else {
  if($DbUser -and $DbName -and -not $psql){ Write-Host "psql não encontrado; teste profundo de DB omitido" -ForegroundColor Yellow }
}

Write-Host "`nConcluído." -ForegroundColor Cyan
