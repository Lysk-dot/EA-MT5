<#
  auto-commit.ps1
  - Faz commit automático se detectar alterações no repositório
  - Mensagem de commit segue o padrão "MAJOR.MINOR ++" (ex.: "0.1 ++") e incrementa automaticamente o MINOR
  - Se não houver um commit anterior nesse padrão, inicia em 0.1 ++
  - Opcionalmente faz push
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param(
  [string]$RepoPath = $PSScriptRoot,
  [switch]$Push
)

function Get-NextCommitVersion {
  param(
    [string]$RepoPath
  )
  # Busca o último commit cuja mensagem esteja no formato "X.Y ++"
  $pattern = '^(\d+)\.(\d+)\s*\+\+$'
  $null = Push-Location -Path $RepoPath
  try {
    $messages = git log -n 100 --pretty=%s 2>$null
  } catch {
    $messages = @()
  }
  finally {
    Pop-Location | Out-Null
  }

  $major = 0
  $minor = 0

  foreach ($msg in $messages) {
    $m = [regex]::Match($msg, $pattern)
    if ($m.Success) {
      $major = [int]$m.Groups[1].Value
      $minor = [int]$m.Groups[2].Value
      break
    }
  }
  # incrementa o minor e faz carry se quiser
  $minor++
  if ($minor -ge 100) { $minor = 0; $major++ }
  return "{0}.{1} ++" -f $major,$minor
}

function Test-GitAvailable {
  try { git --version 1>$null 2>$null; return $true } catch { return $false }
}

if (-not (Test-GitAvailable)) {
  Write-Host "Git não encontrado no PATH. Abortando." -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path -Path $RepoPath)) {
  Write-Host "RepoPath não existe: $RepoPath" -ForegroundColor Red
  exit 1
}

Push-Location -Path $RepoPath
try {
  # Atualiza README com Inputs do EA (se script existir)
  $gen = Join-Path $RepoPath 'docs\generate-docs.ps1'
  if (Test-Path $gen) {
    try { powershell -ExecutionPolicy Bypass -File $gen | Out-Host } catch { Write-Host "Falha ao gerar docs: $($_.Exception.Message)" -ForegroundColor Yellow }
  }

  # Bump automático será executado depois de detectar mudanças no repo

  # Verifica se há mudanças
  $status = git status --porcelain
  if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Sem alterações para commit." -ForegroundColor DarkGray
    exit 0
  }

  # Houve mudanças: atualiza versão do EA (PDC_VER e #property)
  $bump = Join-Path $RepoPath 'docs\bump-ea-version.ps1'
  if (Test-Path $bump) {
    try { powershell -ExecutionPolicy Bypass -File $bump -NoCommit | Out-Host } catch { Write-Host "Falha no bump de versão: $($_.Exception.Message)" -ForegroundColor Yellow }
  }

  # Stage de tudo (respeita .gitignore)
  git add -A

  # Monta mensagem com padrão MAJOR.MINOR ++
  $msg = Get-NextCommitVersion -RepoPath $RepoPath

  # Commit
  git commit -m $msg | Out-Host

  if ($Push.IsPresent) {
    $pushResult = $null
    $pushStatus = 'success'
    try {
      $pushResult = git push 2>&1 | Out-String
      Write-Host $pushResult
    } catch {
      $pushStatus = 'fail'
      $pushResult = $_.Exception.Message
      Write-Host "Falha no push (continuando): $pushResult" -ForegroundColor Yellow
    }
    # Notificação por e-mail
    $notifyScript = Join-Path $RepoPath 'notify-push-email.ps1'
    if (Test-Path $notifyScript) {
      & $notifyScript -Status $pushStatus -Details $pushResult # Configure SMTP no notify-push-email.ps1
    } else {
      Write-Host "notify-push-email.ps1 não encontrado para notificação." -ForegroundColor DarkGray
    }
  }
}
finally {
  Pop-Location | Out-Null
}