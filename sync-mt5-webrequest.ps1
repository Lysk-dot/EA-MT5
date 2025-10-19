<#
  sync-mt5-webrequest.ps1
  - Garante que o domínio da API está na whitelist do WebRequest do MT5.
  - Pode ser rodado manualmente ou agendado.
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param(
  [string]$TerminalIni = "$env:APPDATA\MetaQuotes\Terminal\D36DE9E413048DE15F2CEE9B72F26E48\terminal.ini",
  [string]$ApiUrl = 'https://sua.api.com',
  [switch]$DryRun
)

if (-not (Test-Path $TerminalIni)) {
  Write-Host "Arquivo terminal.ini não encontrado: $TerminalIni" -ForegroundColor Red
  exit 1
}

$content = Get-Content $TerminalIni -Raw
$section = '[WebRequest]'
$pattern = "(?ms)^\[WebRequest\](.*?)^(\[|$)"
$found = $false

if ($content -match $pattern) {
  $block = $matches[1]
  if ($block -match [regex]::Escape($ApiUrl)) {
    Write-Host "Domínio já está na whitelist." -ForegroundColor Green
    $found = $true
  } else {
    $newBlock = $block.TrimEnd() + "`n$ApiUrl`n"
    $content = $content -replace $pattern, "[WebRequest]`r`n$newBlock`r`n$2"
    Write-Host "Domínio adicionado à whitelist." -ForegroundColor Yellow
  }
} else {
  $content += "`r`n[WebRequest]`r`n$ApiUrl`r`n"
  Write-Host "Seção [WebRequest] criada e domínio adicionado." -ForegroundColor Yellow
}

if (-not $DryRun) {
  Set-Content $TerminalIni -Value $content -Encoding UTF8
  Write-Host "terminal.ini atualizado. Reinicie o MT5 para aplicar." -ForegroundColor Cyan
} else {
  Write-Host "DryRun: Nenhuma alteração feita." -ForegroundColor DarkGray
}
