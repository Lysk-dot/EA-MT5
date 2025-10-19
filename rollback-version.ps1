param(
  [string]$TargetVersion,
  [switch]$Force,
  [string]$EAPath = (Join-Path $PSScriptRoot 'EA\DataCollectorPRO.mq5')
)

# Rollback de versão: reverte PDC_VER para versão anterior ou específica

$root = $PSScriptRoot
Set-Location $root

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rollback de Versão - EA DataCollectorPRO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar git status
Write-Host "[1/6] Verificando status do Git..." -ForegroundColor Yellow
$gitStatus = git status --porcelain
if ($gitStatus -and -not $Force) {
  Write-Host "❌ Há mudanças não commitadas. Commit ou use -Force para continuar." -ForegroundColor Red
  Write-Host "Mudanças pendentes:" -ForegroundColor Yellow
  git status --short | Out-Host
  exit 1
}
Write-Host "✅ Git status ok" -ForegroundColor Green
Write-Host ""

# 2. Listar versões disponíveis (tags)
Write-Host "[2/6] Listando versões disponíveis..." -ForegroundColor Yellow
$tags = git tag --sort=-version:refname | Select-Object -First 10
if ($tags.Count -eq 0) {
  Write-Host "⚠️  Nenhuma tag encontrada no repositório" -ForegroundColor Yellow
  Write-Host "Tentando usar histórico de commits..." -ForegroundColor Gray
} else {
  Write-Host "Últimas 10 versões (tags):" -ForegroundColor Gray
  $tags | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
}
Write-Host ""

# 3. Determinar versão atual
if (-not (Test-Path $EAPath)) { Write-Host "❌ EA não encontrado: $EAPath" -ForegroundColor Red; exit 2 }
$src = Get-Content $EAPath -Raw -Encoding UTF8
$currentVer = $null
if ($src -match '#define\s+PDC_VER\s+"([^"]+)"') { $currentVer = $Matches[1] }
if (-not $currentVer) { Write-Host "❌ PDC_VER não encontrado no EA" -ForegroundColor Red; exit 3 }
Write-Host "[3/6] Versão atual: $currentVer" -ForegroundColor Yellow
Write-Host ""

# 4. Determinar versão alvo
$targetVer = $TargetVersion
if (-not $targetVer) {
  # Tentar versão anterior via git log
  Write-Host "[4/6] Buscando versão anterior no histórico..." -ForegroundColor Yellow
  $commits = git log --all --oneline --grep="release:|bump" -20
  if ($commits) {
    Write-Host "Commits recentes de release/bump:" -ForegroundColor Gray
    $commits | Select-Object -First 5 | Out-Host
    
    # Tentar extrair versão do último commit de release
    $lastRelease = git log --all --oneline --grep="release:|bump" -1
    if ($lastRelease -match '\b(\d+\.\d+)\b') {
      $targetVer = $Matches[1]
      Write-Host ("Versão sugerida do histórico: {0}" -f $targetVer) -ForegroundColor Cyan
      $confirm = Read-Host "Usar versão $targetVer? (s/N)"
      if ($confirm -ne 's' -and $confirm -ne 'S') {
        $targetVer = Read-Host "Digite a versão alvo (ex: 1.64)"
      }
    }
  }
  
  if (-not $targetVer) {
    Write-Host "Digite a versão alvo para rollback (ex: 1.64):" -ForegroundColor Cyan
    $targetVer = Read-Host "Versão"
  }
}

if (-not $targetVer -or $targetVer -eq '') { Write-Host "❌ Versão alvo não especificada" -ForegroundColor Red; exit 4 }
Write-Host "✅ Versão alvo: $targetVer" -ForegroundColor Green
Write-Host ""

# 5. Confirmar rollback
Write-Host "[5/6] Confirmação de Rollback" -ForegroundColor Yellow
Write-Host ("  Versão atual:  {0}" -f $currentVer) -ForegroundColor White
Write-Host ("  Versão alvo:   {0}" -f $targetVer) -ForegroundColor White
if (-not $Force) {
  $confirm = Read-Host "Confirmar rollback? (s/N)"
  if ($confirm -ne 's' -and $confirm -ne 'S') {
    Write-Host "Rollback cancelado pelo usuário" -ForegroundColor Yellow
    exit 0
  }
}
Write-Host ""

# 6. Executar rollback
Write-Host "[6/6] Executando rollback..." -ForegroundColor Yellow

# Atualizar PDC_VER
$src = $src -replace '#define\s+PDC_VER\s+"[^"]+"', ('#define PDC_VER "{0}"' -f $targetVer)

# Atualizar #property version
if ($targetVer -match '^(\d+)\.(\d+)$') {
  $maj=[int]$Matches[1]; $min=[int]$Matches[2]
  $prop = ('{0}.{1}0' -f $maj,$min)
  $src = $src -replace '#property\s+version\s+"[^"]+"', ('#property version   "{0}"' -f $prop)
}

Set-Content -Path $EAPath -Value $src -Encoding UTF8
Write-Host "✅ Arquivo atualizado para versão $targetVer" -ForegroundColor Green

# Compilar (opcional)
$compileScript = Join-Path $root 'compile-ea.ps1'
if (Test-Path $compileScript) {
  Write-Host "Compilando versão $targetVer..." -ForegroundColor Gray
  try {
    $psArgs = @('-ExecutionPolicy','Bypass','-File', $compileScript, '-EAPath', $EAPath, '-FailOnError')
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -PassThru -Wait -NoNewWindow
    if ($p.ExitCode -eq 0) {
      Write-Host "✅ Compilação bem-sucedida" -ForegroundColor Green
    } else {
      Write-Host "⚠️  Falha na compilação (código: $($p.ExitCode))" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "⚠️  Erro ao compilar: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

# Commit rollback
Write-Host ""
Write-Host "Criando commit de rollback..." -ForegroundColor Gray
git add "$EAPath"
$msg = "rollback: reverter versão para $targetVer (de $currentVer)"
git commit -m $msg | Out-Host

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rollback concluído: $currentVer → $targetVer" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Cyan
Write-Host "  1. Verificar EA: .\verify-ea-data.ps1 -ExpectedPdcVer $targetVer" -ForegroundColor Gray
Write-Host "  2. Testar funcionamento no MT5" -ForegroundColor Gray
Write-Host "  3. Se ok, push: git push origin main" -ForegroundColor Gray
Write-Host "  4. Se erro, reverter: git reset --hard HEAD~1" -ForegroundColor Gray
