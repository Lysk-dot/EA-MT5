param(
  [string]$EAPath = (Join-Path $PSScriptRoot 'EA\DataCollectorPRO.mq5'),
  [string]$MetaEditorPath,
  [switch]$FailOnError,
  [switch]$ShowLog
)

# Quick compile check for MT5 EA using MetaEditor
# Returns: 0 on success, non-zero on failures

function Get-MetaEditorPath {
  param([string]$Hint)
  if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }

  $common = @(
    (Join-Path $env:ProgramFiles 'MetaTrader 5\metaeditor64.exe'),
    (Join-Path $env:ProgramFiles 'MetaTrader5\metaeditor64.exe'),
    (Join-Path $env:ProgramFiles '(.*)MetaTrader*\metaeditor64.exe'),
    (Join-Path $env:ProgramFiles '(.*)\metaeditor64.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'MetaTrader 5\metaeditor.exe')
  )
  foreach ($p in $common) { if (Test-Path $p) { return (Resolve-Path $p).Path } }

  # Broad search (may take a bit)
  $candidates = @()
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $root) { continue }
    try {
      $candidates += Get-ChildItem -Path $root -Recurse -Filter 'metaeditor*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 3
    } catch {}
  }
  if ($candidates.Count -gt 0) { return $candidates[0].FullName }
  return $null
}

function Invoke-EACompile {
  param([string]$MetaEditor, [string]$Src)
  if (-not (Test-Path $Src)) { throw "EA não encontrado: $Src" }
  $log = Join-Path $env:TEMP ("mql5-compile-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".log")
  $procArgs = @(
    "/compile:`"$Src`"",
    "/log:`"$log`"",
    "/quiet"
  )
  Write-Host ("Compilando: {0}" -f $Src) -ForegroundColor Yellow
  Start-Process -FilePath $MetaEditor -ArgumentList $procArgs -Wait -NoNewWindow | Out-Null
  Start-Sleep -Milliseconds 300

  $ok = $false
  if (Test-Path $log) {
    $content = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if ($ShowLog) { Write-Host "==== LOG DE COMPILAÇÃO ====" -ForegroundColor DarkGray; Write-Host $content }
    # Heurística de sucesso: ausência de 'error' e/ou presença de '0 error' / 'successful'
    $hasErrorWord = ($content -match '(?i)\berror\b|cannot|failed')
    $hasSuccess = ($content -match '(?i)0\s+error|successful|compil')
    $ok = ($hasSuccess -and -not $hasErrorWord) -or ($hasSuccess -and ($content -notmatch '(?i)\berror\b'))
  } else {
    Write-Host "⚠️  Log de compilação não encontrado: $log" -ForegroundColor Yellow
  }
  return @{ Ok = $ok; LogPath = $log }
}

# Main
try {
  if (-not (Test-Path $EAPath)) { Write-Host "❌ Arquivo EA não encontrado: $EAPath" -ForegroundColor Red; exit 2 }
  $meta = Get-MetaEditorPath -Hint $MetaEditorPath
  if (-not $meta) { Write-Host "❌ MetaEditor não encontrado. Informe -MetaEditorPath ou instale o MT5/MetaEditor." -ForegroundColor Red; exit 1 }
  Write-Host ("MetaEditor: {0}" -f $meta) -ForegroundColor Gray

  $res = Invoke-EACompile -MetaEditor $meta -Src $EAPath
  if ($res.Ok) {
    Write-Host "✅ Compilação bem-sucedida" -ForegroundColor Green
    Write-Host ("Log: {0}" -f $res.LogPath) -ForegroundColor DarkGray
    exit 0
  } else {
    Write-Host "❌ Compilação falhou" -ForegroundColor Red
    Write-Host ("Log: {0}" -f $res.LogPath) -ForegroundColor DarkGray
    if ($FailOnError) { exit 3 } else { exit 0 }
  }
} catch {
  Write-Host "❌ Erro durante a compilação: $($_.Exception.Message)" -ForegroundColor Red
  if ($FailOnError) { exit 4 } else { exit 0 }
}