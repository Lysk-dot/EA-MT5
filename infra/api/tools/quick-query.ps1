# Script rapido para executar queries especificas do MT5-Trading-Analysis.sql
# Uso: .\quick-query.ps1 -Section <numero>
# Exemplo: .\quick-query.ps1 -Section 2  (executa query 2: Ultimos 20 registros)

param(
    [int]$Section = 2  # Query padrao: Ultimos 20 registros
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$runQueryScript = Join-Path $scriptPath "run-query.ps1"

# Mapear secoes para queries especificas
$queries = @{
    1 = "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = 'market_data' ORDER BY ordinal_position;"
    2 = "SELECT ts, symbol, timeframe, open, high, low, close, volume, tick_volume FROM market_data ORDER BY ts DESC LIMIT 20;"
    3 = "SELECT symbol, COUNT(*) as total_candles, MIN(ts) as primeiro_registro, MAX(ts) as ultimo_registro, SUM(volume) as volume_total, AVG(high - low) as range_medio, MAX(high) as max_high, MIN(low) as min_low FROM market_data WHERE ts > NOW() - INTERVAL '24 hours' GROUP BY symbol ORDER BY total_candles DESC;"
    4 = "SELECT ts, open, high, low, close, volume, tick_volume, (high - low) as range, (close - open) as movement, CASE WHEN close > open THEN 'BULL' WHEN close < open THEN 'BEAR' ELSE 'DOJI' END as candle_type FROM market_data WHERE symbol = 'EURUSD' ORDER BY ts DESC LIMIT 50;"
    5 = "SELECT symbol, SUM(volume) as volume_total, AVG(volume) as volume_medio, MAX(volume) as volume_maximo, COUNT(*) as num_candles, SUM(volume) / NULLIF(COUNT(*), 0) as volume_por_candle FROM market_data WHERE ts > NOW() - INTERVAL '24 hours' GROUP BY symbol ORDER BY volume_total DESC LIMIT 10;"
    6 = "SELECT symbol, AVG(high - low) as range_medio, MAX(high - low) as range_maximo, MIN(high - low) as range_minimo, STDDEV(high - low) as desvio_padrao, COUNT(*) as num_candles FROM market_data WHERE ts > NOW() - INTERVAL '24 hours' GROUP BY symbol ORDER BY desvio_padrao DESC;"
    7 = "SELECT DATE_TRUNC('minute', ts) as minuto, COUNT(*) as candles_recebidos, COUNT(DISTINCT symbol) as symbols_ativos, SUM(volume) as volume_total FROM market_data WHERE ts > NOW() - INTERVAL '1 hour' GROUP BY minuto ORDER BY minuto DESC LIMIT 60;"
    8 = "SELECT symbol, MAX(ts) as ultimo_dado, NOW() as timestamp_atual, EXTRACT(EPOCH FROM (NOW() - MAX(ts)))/60 as minutos_atras FROM market_data GROUP BY symbol ORDER BY minutos_atras ASC;"
    9 = "SELECT symbol, COUNT(*) as total_registros, SUM(CASE WHEN open IS NULL THEN 1 ELSE 0 END) as nulls_open, SUM(CASE WHEN high IS NULL THEN 1 ELSE 0 END) as nulls_high FROM market_data WHERE ts > NOW() - INTERVAL '24 hours' GROUP BY symbol ORDER BY symbol;"
    10 = "SELECT symbol, MIN(ts) as data_inicio, MAX(ts) as data_fim, COUNT(*) as total_registros FROM market_data GROUP BY symbol ORDER BY data_fim DESC;"
}

$sectionNames = @{
    1 = "Estrutura da Tabela"
    2 = "Ultimos 20 Registros"
    3 = "Resumo por Simbolo (24h)"
    4 = "Candles EURUSD (50)"
    5 = "Analise de Volume"
    6 = "Volatilidade por Simbolo"
    7 = "Taxa de Ingestao (1h)"
    8 = "Latencia de Dados"
    9 = "Qualidade dos Dados"
    10 = "Timeline Completa"
}

if (-not $queries.ContainsKey($Section)) {
    Write-Host "Secao invalida: $Section" -ForegroundColor Red
    Write-Host "`nSecoes disponiveis:" -ForegroundColor Yellow
    foreach ($key in $sectionNames.Keys | Sort-Object) {
        Write-Host "  $key - $($sectionNames[$key])" -ForegroundColor Cyan
    }
    Write-Host "`nUso: .\quick-query.ps1 -Section <numero>" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nExecutando Query: $($sectionNames[$Section])" -ForegroundColor Green
Write-Host "===============================================`n" -ForegroundColor Green

# Executar query
& $runQueryScript -Query $queries[$Section]
