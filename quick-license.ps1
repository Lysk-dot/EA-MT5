# Quick License Generator - Use este para gerar licença rapidamente

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gerador Rápido de Licença" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Pedir número da conta
$account = Read-Host "Digite o número da sua conta MT5"
if (-not $account -or $account -eq "") {
    Write-Host "❌ Número da conta não informado" -ForegroundColor Red
    exit 1
}

# Converter para número
try {
    $accountNum = [long]$account
} catch {
    Write-Host "❌ Número de conta inválido" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Gerando licença para conta: $accountNum" -ForegroundColor Yellow
Write-Host ""

# Executar gerador principal
$scriptPath = Join-Path $PSScriptRoot "scripts/generate-license.ps1"
if (Test-Path $scriptPath) {
    & $scriptPath -AccountNumber $accountNum -ExpirationDays 3650
} else {
    Write-Host "❌ Script generate-license.ps1 não encontrado" -ForegroundColor Red
}
