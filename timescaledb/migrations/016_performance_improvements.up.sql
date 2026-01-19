BEGIN;

-- =============================================================================
-- Migration 016: Performance Improvements
-- =============================================================================
-- This migration adds:
-- 1. Indexes on continuous aggregates for faster lookups
-- 2. Compression policies on hypertables to reduce storage
-- 3. Optimized FDV and Market Cap functions (single scan instead of double)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Add indexes to continuous aggregates
-- -----------------------------------------------------------------------------

-- Index for cumsum.all_metrics_minute - used heavily by cumsum functions
CREATE INDEX IF NOT EXISTS idx_cumsum_minute_name_schema_bucket
ON cumsum.all_metrics_minute (name, schema, bucket DESC);

-- Index for internal.cagg_calculated_metric - used by tokenomics functions
CREATE INDEX IF NOT EXISTS idx_cagg_calculated_name_schema_bucket
ON internal.cagg_calculated_metric (name, schema, bucket DESC);

-- Index for geo.latest_coords - used by geo functions
CREATE INDEX IF NOT EXISTS idx_geo_coords_bucket
ON geo.latest_coords (bucket DESC);

-- Index for mainnet/testnet/common 1m aggregates (from migration 014)
CREATE INDEX IF NOT EXISTS idx_prometheus_mainnet_1m_name_bucket
ON internal.prometheus_mainnet_1m (name, bucket DESC);

CREATE INDEX IF NOT EXISTS idx_prometheus_testnet_1m_name_bucket
ON internal.prometheus_testnet_1m (name, bucket DESC);

CREATE INDEX IF NOT EXISTS idx_prometheus_common_1m_name_bucket
ON internal.prometheus_common_1m (name, bucket DESC);

-- -----------------------------------------------------------------------------
-- 2. Enable compression on hypertables
-- -----------------------------------------------------------------------------

-- Compression for internal.prometheus_remote_write
ALTER TABLE internal.prometheus_remote_write SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_segmentby = 'schema, name'
);

SELECT add_compression_policy('internal.prometheus_remote_write', INTERVAL '7 days');

-- Compression for cumsum.prometheus_remote_write
ALTER TABLE cumsum.prometheus_remote_write SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_segmentby = 'schema, name'
);

SELECT add_compression_policy('cumsum.prometheus_remote_write', INTERVAL '7 days');

-- -----------------------------------------------------------------------------
-- 3. Optimize FDV function - single scan instead of two subqueries
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_fdv(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        (
            COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN value::NUMERIC END), 0) *
            COALESCE(MAX(CASE WHEN name = 'talib_mfx_power_conversion' THEN value::NUMERIC END), 0)
        )::TEXT AS "value"
    FROM internal.cagg_calculated_metric
    WHERE (
        (schema = p_schema AND name = 'manifest_tokenomics_total_supply')
        OR name = 'talib_mfx_power_conversion'
    )
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY time_bucket(p_interval, bucket)
    -- Only return buckets where total_supply exists (matches original LEFT JOIN behavior)
    HAVING MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN 1 END) IS NOT NULL
    ORDER BY "timestamp" DESC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

-- -----------------------------------------------------------------------------
-- 4. Optimize Market Cap function - single scan instead of two subqueries
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_market_cap(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        ((
            COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_excluded_supply' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_tokens' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_fees' AND schema = p_schema THEN value::NUMERIC END), 0)
        ) * COALESCE(MAX(CASE WHEN name = 'talib_mfx_power_conversion' THEN value::NUMERIC END), 0))::TEXT AS "value"
    FROM internal.cagg_calculated_metric
    WHERE (
        (schema = p_schema AND name IN (
            'manifest_tokenomics_total_supply',
            'manifest_tokenomics_excluded_supply',
            'locked_tokens',
            'locked_fees'
        ))
        OR name = 'talib_mfx_power_conversion'
    )
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY time_bucket(p_interval, bucket)
    -- Only return buckets where total_supply exists (matches original LEFT JOIN behavior)
    HAVING MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN 1 END) IS NOT NULL
    ORDER BY "timestamp" ASC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

COMMIT;
