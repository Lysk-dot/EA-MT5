<#
  setup-autocommit.ps1
  - Cria uma tarefa agendada no Windows para rodar diariamente às 04:00 UTC-3
  - Calcula o horário local equivalente a 04:00 em "SA Eastern Standard Time" (UTC-3) e agenda nesse horário
  - Observação: se o fuso do servidor mudar ou houver DST no servidor, pode ser necessário recriar a tarefa
#>
[CmdletBinding()]
param(
  [string]$RepoPath = $PSScriptRoot,
  [string]$TaskName = 'EAData-AutoCommit-0400-UTC3',
  [switch]$Push,
  [string]$TimeZoneId = 'SA Eastern Standard Time', # UTC-3 (Buenos Aires)
  [string]$UtcMinus3Time = '04:00' # 04:00 no fuso UTC-3
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { Get-Location }
if (-not $RepoPath) { $RepoPath = $scriptDir }

$autoCommit = Join-Path $RepoPath 'auto-commit.ps1'
if (-not (Test-Path $autoCommit)) {
  Write-Error "Script não encontrado: $autoCommit"
  exit 1
}

# Calcula o horário local equivalente a 04:00 UTC-3
try {
  $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
} catch {
  Write-Error "TimeZoneId inválido: $TimeZoneId"
  exit 1
}
<#[
$today = Get-Date
#]
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
$dtInTzUnspec = [datetime]::SpecifyKind(($today.Date + $timeSpan), 'Unspecified')
$localAt = [System.TimeZoneInfo]::ConvertTime($dtInTzUnspec, $tz, [System.TimeZoneInfo]::Local)

# Se já passou hoje, o gatilho diário ainda usa apenas a hora, mas ajustamos a mensagem
$atDisplay = $localAt.ToString('HH:mm')

# Trigger diário na hora local calculada
$trigger = New-ScheduledTaskTrigger -Daily -At $localAt

# Ação: executar powershell chamando o script
$psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$autoCommit`""
if ($Push.IsPresent) { $psArgs += ' -Push' }
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs -WorkingDirectory $RepoPath

try {
  # Registra a tarefa para o usuário atual; por padrão roda quando o usuário estiver logado
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
  }
  Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -Action $action -Description ("Auto commit diário às 04:00 (UTC-3) ~ {0} local" -f $atDisplay) | Out-Null
  Write-Host ("Tarefa '{0}' criada. Horário local agendado: {1} (equivalente a 04:00 UTC-3)." -f $TaskName, $atDisplay) -ForegroundColor Green
}
catch {
  Write-Error "Falha ao registrar a tarefa: $($_.Exception.Message)"
  exit 1
}

# Opcional: executar agora para testar
if ($env:RUN_NOW -eq '1') {
  Start-ScheduledTask -TaskName $TaskName
}