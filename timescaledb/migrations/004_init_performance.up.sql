BEGIN;

-- =============================================================================
-- Migration 004: Performance Optimizations (Indexes and Compression)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Indexes on continuous aggregates
-- -----------------------------------------------------------------------------

-- Index for cumsum aggregate (single host assumption, no tag_id needed)
CREATE INDEX IF NOT EXISTS idx_cumsum_all_metrics_minute_name_schema_bucket
ON cumsum.all_metrics_minute (name, schema, bucket DESC);

-- Index for calculated metrics aggregate
CREATE INDEX IF NOT EXISTS idx_cagg_calculated_metric_name_schema_bucket
ON internal.cagg_calculated_metric (name, schema, bucket DESC);

-- Index for mainnet aggregate
CREATE INDEX IF NOT EXISTS idx_prometheus_mainnet_1m_name_bucket
ON internal.prometheus_mainnet_1m (name, bucket DESC);

-- Index for testnet aggregate
CREATE INDEX IF NOT EXISTS idx_prometheus_testnet_1m_name_bucket
ON internal.prometheus_testnet_1m (name, bucket DESC);

-- Index for common aggregate
CREATE INDEX IF NOT EXISTS idx_prometheus_common_1m_name_bucket
ON internal.prometheus_common_1m (name, bucket DESC);

-- Index for geo coordinates aggregate
CREATE INDEX IF NOT EXISTS idx_geo_latest_coords_bucket
ON geo.latest_coords (bucket DESC);

-- -----------------------------------------------------------------------------
-- 2. Compression policies for hypertables
-- -----------------------------------------------------------------------------

-- Enable compression on internal.prometheus_remote_write
ALTER TABLE internal.prometheus_remote_write SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'name, schema',
  timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('internal.prometheus_remote_write', INTERVAL '7 days');

-- Enable compression on cumsum.prometheus_remote_write
ALTER TABLE cumsum.prometheus_remote_write SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'name, schema',
  timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('cumsum.prometheus_remote_write', INTERVAL '7 days');

COMMIT;
