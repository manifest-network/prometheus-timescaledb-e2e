-- =============================================================================
-- Bulk Refresh Continuous Aggregates
-- =============================================================================
-- Run this script AFTER backfilling historical data to populate the continuous
-- aggregates in bulk. This is much faster than letting the policies process
-- minute-by-minute.
--
-- Usage:
--   docker exec -i timescaledb psql -U postgres -d metrics < timescaledb/scripts/bulk_refresh_aggregates.sql
--
-- When to run:
--   1. After initial historical data backfill (vmalert_backfill containers)
--   2. After restoring from backup
--   3. If aggregates get out of sync
-- =============================================================================

\echo '=== Bulk Refresh Continuous Aggregates ==='
\echo ''

\echo 'Refreshing cumsum.all_metrics_minute (this may take a while)...'
CALL refresh_continuous_aggregate('cumsum.all_metrics_minute', NULL, now());

\echo 'Refreshing internal.cagg_calculated_metric...'
CALL refresh_continuous_aggregate('internal.cagg_calculated_metric', NULL, now());

\echo 'Refreshing internal.prometheus_mainnet_1m...'
CALL refresh_continuous_aggregate('internal.prometheus_mainnet_1m', NULL, now());

\echo 'Refreshing internal.prometheus_testnet_1m...'
CALL refresh_continuous_aggregate('internal.prometheus_testnet_1m', NULL, now());

\echo 'Refreshing internal.prometheus_common_1m...'
CALL refresh_continuous_aggregate('internal.prometheus_common_1m', NULL, now());

\echo 'Refreshing geo.latest_coords...'
CALL refresh_continuous_aggregate('geo.latest_coords', NULL, now());

\echo ''
\echo '=== Done! All continuous aggregates have been refreshed. ==='
