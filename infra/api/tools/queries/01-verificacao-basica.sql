-- 📊 Verificação Básica - MT5 Trading Database
-- Execute este arquivo para verificar o estado geral do banco

-- 1. Ver estrutura da tabela market_data
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'market_data'
ORDER BY ordinal_position;

-- 2. Últimos 10 registros
SELECT * FROM market_data 
ORDER BY ts DESC 
LIMIT 10;

-- 3. Contagem por símbolo
SELECT 
    symbol, 
    COUNT(*) as total_candles,
    MIN(ts) as primeiro_tick,
    MAX(ts) as ultimo_tick,
    MAX(ts) - MIN(ts) as periodo
FROM market_data
GROUP BY symbol
ORDER BY total_candles DESC;

-- 4. Registros nas últimas 24h
SELECT 
    symbol,
    COUNT(*) as candles_24h,
    MAX(ts) as ultimo_tick
FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY candles_24h DESC;
