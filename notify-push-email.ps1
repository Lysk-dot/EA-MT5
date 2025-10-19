<#
  notify-push-email.ps1
  - Envia e-mail notificando sucesso ou falha do push automático.
  - Use como parte do auto-commit.ps1 ou chame após o push.
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param(
  [string]$Status = 'success', # 'success' ou 'fail'
  [string]$Details = '',
  [string]$SmtpServer = 'smtp.seudominio.com',
  [int]$SmtpPort = 587,
  [string]$From = 'alerta@seudominio.com',
  [string]$To = 'seu@email.com',
  [string]$SmtpUser = 'alerta@seudominio.com',
  [string]$SmtpPass = 'SENHA_AQUI'
)

$subject = if ($Status -eq 'success') { '[EAData] Push automático realizado com sucesso' } else { '[EAData] Falha no push automático' }
$body = "Status: $Status`n`nDetalhes:`n$Details"

try {
  Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort -From $From -To $To -Subject $subject -Body $body -Credential (New-Object System.Management.Automation.PSCredential($SmtpUser,(ConvertTo-SecureString $SmtpPass -AsPlainText -Force))) -UseSsl
  Write-Host "Notificação enviada para $To" -ForegroundColor Green
} catch {
  Write-Host "Falha ao enviar notificação: $($_.Exception.Message)" -ForegroundColor Red
}
