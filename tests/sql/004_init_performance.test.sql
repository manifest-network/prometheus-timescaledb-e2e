-- Tests for Migration 004: Performance Optimizations (Indexes and Compression)
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

-- =============================================================================
-- 1. Indexes on continuous aggregates exist
-- =============================================================================
-- Note: TimescaleDB continuous aggregates store indexes on internal materialized
-- hypertables, so we query pg_indexes directly instead of using has_index().

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_cumsum_all_metrics_minute_name_schema_bucket'),
  'cumsum.all_metrics_minute has name_schema_bucket index'
);

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_cagg_calculated_metric_name_schema_bucket'),
  'internal.cagg_calculated_metric has name_schema_bucket index'
);

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_prometheus_mainnet_1m_name_bucket'),
  'internal.prometheus_mainnet_1m has name_bucket index'
);

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_prometheus_testnet_1m_name_bucket'),
  'internal.prometheus_testnet_1m has name_bucket index'
);

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_prometheus_common_1m_name_bucket'),
  'internal.prometheus_common_1m has name_bucket index'
);

SELECT ok(
  EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = 'idx_geo_latest_coords_bucket'),
  'geo.latest_coords has bucket index'
);

-- =============================================================================
-- 2. Compression is enabled on hypertables
-- =============================================================================

SELECT ok(
  EXISTS(
    SELECT 1 FROM timescaledb_information.compression_settings
    WHERE hypertable_schema = 'internal' AND hypertable_name = 'prometheus_remote_write'
  ),
  'compression is enabled on internal.prometheus_remote_write'
);

SELECT ok(
  EXISTS(
    SELECT 1 FROM timescaledb_information.compression_settings
    WHERE hypertable_schema = 'cumsum' AND hypertable_name = 'prometheus_remote_write'
  ),
  'compression is enabled on cumsum.prometheus_remote_write'
);

SELECT * FROM finish();

COMMIT;
