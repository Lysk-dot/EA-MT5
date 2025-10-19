# Sets up a basic pre-commit hook that runs compile and verify checks
param(
  [switch]$Overwrite,
  [string]$ExpectedPdcVer,
  [string]$MetaEditorPath
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$gitDir = Join-Path $root '.git'
$hookDir = Join-Path $gitDir 'hooks'
$hook = Join-Path $hookDir 'pre-commit'

if (-not (Test-Path $gitDir)) { Write-Host "❌ Não é um repositório Git: $root" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $hookDir)) { New-Item -ItemType Directory -Path $hookDir | Out-Null }
if ((Test-Path $hook) -and -not $Overwrite) { Write-Host "⚠️  pre-commit já existe. Use -Overwrite para substituir." -ForegroundColor Yellow; exit 0 }

$script = @'
#!/bin/sh
# Pre-commit: compile EA and verify health

POWERSHELL="powershell.exe -NoProfile -ExecutionPolicy Bypass"

$POWERSHELL -File "compile-ea.ps1" -FailOnError %(METAEDITOR)s || exit 1
$POWERSHELL -File "verify-ea-data.ps1" -RunCompileCheck -FailOnMismatch %(EXPECTED)s || exit 1
$POWERSHELL -File "repo-health.ps1" || exit 1

exit 0
'@

$expected = ''
if ($ExpectedPdcVer) { $expected = ("-ExpectedPdcVer {0}" -f $ExpectedPdcVer) }
$me = ''
if ($MetaEditorPath) { $me = ("-MetaEditorPath `"{0}`"" -f $MetaEditorPath) }

$script = $script.Replace('%(EXPECTED)s',$expected).Replace('%(METAEDITOR)s',$me)

Set-Content -Path $hook -Value $script -Encoding Ascii
# Make executable on Windows Git does not require chmod, but keeping for compatibility
Write-Host "✅ pre-commit configurado em $hook" -ForegroundColor Green
