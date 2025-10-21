<#
.SYNOPSIS
    Executa todos os testes automatizados do projeto EA-MT5
.DESCRIPTION
    Roda pytest nos testes de logging e métricas, mostrando o resultado completo.
#>

$ErrorActionPreference = "Stop"

Write-Host '╔════════════════════════════════════════╗'
Write-Host '║   EA-MT5 - Testes Automatizados      ║'
Write-Host '╚════════════════════════════════════════╝'

# Caminho do Python
$pythonExe = "C:/Program Files/Python312/python.exe"

# Verifica se pytest está instalado
$pytestInstalled = & $pythonExe -m pip show pytest 2>$null
if (-not $pytestInstalled) {
    Write-Host 'Instalando pytest...'
    & $pythonExe -m pip install pytest
}

# Executa os testes
Write-Host 'Executando testes com pytest...'
& $pythonExe -m pytest tests/test_structured_logging.py tests/test_prometheus_metrics.py

if ($LASTEXITCODE -eq 0) {
    Write-Host 'Todos os testes passaram!' -ForegroundColor Green
} else {
    Write-Host 'Alguns testes falharam. Verifique o log acima.' -ForegroundColor Red
}
