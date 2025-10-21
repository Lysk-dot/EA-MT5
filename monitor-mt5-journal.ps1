<#
  monitor-mt5-journal.ps1
  - Monitora o arquivo Journal do MT5 e envia alerta por e-mail se encontrar erros, falhas ou exceções.
  - Pode ser agendado ou rodado manualmente.
  - Requer configuração de SMTP e credenciais.
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param(
  [string]$JournalPath = "$env:APPDATA\MetaQuotes\Terminal\D36DE9E413048DE15F2CEE9B72F26E48\Logs",
  [string]$SmtpServer = 'smtp.seudominio.com',
  [int]$SmtpPort = 587,
  [string]$From = 'alerta@seudominio.com',
  [string]$To = 'seu@email.com',
  [string]$SmtpUser = 'alerta@seudominio.com',
  [string]$SmtpPass = 'SENHA_AQUI',
  [string[]]$Keywords = @('error', 'fail', 'exception'),
  [int]$LookbackMinutes = 10
)

# Pega o arquivo de log mais recente
$logFile = Get-ChildItem -Path $JournalPath -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $logFile) {
  Write-Host "Nenhum arquivo de log encontrado em $JournalPath" -ForegroundColor Yellow
  exit 1
}

# Lê apenas as linhas recentes
$since = (Get-Date).AddMinutes(-$LookbackMinutes)
$lines = Get-Content $logFile.FullName | Where-Object { $_ -match '\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}' -and ([datetime]::ParseExact($_.Substring(0,19), 'yyyy.MM.dd HH:mm:ss', $null) -ge $since) }

# Filtra por palavras-chave
$alerts = $lines | Where-Object { $kw = $Keywords | Where-Object { $_ -and $_.Length -gt 0 -and $_.ToLower() -in $_.ToLower() }; foreach ($k in $Keywords) { if ($_.ToLower() -like "*$k*") { return $true } }; return $false }

if ($alerts.Count -gt 0) {
  $body = "Foram encontrados erros no Journal do MT5:\n\n" + ($alerts -join "`n")
  try {
    Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort -From $From -To $To -Subject "[ALERTA] Erro no Journal MT5" -Body $body -Credential (New-Object System.Management.Automation.PSCredential($SmtpUser,(ConvertTo-SecureString $SmtpPass -AsPlainText -Force))) -UseSsl
    Write-Host "Alerta enviado para $To" -ForegroundColor Green
  } catch {
    Write-Host "Falha ao enviar e-mail: $($_.Exception.Message)" -ForegroundColor Red
  }
} else {
  Write-Host "Nenhum erro encontrado nas últimas $LookbackMinutes minutos." -ForegroundColor DarkGray
}
 
 # Moved to scripts folder
 # (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
 [CmdletBinding()]
 param(
   [string]$JournalPath = "$env:APPDATA\MetaQuotes\Terminal\D36DE9E413048DE15F2CEE9B72F26E48\Logs",
   [string]$SmtpServer = 'smtp.seudominio.com',
   [int]$SmtpPort = 587,
   [string]$From = 'alerta@seudominio.com',
   [string]$To = 'seu@email.com',
   [string]$SmtpUser = 'alerta@seudominio.com',
   [string]$SmtpPass = 'SENHA_AQUI',
   [string[]]$Keywords = @('error', 'fail', 'exception'),
   [int]$LookbackMinutes = 10
 )
