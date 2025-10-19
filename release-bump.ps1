param(
  [string]$EAPath = (Join-Path $PSScriptRoot 'EA\DataCollectorPRO.mq5'),
  [switch]$CreateTag,
  [switch]$SkipCommit,
  [string]$MetaEditorPath
)

# Release bump: incrementa PDC_VER, compila, verifica, opcionalmente cria tag e changelog

$root = $PSScriptRoot
Set-Location $root

function Get-NextMinor([string]$ver){
  if ($ver -match '^(\d+)\.(\d+)$') {
    $maj=[int]$Matches[1]; $min=[int]$Matches[2]; $min+=1; return "$maj.$min"
  }
  throw "Formato de versão inesperado: $ver"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Release Bump - EA DataCollectorPRO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Bump version
Write-Host "[1/5] Incrementando versão..." -ForegroundColor Yellow
if (-not (Test-Path $EAPath)) { Write-Host "❌ EA não encontrado: $EAPath" -ForegroundColor Red; exit 1 }
$src = Get-Content $EAPath -Raw -Encoding UTF8
$pdcVer = $null
if ($src -match '#define\s+PDC_VER\s+"([^"]+)"') { $pdcVer = $Matches[1] } else { Write-Host "❌ PDC_VER não encontrado" -ForegroundColor Red; exit 1 }
$newVer = Get-NextMinor $pdcVer
Write-Host ("   Versão atual: {0} → Nova versão: {1}" -f $pdcVer, $newVer) -ForegroundColor Gray

$src = $src -replace '#define\s+PDC_VER\s+"[^"]+"', ('#define PDC_VER "{0}"' -f $newVer)
if ($newVer -match '^(\d+)\.(\d+)$') {
  $maj=[int]$Matches[1]; $min=[int]$Matches[2]
  $prop = ('{0}.{1}0' -f $maj,$min)
  $src = $src -replace '#property\s+version\s+"[^"]+"', ('#property version   "{0}"' -f $prop)
}
Set-Content -Path $EAPath -Value $src -Encoding UTF8
Write-Host "✅ Versão atualizada para $newVer" -ForegroundColor Green
Write-Host ""

# 2. Compile
Write-Host "[2/5] Compilando EA..." -ForegroundColor Yellow
$compileScript = Join-Path $root 'compile-ea.ps1'
if (-not (Test-Path $compileScript)) { Write-Host "❌ compile-ea.ps1 não encontrado" -ForegroundColor Red; exit 1 }
$psArgs = @('-ExecutionPolicy','Bypass','-File', $compileScript, '-EAPath', $EAPath, '-FailOnError', '-ShowLog')
if ($MetaEditorPath) { $psArgs += @('-MetaEditorPath', $MetaEditorPath) }
$p = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -PassThru -Wait -NoNewWindow
if ($p.ExitCode -ne 0) { Write-Host "❌ Falha na compilação" -ForegroundColor Red; exit 2 }
Write-Host "✅ Compilação bem-sucedida" -ForegroundColor Green
Write-Host ""

# 3. Verify
Write-Host "[3/5] Verificando saúde..." -ForegroundColor Yellow
$verifyScript = Join-Path $root 'verify-ea-data.ps1'
$healthScript = Join-Path $root 'repo-health.ps1'
if (Test-Path $verifyScript) {
  $psArgs = @('-ExecutionPolicy','Bypass','-File', $verifyScript, '-ExpectedPdcVer', $newVer)
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -PassThru -Wait -NoNewWindow
  if ($p.ExitCode -ne 0) { Write-Host "⚠️  Falha no verify (continuando)" -ForegroundColor Yellow }
}
if (Test-Path $healthScript) {
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy','Bypass','-File', $healthScript) -PassThru -Wait -NoNewWindow
  if ($p.ExitCode -ne 0) { Write-Host "⚠️  Falha no repo-health (continuando)" -ForegroundColor Yellow }
}
Write-Host "✅ Checks concluídos" -ForegroundColor Green
Write-Host ""

# 4. Commit
if (-not $SkipCommit) {
  Write-Host "[4/5] Criando commit de release..." -ForegroundColor Yellow
  git add -A
  $msg = "release: bump versão para $newVer (PDC_VER e #property)"
  git commit -m $msg | Out-Host
  Write-Host "✅ Commit criado" -ForegroundColor Green
  Write-Host ""
} else {
  Write-Host "[4/5] Commit pulado (-SkipCommit)" -ForegroundColor Gray
  Write-Host ""
}

# 5. Tag (opcional)
if ($CreateTag) {
  Write-Host "[5/5] Criando tag v$newVer..." -ForegroundColor Yellow
  $tagMsg = "Release $newVer - DataCollectorPRO EA"
  git tag -a "v$newVer" -m $tagMsg | Out-Host
  Write-Host "✅ Tag v$newVer criada" -ForegroundColor Green
  Write-Host ""
  Write-Host "Para enviar ao remote:" -ForegroundColor Cyan
  Write-Host "  git push origin main --tags" -ForegroundColor Gray
} else {
  Write-Host "[5/5] Tag não solicitada (use -CreateTag)" -ForegroundColor Gray
  Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Release bump concluído: v$newVer" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
