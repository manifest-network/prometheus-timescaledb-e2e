BEGIN;

-- Remove compression policies
SELECT remove_compression_policy('cumsum.prometheus_remote_write', if_exists => true);
SELECT remove_compression_policy('internal.prometheus_remote_write', if_exists => true);

-- Disable compression (note: requires decompressing all chunks first in practice)
ALTER TABLE cumsum.prometheus_remote_write SET (timescaledb.compress = false);
ALTER TABLE internal.prometheus_remote_write SET (timescaledb.compress = false);

-- Drop indexes on continuous aggregates
DROP INDEX IF EXISTS geo.idx_geo_latest_coords_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_common_1m_name_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_testnet_1m_name_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_mainnet_1m_name_bucket;
DROP INDEX IF EXISTS internal.idx_cagg_calculated_metric_name_schema_bucket;
DROP INDEX IF EXISTS cumsum.idx_cumsum_all_metrics_minute_name_schema_bucket;

COMMIT;
