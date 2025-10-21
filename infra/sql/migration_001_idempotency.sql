-- Migration: Add strong idempotency with deduplication key
-- Execution: psql -U trader -d mt5_trading -f infra/sql/migration_001_idempotency.sql

-- ===============================================
-- 1. Add unique constraint for OHLCV data
-- ===============================================
-- Chave de deduplicação: (symbol, timeframe, ts_ms)
-- Previne duplicatas mesmo se enviadas em batches diferentes

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'ticks_dedupe_key'
    ) THEN
        ALTER TABLE ticks 
        ADD CONSTRAINT ticks_dedupe_key 
        UNIQUE (symbol, timeframe, ts_ms);
        
        RAISE NOTICE 'Added unique constraint: ticks_dedupe_key';
    ELSE
        RAISE NOTICE 'Constraint ticks_dedupe_key already exists';
    END IF;
END $$;

-- ===============================================
-- 2. Create table for tick data (separate from OHLCV)
-- ===============================================
CREATE TABLE IF NOT EXISTS raw_ticks (
  id BIGSERIAL,
  symbol TEXT NOT NULL,
  time_msc BIGINT NOT NULL,
  ts TIMESTAMPTZ GENERATED ALWAYS AS (to_timestamp(time_msc/1000.0)) STORED,
  bid DOUBLE PRECISION NOT NULL,
  ask DOUBLE PRECISION NOT NULL,
  last DOUBLE PRECISION,
  volume BIGINT DEFAULT 0,
  flags INT DEFAULT 0,
  source TEXT DEFAULT 'MT5',
  ea_version TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (symbol, time_msc)
);

-- Convert to hypertable for time-series optimization
SELECT create_hypertable('raw_ticks', by_range('ts'), if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_raw_ticks_ts ON raw_ticks(ts DESC);
CREATE INDEX IF NOT EXISTS idx_raw_ticks_symbol_ts ON raw_ticks(symbol, ts DESC);

-- ===============================================
-- 3. Add duplicate counter table
-- ===============================================
-- Track duplicate attempts for monitoring and alerts
CREATE TABLE IF NOT EXISTS duplicate_stats (
  id BIGSERIAL PRIMARY KEY,
  endpoint TEXT NOT NULL, -- '/ingest' or '/ingest/tick'
  symbol TEXT NOT NULL,
  timeframe TEXT, -- NULL for ticks
  hour_bucket TIMESTAMPTZ NOT NULL,
  duplicate_count INT NOT NULL DEFAULT 0,
  last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(endpoint, symbol, timeframe, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_duplicate_stats_hour 
  ON duplicate_stats(hour_bucket DESC);
CREATE INDEX IF NOT EXISTS idx_duplicate_stats_symbol 
  ON duplicate_stats(symbol, hour_bucket DESC);

-- ===============================================
-- 4. Function to increment duplicate counter
-- ===============================================
CREATE OR REPLACE FUNCTION increment_duplicate_stat(
  p_endpoint TEXT,
  p_symbol TEXT,
  p_timeframe TEXT,
  p_ts TIMESTAMPTZ
) RETURNS VOID AS $$
DECLARE
  v_hour_bucket TIMESTAMPTZ;
BEGIN
  v_hour_bucket := date_trunc('hour', p_ts);
  
  INSERT INTO duplicate_stats (
    endpoint, symbol, timeframe, hour_bucket, duplicate_count, last_seen
  ) VALUES (
    p_endpoint, p_symbol, p_timeframe, v_hour_bucket, 1, now()
  )
  ON CONFLICT (endpoint, symbol, timeframe, hour_bucket) 
  DO UPDATE SET 
    duplicate_count = duplicate_stats.duplicate_count + 1,
    last_seen = now();
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 5. View for duplicate monitoring
-- ===============================================
CREATE OR REPLACE VIEW duplicate_monitoring AS
SELECT 
  endpoint,
  symbol,
  timeframe,
  hour_bucket,
  duplicate_count,
  last_seen,
  CASE 
    WHEN duplicate_count > 1000 THEN 'HIGH'
    WHEN duplicate_count > 100 THEN 'MEDIUM'
    ELSE 'LOW'
  END as severity
FROM duplicate_stats
WHERE hour_bucket > now() - interval '24 hours'
ORDER BY hour_bucket DESC, duplicate_count DESC;

-- ===============================================
-- 6. Add metadata columns to existing tables
-- ===============================================
-- Add columns for better observability
ALTER TABLE ticks ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'MT5';
ALTER TABLE ticks ADD COLUMN IF NOT EXISTS ea_version TEXT;
ALTER TABLE ticks ADD COLUMN IF NOT EXISTS collection_mode TEXT;
ALTER TABLE ticks ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ DEFAULT now();

-- ===============================================
-- 7. Create materialized view for quick stats
-- ===============================================
CREATE MATERIALIZED VIEW IF NOT EXISTS idempotency_stats AS
SELECT 
  DATE_TRUNC('hour', received_at) as hour,
  COUNT(*) as total_requests,
  SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END) as duplicates,
  SUM(CASE WHEN NOT was_duplicate THEN 1 ELSE 0 END) as new_records,
  ROUND(100.0 * SUM(CASE WHEN was_duplicate THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)::NUMERIC, 2) as duplicate_rate_pct
FROM ingest_log
WHERE received_at > now() - interval '7 days'
GROUP BY DATE_TRUNC('hour', received_at)
ORDER BY hour DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_idempotency_stats_hour 
  ON idempotency_stats(hour);

-- Refresh materialized view function
CREATE OR REPLACE FUNCTION refresh_idempotency_stats() 
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY idempotency_stats;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 8. Cleanup old duplicate stats (retention policy)
-- ===============================================
-- Keep only last 30 days of duplicate stats
CREATE OR REPLACE FUNCTION cleanup_duplicate_stats() 
RETURNS void AS $$
BEGIN
  DELETE FROM duplicate_stats 
  WHERE hour_bucket < now() - interval '30 days';
  
  DELETE FROM ingest_log 
  WHERE received_at < now() - interval '30 days';
  
  RAISE NOTICE 'Cleaned up old duplicate stats and ingest logs';
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 9. Grant permissions
-- ===============================================
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE raw_ticks TO trader;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE duplicate_stats TO trader;
GRANT SELECT ON duplicate_monitoring TO trader;
GRANT SELECT ON idempotency_stats TO trader;
GRANT USAGE, SELECT ON SEQUENCE raw_ticks_id_seq TO trader;
GRANT USAGE, SELECT ON SEQUENCE duplicate_stats_id_seq TO trader;

-- ===============================================
-- Success message
-- ===============================================
DO $$ 
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE 'Added:';
  RAISE NOTICE '  - Unique constraint on ticks (symbol, timeframe, ts_ms)';
  RAISE NOTICE '  - raw_ticks table for tick data';
  RAISE NOTICE '  - duplicate_stats table for monitoring';
  RAISE NOTICE '  - Views: duplicate_monitoring, idempotency_stats';
  RAISE NOTICE '  - Functions: increment_duplicate_stat, cleanup_duplicate_stats';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '  1. Update API to use ON CONFLICT DO NOTHING';
  RAISE NOTICE '  2. Call increment_duplicate_stat() on 409 responses';
  RAISE NOTICE '  3. Setup cron job to run cleanup_duplicate_stats() daily';
  RAISE NOTICE '  4. Setup cron job to refresh_idempotency_stats() hourly';
  RAISE NOTICE '====================================================';
END $$;
