-- 🔍 Monitoramento de Pipeline
-- Verifica saúde e latência do pipeline de dados

-- 1. Taxa de ingestão (candles por minuto, última hora)
SELECT 
    DATE_TRUNC('minute', ts) as minuto,
    COUNT(*) as candles_recebidos,
    COUNT(DISTINCT symbol) as symbols_ativos
FROM market_data
WHERE ts > NOW() - INTERVAL '1 hour'
GROUP BY minuto
ORDER BY minuto DESC
LIMIT 60;

-- 2. Latência de dados (diferença entre timestamp do dado e timestamp de inserção)
-- Assumindo que existe coluna created_at ou similar
SELECT 
    symbol,
    MAX(ts) as ultimo_dado,
    NOW() as agora,
    EXTRACT(EPOCH FROM (NOW() - MAX(ts)))/60 as minutos_atras
FROM market_data
GROUP BY symbol
ORDER BY minutos_atras ASC;

-- 3. Símbolos sem dados recentes (últimas 2 horas)
SELECT DISTINCT symbol
FROM market_data
WHERE symbol NOT IN (
    SELECT DISTINCT symbol 
    FROM market_data 
    WHERE ts > NOW() - INTERVAL '2 hours'
)
ORDER BY symbol;

-- 4. Qualidade dos dados (verificar NULL e valores anômalos)
SELECT 
    symbol,
    COUNT(*) as total_registros,
    SUM(CASE WHEN open IS NULL THEN 1 ELSE 0 END) as nulls_open,
    SUM(CASE WHEN high IS NULL THEN 1 ELSE 0 END) as nulls_high,
    SUM(CASE WHEN low IS NULL THEN 1 ELSE 0 END) as nulls_low,
    SUM(CASE WHEN close IS NULL THEN 1 ELSE 0 END) as nulls_close,
    SUM(CASE WHEN volume IS NULL OR volume = 0 THEN 1 ELSE 0 END) as volume_zero,
    SUM(CASE WHEN high < low THEN 1 ELSE 0 END) as high_menor_low,
    SUM(CASE WHEN open > high OR open < low THEN 1 ELSE 0 END) as open_fora_range,
    SUM(CASE WHEN close > high OR close < low THEN 1 ELSE 0 END) as close_fora_range
FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY symbol;
