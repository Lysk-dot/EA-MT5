param(
  [switch]$Fix,
  [int]$MaxEALineLen = 180
)

# Repo health checks: EOL normalization, trailing spaces, forbidden tabs (except .mq5 if needed), BOM, and stale paths

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$errors = 0
function Fail([string]$msg){ Write-Host "❌ $msg" -ForegroundColor Red; $script:errors++ }
function Warn([string]$msg){ Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Info([string]$msg){ Write-Host "ℹ️  $msg" -ForegroundColor Gray }

# 1) EOL normalization check
Info "Checando finais de linha (CRLF recomendado para Windows)"
$badEol = @()
Get-ChildItem -Recurse -File -Include *.md,*.ps1,*.psm1,*.yml,*.yaml,*.json,*.txt,*.mq5 | ForEach-Object {
  try {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text -match "\r\n") { return }
    if ($text -match "\n" -and $text -notmatch "\r\n") { $badEol += $_.FullName }
  } catch {}
}
if ($badEol.Count -gt 0){
  Warn ("Arquivos com LF puro: " + ($badEol.Count))
  if ($Fix) {
    foreach($f in $badEol){
      $t = Get-Content $f -Raw -Encoding UTF8
      $t = $t -replace "\r?\n", "`r`n"
      Set-Content -Path $f -Value $t -Encoding UTF8
      Info ("Normalizado CRLF: $f")
    }
  }
}

# 2) Trailing spaces
Info "Checando trailing spaces"
$trail = Select-String -Path (Get-ChildItem -Recurse -File -Include *.md,*.ps1,*.psm1,*.yml,*.yaml,*.json,*.mq5 | ForEach-Object { $_.FullName }) -Pattern "\s+$" -SimpleMatch -List -ErrorAction SilentlyContinue
if ($trail){ Warn "Há arquivos com trailing spaces" }

# 3) Tabs proibidas (permitir em .mq5 se já usa)
Info "Checando TABs indevidas"
$tabs = Select-String -Path (Get-ChildItem -Recurse -File -Include *.md,*.ps1,*.psm1,*.yml,*.yaml,*.json | ForEach-Object { $_.FullName }) -Pattern "\t" -SimpleMatch -List -ErrorAction SilentlyContinue
if ($tabs){ Warn "Há arquivos com TABs em textos/scripts" }

# 4) BOM em scripts
Info "Checando BOM em scripts PowerShell"
Get-ChildItem -Recurse -File -Include *.ps1,*.psm1 | ForEach-Object {
  $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Warn ("BOM detectado: " + $_.FullName)
    if ($Fix){
      $nbytes = $bytes[3..($bytes.Length-1)]
      [System.IO.File]::WriteAllBytes($_.FullName, $nbytes)
      Info ("Removido BOM: " + $_.FullName)
    }
  }
}

# 5) Linhas muito longas em .mq5 (padrão: 180)
Info "Checando comprimento de linhas em .mq5"
Get-ChildItem -Recurse -File -Include *.mq5 | ForEach-Object {
  $i=0
  Get-Content $_.FullName -Encoding UTF8 | ForEach-Object {
    $i++
    if ($_.Length -gt $MaxEALineLen) {
      Warn ("Linha longa ($($._.Length)) em $($_.FullName):$i")
    }
  }
}

# 6) Referências antigas de caminho
Info "Checando referências obsoletas (Data/ -> EA/)"
$legacy = Select-String -Path (Get-ChildItem -Recurse -File -Include *.md,*.ps1,*.psm1,*.mq5 | ForEach-Object { $_.FullName }) -Pattern "Data/DataCollectorPRO\.mq5|Data/Obsoleto|git add Data/\*\.mq5" -AllMatches -ErrorAction SilentlyContinue
if ($legacy){ Fail "Encontradas referências antigas a Data/ (ajuste para EA/)." }

# 7) Verificação de .gitignore e .gitattributes
Info "Checando .gitignore e .gitattributes"
if (-not (Test-Path (Join-Path $root '.gitattributes'))){
  Warn ".gitattributes ausente (recomendado para normalizar EOL)"
}

# 8) Sumarizar
if ($errors -gt 0){ Write-Host ("Resultado: {0} problemas críticos" -f $errors) -ForegroundColor Red; exit 1 }
Write-Host "Resultado: OK (sem problemas críticos)" -ForegroundColor Green; exit 0
