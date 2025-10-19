# Análise de Atividade do Mercado - Queries SQL

Este documento contém queries úteis para analisar quando o mercado estava ativo ou parado, usando a tabela `ingest_log`.

## 📊 Tabelas

### `ticks` (principal)
- Armazena dados únicos (dedupe via ON CONFLICT)
- Hypertable otimizado para time-series

### `ingest_log` (audit completo)
- Registra TODAS as tentativas de inserção
- Inclui flag `was_duplicate` para detectar mercado parado
- Contém `source_ip` e `user_agent` para debug

## 🔍 Queries Úteis

### 1. Ver atividade por hora (últimos 7 dias)
```sql
SELECT * FROM market_activity
WHERE symbol = 'EURUSD'
ORDER BY hour DESC
LIMIT 168;  -- 7 dias * 24 horas
```

### 2. Detectar períodos com mercado parado (>80% duplicatas)
```sql
SELECT 
  symbol,
  DATE_TRUNC('hour', received_at) as hour,
  COUNT(*) as total_attempts,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as dup_pct
FROM ingest_log
WHERE received_at > now() - interval '24 hours'
GROUP BY symbol, DATE_TRUNC('hour', received_at)
HAVING (100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*)) > 80
ORDER BY hour DESC;
```

### 3. Taxa de duplicatas por símbolo (últimas 24h)
```sql
SELECT 
  symbol,
  COUNT(*) as total,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_data,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as dup_rate
FROM ingest_log
WHERE received_at > now() - interval '24 hours'
GROUP BY symbol
ORDER BY dup_rate DESC;
```

### 4. Horários de maior atividade (menor taxa de duplicatas)
```sql
SELECT 
  EXTRACT(HOUR FROM received_at) as hour_of_day,
  COUNT(*) as attempts,
  SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_candles,
  ROUND(100.0 * SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as activity_pct
FROM ingest_log
WHERE received_at > now() - interval '7 days'
GROUP BY EXTRACT(HOUR FROM received_at)
ORDER BY activity_pct DESC;
```

### 5. Últimas tentativas (incluindo duplicatas)
```sql
SELECT 
  received_at,
  symbol,
  timeframe,
  open,
  high,
  low,
  close,
  volume,
  was_duplicate,
  source_ip
FROM ingest_log
ORDER BY received_at DESC
LIMIT 50;
```

### 6. Identificar gaps (períodos sem dados)
```sql
WITH hourly_buckets AS (
  SELECT 
    generate_series(
      date_trunc('hour', now() - interval '7 days'),
      date_trunc('hour', now()),
      interval '1 hour'
    ) as hour
),
data_by_hour AS (
  SELECT 
    date_trunc('hour', received_at) as hour,
    COUNT(*) as attempts
  FROM ingest_log
  WHERE symbol = 'EURUSD'
    AND received_at > now() - interval '7 days'
  GROUP BY date_trunc('hour', received_at)
)
SELECT 
  b.hour,
  COALESCE(d.attempts, 0) as attempts,
  CASE WHEN d.attempts IS NULL THEN 'GAP' ELSE 'OK' END as status
FROM hourly_buckets b
LEFT JOIN data_by_hour d ON b.hour = d.hour
WHERE COALESCE(d.attempts, 0) = 0
ORDER BY b.hour DESC;
```

### 7. Comparar taxa de duplicatas entre símbolos
```sql
SELECT 
  symbol,
  DATE_TRUNC('day', received_at) as day,
  COUNT(*) as total,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as dups,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as dup_pct
FROM ingest_log
WHERE received_at > now() - interval '30 days'
GROUP BY symbol, DATE_TRUNC('day', received_at)
ORDER BY day DESC, symbol;
```

### 8. Ver padrão semanal (fins de semana = mercado fechado)
```sql
SELECT 
  TO_CHAR(received_at, 'Day') as day_of_week,
  EXTRACT(DOW FROM received_at) as dow_num,
  COUNT(*) as attempts,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as dup_rate
FROM ingest_log
WHERE received_at > now() - interval '30 days'
GROUP BY TO_CHAR(received_at, 'Day'), EXTRACT(DOW FROM received_at)
ORDER BY dow_num;
```

### 9. Estatísticas de fonte (qual EA enviou)
```sql
SELECT 
  user_agent,
  source_ip,
  COUNT(*) as total_requests,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  MIN(received_at) as first_seen,
  MAX(received_at) as last_seen
FROM ingest_log
WHERE received_at > now() - interval '7 days'
GROUP BY user_agent, source_ip
ORDER BY total_requests DESC;
```

### 10. Detectar anomalias (súbita queda de dados novos)
```sql
WITH hourly_stats AS (
  SELECT 
    DATE_TRUNC('hour', received_at) as hour,
    COUNT(*) as total,
    SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_data
  FROM ingest_log
  WHERE received_at > now() - interval '48 hours'
    AND symbol = 'EURUSD'
  GROUP BY DATE_TRUNC('hour', received_at)
),
with_avg AS (
  SELECT 
    hour,
    new_data,
    AVG(new_data) OVER (ORDER BY hour ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as moving_avg
  FROM hourly_stats
)
SELECT 
  hour,
  new_data,
  ROUND(moving_avg::numeric, 2) as ma_7h,
  CASE 
    WHEN new_data < moving_avg * 0.5 THEN '⚠️  ANOMALIA'
    ELSE '✅ OK'
  END as status
FROM with_avg
ORDER BY hour DESC;
```

## 🎯 Para IA/ML

### Dataset para treinar modelo de atividade do mercado
```sql
-- Exportar dados para análise de IA
COPY (
  SELECT 
    symbol,
    EXTRACT(YEAR FROM received_at) as year,
    EXTRACT(MONTH FROM received_at) as month,
    EXTRACT(DAY FROM received_at) as day,
    EXTRACT(DOW FROM received_at) as day_of_week,
    EXTRACT(HOUR FROM received_at) as hour,
    COUNT(*) as attempts,
    SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
    SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_data,
    ROUND(AVG(open), 5) as avg_open,
    ROUND(AVG(close), 5) as avg_close,
    ROUND(AVG(volume), 2) as avg_volume
  FROM ingest_log
  WHERE received_at > now() - interval '90 days'
  GROUP BY 
    symbol,
    EXTRACT(YEAR FROM received_at),
    EXTRACT(MONTH FROM received_at),
    EXTRACT(DAY FROM received_at),
    EXTRACT(DOW FROM received_at),
    EXTRACT(HOUR FROM received_at)
  ORDER BY symbol, year, month, day, hour
) TO '/tmp/market_activity_dataset.csv' WITH CSV HEADER;
```

## 📈 Métricas para Dashboard

### KPIs principais
```sql
SELECT 
  -- Últimas 24 horas
  (SELECT COUNT(*) FROM ingest_log WHERE received_at > now() - interval '24 hours') as total_24h,
  (SELECT COUNT(*) FROM ingest_log WHERE received_at > now() - interval '24 hours' AND was_duplicate) as dups_24h,
  
  -- Taxa média de duplicatas
  ROUND(
    100.0 * (SELECT COUNT(*) FROM ingest_log WHERE received_at > now() - interval '24 hours' AND was_duplicate) /
    NULLIF((SELECT COUNT(*) FROM ingest_log WHERE received_at > now() - interval '24 hours'), 0),
    2
  ) as dup_rate_24h,
  
  -- Símbolos ativos
  (SELECT COUNT(DISTINCT symbol) FROM ingest_log WHERE received_at > now() - interval '1 hour') as active_symbols_1h;
```

## 🧹 Manutenção

### Limpar logs antigos (manter 90 dias)
```sql
DELETE FROM ingest_log
WHERE received_at < now() - interval '90 days';
```

### Recriar hypertable chunks
```sql
SELECT show_chunks('ingest_log');
SELECT drop_chunks('ingest_log', older_than => INTERVAL '90 days');
```
