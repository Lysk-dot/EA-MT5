-- 📈 Análise de Volume e Liquidez
-- Analisa padrões de volume por símbolo e período

-- 1. Volume total por símbolo (últimas 24h)
SELECT 
    symbol,
    SUM(volume) as volume_total,
    AVG(volume) as volume_medio,
    COUNT(*) as num_candles
FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY volume_total DESC;

-- 2. Análise horária de volume (últimos 7 dias)
SELECT 
    DATE_TRUNC('hour', ts) as hora,
    symbol,
    SUM(volume) as volume_total,
    AVG(high - low) as spread_medio,
    COUNT(*) as candles
FROM market_data
WHERE ts > NOW() - INTERVAL '7 days'
GROUP BY hora, symbol
ORDER BY hora DESC, volume_total DESC
LIMIT 100;

-- 3. Volatilidade (range alto/baixo) por símbolo
SELECT 
    symbol,
    AVG(high - low) as range_medio,
    MAX(high - low) as range_maximo,
    MIN(high - low) as range_minimo,
    STDDEV(high - low) as volatilidade
FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY volatilidade DESC;

-- 4. Gaps de preço (diferença entre close e próximo open)
SELECT 
    a.symbol,
    a.ts as ts_anterior,
    b.ts as ts_proximo,
    a.close as close_anterior,
    b.open as open_proximo,
    ABS(b.open - a.close) as gap,
    CASE 
        WHEN b.open > a.close THEN 'GAP UP'
        WHEN b.open < a.close THEN 'GAP DOWN'
        ELSE 'SEM GAP'
    END as tipo_gap
FROM market_data a
INNER JOIN market_data b ON 
    a.symbol = b.symbol AND 
    b.ts = (SELECT MIN(ts) FROM market_data WHERE symbol = a.symbol AND ts > a.ts)
WHERE ABS(b.open - a.close) > 0.001
ORDER BY a.ts DESC
LIMIT 50;
