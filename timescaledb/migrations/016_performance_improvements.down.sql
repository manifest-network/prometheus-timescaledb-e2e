BEGIN;

-- =============================================================================
-- Migration 016 Rollback: Remove Performance Improvements
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Remove compression policies and disable compression
-- -----------------------------------------------------------------------------

SELECT remove_compression_policy('internal.prometheus_remote_write', if_exists => true);
SELECT remove_compression_policy('cumsum.prometheus_remote_write', if_exists => true);

ALTER TABLE internal.prometheus_remote_write SET (timescaledb.compress = false);
ALTER TABLE cumsum.prometheus_remote_write SET (timescaledb.compress = false);

-- -----------------------------------------------------------------------------
-- 2. Remove indexes from continuous aggregates
-- -----------------------------------------------------------------------------

DROP INDEX IF EXISTS cumsum.idx_cumsum_minute_name_schema_tag_bucket;
DROP INDEX IF EXISTS internal.idx_cagg_calculated_name_schema_bucket;
DROP INDEX IF EXISTS geo.idx_geo_coords_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_mainnet_1m_name_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_testnet_1m_name_bucket;
DROP INDEX IF EXISTS internal.idx_prometheus_common_1m_name_bucket;

-- -----------------------------------------------------------------------------
-- 3. Restore original FDV function (two subqueries)
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
        ts.bucket AS "timestamp",
        (COALESCE(ts.total_supply, 0) * COALESCE(pc.power_conversion, 0))::TEXT AS "value"
    FROM (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(value::NUMERIC) AS total_supply
        FROM internal.cagg_calculated_metric
        WHERE schema = p_schema
          AND name = 'manifest_tokenomics_total_supply'
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY time_bucket(p_interval, bucket)
    ) ts
    LEFT JOIN (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(value::NUMERIC) AS power_conversion
        FROM internal.cagg_calculated_metric
        WHERE name = 'talib_mfx_power_conversion'
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY time_bucket(p_interval, bucket)
    ) pc ON ts.bucket = pc.bucket
    ORDER BY "timestamp" DESC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

-- -----------------------------------------------------------------------------
-- 4. Restore original Market Cap function (two subqueries)
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
        ts.bucket AS "timestamp",
        ((
            COALESCE(ts.total_supply, 0)
            - COALESCE(ts.excluded_supply, 0)
            - COALESCE(ts.locked_tokens, 0)
            - COALESCE(ts.locked_fees, 0)
        ) * COALESCE(pc.power_conversion, 0))::TEXT AS "value"
    FROM (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' THEN value::NUMERIC END) AS total_supply,
            MAX(CASE WHEN name = 'manifest_tokenomics_excluded_supply' THEN value::NUMERIC END) AS excluded_supply,
            MAX(CASE WHEN name = 'locked_tokens' THEN value::NUMERIC END) AS locked_tokens,
            MAX(CASE WHEN name = 'locked_fees' THEN value::NUMERIC END) AS locked_fees
        FROM internal.cagg_calculated_metric
        WHERE schema = p_schema
          AND name IN (
            'manifest_tokenomics_total_supply',
            'manifest_tokenomics_excluded_supply',
            'locked_tokens',
            'locked_fees'
          )
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY time_bucket(p_interval, bucket)
    ) ts
    LEFT JOIN (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(value::NUMERIC) AS power_conversion
        FROM internal.cagg_calculated_metric
        WHERE name = 'talib_mfx_power_conversion'
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY time_bucket(p_interval, bucket)
    ) pc ON ts.bucket = pc.bucket
    ORDER BY "timestamp" ASC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

COMMIT;
