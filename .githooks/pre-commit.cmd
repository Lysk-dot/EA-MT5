@echo off
setlocal enableextensions enabledelayedexpansion

REM Run PowerShell validator
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop';
  # Gather staged files
  $files = git diff --cached --name-only | Where-Object { $_ -ne $null -and $_ -ne '' }
  if (-not $files) { exit 0 }

  # Define patterns
  $patRegex = 'ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,120}'
  $maxSize = 5MB

  foreach ($f in $files) {
    if (-not (Test-Path $f)) { continue }
    $size = (Get-Item $f).Length
    if ($size -gt $maxSize) {
      Write-Host "[pre-commit] Large file blocked (>5MB): $f ($size bytes)" -ForegroundColor Red
      exit 1
    }
    $content = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
    if ($null -ne $content -and $content -match $patRegex) {
      Write-Host "[pre-commit] Detected GitHub token-like secret in: $f" -ForegroundColor Red
      Write-Host "Please remove secrets before committing." -ForegroundColor Yellow
      exit 1
    }
  }
}"
if errorlevel 1 exit /b 1
exit /b 0
