CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Usamos ts_ms (epoch ms) e uma coluna gerada ts (timestamptz) para hypertable
CREATE TABLE IF NOT EXISTS ticks (
  symbol TEXT NOT NULL,
  ts_ms BIGINT NOT NULL,
  ts TIMESTAMPTZ GENERATED ALWAYS AS (to_timestamp(ts_ms/1000.0)) STORED,
  timeframe TEXT,
  open DOUBLE PRECISION,
  high DOUBLE PRECISION,
  low DOUBLE PRECISION,
  close DOUBLE PRECISION,
  volume DOUBLE PRECISION,
  kind TEXT,
  meta JSONB,
  PRIMARY KEY (symbol, ts_ms)
);

SELECT create_hypertable('ticks', by_range('ts'), if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_ticks_ts ON ticks(ts DESC);
CREATE INDEX IF NOT EXISTS idx_ticks_symbol_ts ON ticks(symbol, ts DESC);

-- Audit de forward para servidor Linux
CREATE TABLE IF NOT EXISTS forward_audit (
  symbol TEXT NOT NULL,
  ts_ms BIGINT NOT NULL,
  endpoint TEXT NOT NULL, -- '/ingest' ou '/ingest/tick'
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'sent', -- 'sent' | 'confirmed' | 'error'
  confirm_at TIMESTAMPTZ,
  last_status_code INT,
  PRIMARY KEY(symbol, ts_ms, endpoint)
);
CREATE INDEX IF NOT EXISTS idx_forward_audit_status ON forward_audit(status);
CREATE INDEX IF NOT EXISTS idx_forward_audit_sent_at ON forward_audit(sent_at DESC);

-- Log de todas as tentativas de ingestão (incluindo duplicatas)
-- Útil para detectar quando mercado está parado (muitas duplicatas)
CREATE TABLE IF NOT EXISTS ingest_log (
  id BIGSERIAL PRIMARY KEY,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  symbol TEXT NOT NULL,
  ts_ms BIGINT NOT NULL,
  timeframe TEXT,
  open DOUBLE PRECISION,
  high DOUBLE PRECISION,
  low DOUBLE PRECISION,
  close DOUBLE PRECISION,
  volume DOUBLE PRECISION,
  kind TEXT,
  was_duplicate BOOLEAN NOT NULL DEFAULT false,
  source_ip TEXT,
  user_agent TEXT
);

-- Converter para hypertable para performance com muitos dados
SELECT create_hypertable('ingest_log', by_range('received_at'), if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_ingest_log_symbol ON ingest_log(symbol, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_ingest_log_duplicate ON ingest_log(was_duplicate, received_at DESC);

-- View para análise de atividade do mercado
CREATE OR REPLACE VIEW market_activity AS
SELECT 
  symbol,
  DATE_TRUNC('hour', received_at) as hour,
  COUNT(*) as total_attempts,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_data,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) / COUNT(*), 2) as duplicate_rate_pct
FROM ingest_log
WHERE received_at > now() - interval '7 days'
GROUP BY symbol, DATE_TRUNC('hour', received_at)
ORDER BY hour DESC, symbol;
