-- Tests for Migration 002: Continuous Aggregates
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(6);

-- =============================================================================
-- 1. Continuous aggregates exist (shown as views in pgTAP)
-- =============================================================================

-- Note: has_materialized_view doesn't work with TimescaleDB continuous aggregates,
-- so we use has_view instead

SELECT has_view('cumsum', 'all_metrics_minute', 'cumsum.all_metrics_minute continuous aggregate exists');
SELECT has_view('geo', 'latest_coords', 'geo.latest_coords continuous aggregate exists');
SELECT has_view('internal', 'cagg_calculated_metric', 'internal.cagg_calculated_metric continuous aggregate exists');
SELECT has_view('internal', 'prometheus_mainnet_1m', 'internal.prometheus_mainnet_1m continuous aggregate exists');
SELECT has_view('internal', 'prometheus_testnet_1m', 'internal.prometheus_testnet_1m continuous aggregate exists');
SELECT has_view('internal', 'prometheus_common_1m', 'internal.prometheus_common_1m continuous aggregate exists');

SELECT * FROM finish();

COMMIT;
