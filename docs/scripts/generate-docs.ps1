<#
  generate-docs.ps1
  - Gera automaticamente a seção de Inputs do README.md a partir das declarações input em DataCollectorPRO.mq5
  - Atualiza o trecho entre os marcadores: <!-- AUTO-INPUTS:START --> ... <!-- AUTO-INPUTS:END -->
  - Uso: powershell -ExecutionPolicy Bypass -File .\docs\generate-docs.ps1
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param()

# Resolve base dir robustamente
$__base = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($__base)) {
  $__base = Split-Path -Parent $MyInvocation.MyCommand.Path
}
 $EAPath = Join-Path $__base '..\EA\DataCollectorPRO.mq5'
$ReadmePath = Join-Path $__base '..\README.md'

if (-not (Test-Path $EAPath)) { Write-Host "EA não encontrado: $EAPath" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $ReadmePath)) { Write-Host "README não encontrado: $ReadmePath" -ForegroundColor Red; exit 1 }

$content = Get-Content $EAPath -Raw

# Captura grupos (input group "...") e inputs logo abaixo até nova group ou seção
$lines = $content -split "`n"
$groups = @()
$current = $null
for ($i=0; $i -lt $lines.Length; $i++) {
  $line = $lines[$i].Trim()
  if ($line -match '^input\s+group\s+"([^"]+)"') {
    if ($current) { $groups += $current }
    $current = [ordered]@{ name = $Matches[1]; inputs = @() }
    continue
  }
  # Captura linhas de input (exceto input group)
  if ($line -match '^input\s+(?!group\b)(.+?);\s*(?:\/\/.*)?$') {
    $decl = $Matches[1].Trim()
    if ($null -ne $current) { $current.inputs += $decl }
  }
}
if ($current) { $groups += $current }

# Monta markdown
$md = "## Inputs (gerado automaticamente)`n`n"
foreach ($g in $groups) {
  $md += "### $($g.name)`n"
  foreach ($inp in $g.inputs) {
    $md += "- $inp`n"
  }
  $md += "`n"
}

$readme = Get-Content $ReadmePath -Raw
$start = '<!-- AUTO-INPUTS:START -->'
$end = '<!-- AUTO-INPUTS:END -->'
if ($readme -notmatch [regex]::Escape($start)) {
  # Insere no final se marcadores não existirem
  $readme += "`n`n$start`n$md$end`n"
} else {
  $pattern = "(?s)" + [regex]::Escape($start) + ".*?" + [regex]::Escape($end)
  $replacement = "$start`n$md$end"
  $readme = [regex]::Replace($readme, $pattern, $replacement)
}

Set-Content -Path $ReadmePath -Value $readme -Encoding UTF8
Write-Host "README atualizado com inputs do EA." -ForegroundColor Green
