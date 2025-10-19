<#
  bump-ea-version.ps1
  - Incrementa a versão do EA em +0.01 (PDC_VER e #property version)
  - Atualiza EA/DataCollectorPRO.mq5 diretamente
  - Opcional: faz commit com mensagem padrão
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
[CmdletBinding()]
param(
  [string]$EAPath = (Join-Path $PSScriptRoot '..\EA\DataCollectorPRO.mq5'),
  [switch]$NoCommit
)

function Get-NextMinor([string]$ver){
  # aceita X.Y
  if ($ver -match '^(\d+)\.(\d+)$') {
    $maj=[int]$Matches[1]; $min=[int]$Matches[2]; $min+=1; return "$maj.$min"
  }
  throw "Formato de versão inesperado: $ver"
}

if (-not (Test-Path $EAPath)) { throw "EA não encontrado: $EAPath" }
$src = Get-Content $EAPath -Raw -Encoding UTF8

# Extrai PDC_VER
$pdc = $null
if ($src -match '#define\s+PDC_VER\s+"([^"]+)"') { $pdc = $Matches[1] } else { throw "PDC_VER não encontrado" }
$newPdc = Get-NextMinor $pdc

# Atualiza PDC_VER
$src = $src -replace '#define\s+PDC_VER\s+"[^"]+"', ('#define PDC_VER "{0}"' -f $newPdc)

# Atualiza #property version "X.Y0" -> derivar de $newPdc
if ($newPdc -match '^(\d+)\.(\d+)$') {
  $maj=[int]$Matches[1]; $min=[int]$Matches[2]
  $prop = ('{0}.{1}0' -f $maj,$min)
  $src = $src -replace '#property\s+version\s+"[^"]+"', ('#property version   "{0}"' -f $prop)
}

Set-Content -Path $EAPath -Value $src -Encoding UTF8
Write-Host "Versão atualizada para $newPdc (PDC_VER)" -ForegroundColor Green

if (-not $NoCommit) {
  try {
    git add "$EAPath"
    git commit -m "auto: bump versão EA para $newPdc (PDC_VER e #property)" | Out-Host
  } catch {
    Write-Host "Falha ao commitar automaticamente: $_" -ForegroundColor Yellow
  }
}