# Script para executar queries SQL contra o banco PostgreSQL
# Uso: .\run-query.ps1 -QueryFile "caminho\para\arquivo.sql"
# Ou: .\run-query.ps1 -Query "SELECT * FROM market_data LIMIT 10;"

param(
    [string]$QueryFile = "",
    [string]$Query = "",
    [string]$Host = "192.168.15.20",
    [int]$Port = 5432,
    [string]$Database = "mt5_trading",
    [string]$User = "trader",
    [string]$Password = "trader123",
    [int]$Limit = 100
)

# Cores para output
$SuccessColor = "Green"
$ErrorColor = "Red"
$InfoColor = "Cyan"
$HeaderColor = "Yellow"

Write-Host "`n🔍 Executando Query SQL contra MT5 Trading Database" -ForegroundColor $HeaderColor
Write-Host "================================================`n" -ForegroundColor $HeaderColor

# Ativar ambiente virtual se existir
$venvPath = Join-Path $PSScriptRoot "..\..\..\.venv\Scripts\Activate.ps1"
if (Test-Path $venvPath) {
    & $venvPath
    Write-Host "✅ Ambiente virtual ativado" -ForegroundColor $SuccessColor
}

# Determinar qual query executar
$sqlQuery = ""
if ($QueryFile -ne "") {
    if (Test-Path $QueryFile) {
        $sqlQuery = Get-Content $QueryFile -Raw
        Write-Host "📄 Arquivo: $QueryFile" -ForegroundColor $InfoColor
    } else {
        Write-Host "❌ Arquivo não encontrado: $QueryFile" -ForegroundColor $ErrorColor
        exit 1
    }
} elseif ($Query -ne "") {
    $sqlQuery = $Query
    Write-Host "📝 Query inline fornecida" -ForegroundColor $InfoColor
} else {
    # Query padrão: últimos dados
    $sqlQuery = @"
SELECT 
    ts,
    symbol,
    timeframe,
    open,
    high,
    low,
    close,
    volume,
    tick_volume
FROM market_data 
ORDER BY ts DESC 
LIMIT $Limit;
"@
    Write-Host "📊 Executando query padrão (últimos $Limit registros)" -ForegroundColor $InfoColor
}

Write-Host "🔌 Conectando: ${Host}:${Port}/${Database}" -ForegroundColor $InfoColor
Write-Host ""

# Criar script Python temporário para executar a query
$pythonScript = @"
import psycopg2
import sys
from tabulate import tabulate
from datetime import datetime

try:
    # Conectar ao banco
    conn = psycopg2.connect(
        host='$Host',
        port=$Port,
        dbname='$Database',
        user='$User',
        password='$Password',
        connect_timeout=10
    )
    cur = conn.cursor()
    
    # Executar query
    query = '''$($sqlQuery.Replace("'", "''"))'''
    cur.execute(query)
    
    # Pegar resultados
    rows = cur.fetchall()
    colnames = [desc[0] for desc in cur.description]
    
    if len(rows) == 0:
        print("⚠️  Nenhum resultado encontrado.")
    else:
        # Formatar resultados como tabela
        print(f"\n✅ {len(rows)} resultado(s) encontrado(s):\n")
        print(tabulate(rows, headers=colnames, tablefmt='psql', showindex=False))
        print(f"\n📊 Total de linhas: {len(rows)}")
    
    cur.close()
    conn.close()
    
except psycopg2.Error as e:
    print(f"❌ Erro PostgreSQL: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Erro: {e}")
    sys.exit(1)
"@

# Salvar script temporário
$tempScript = Join-Path $env:TEMP "query_temp.py"
$pythonScript | Out-File -FilePath $tempScript -Encoding UTF8

# Executar script Python
try {
    $pythonExe = "python"
    if (Test-Path ".venv\Scripts\python.exe") {
        $pythonExe = ".venv\Scripts\python.exe"
    }
    
    # Instalar tabulate se necessário
    & $pythonExe -m pip install --quiet tabulate psycopg2-binary 2>$null
    
    # Executar query
    & $pythonExe $tempScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Query executada com sucesso!" -ForegroundColor $SuccessColor
    } else {
        Write-Host "`n❌ Erro ao executar query (exit code: $LASTEXITCODE)" -ForegroundColor $ErrorColor
    }
} catch {
    Write-Host "❌ Erro ao executar Python: $_" -ForegroundColor $ErrorColor
} finally {
    # Limpar arquivo temporário
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}

Write-Host ""
