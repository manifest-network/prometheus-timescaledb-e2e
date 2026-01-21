BEGIN;

-- =============================================================================
-- Migration 003: API Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Excluded addresses functions
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_excluded_addresses()
RETURNS TABLE(id INT, value TEXT) AS $$
    SELECT id, value FROM internal.excluded_addresses;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.add_excluded_address(p_value TEXT)
RETURNS void AS $$
    INSERT INTO internal.excluded_addresses (value) VALUES (p_value);
$$ LANGUAGE sql
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.rm_excluded_address(p_value TEXT)
RETURNS void AS $$
    DELETE FROM internal.excluded_addresses WHERE value = p_value;
$$ LANGUAGE sql
SECURITY DEFINER
SET search_path = internal;

GRANT EXECUTE ON FUNCTION api.get_excluded_addresses() TO web_anon;

-- Revoke public access and grant only to writer
REVOKE EXECUTE ON FUNCTION api.add_excluded_address(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.add_excluded_address(TEXT) TO writer;

REVOKE EXECUTE ON FUNCTION api.rm_excluded_address(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.rm_excluded_address(TEXT) TO writer;

-- -----------------------------------------------------------------------------
-- 2. Raw metrics aggregation function
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_metric(
    p_metric_name TEXT,
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT
        time_bucket(p_interval, time) AS "timestamp",
        COALESCE(
          MAX(t.supply::NUMERIC),
          MAX(t.excluded_supply::NUMERIC),
          MAX(t.amount::NUMERIC),
          MAX(rw.value::NUMERIC)
        )::TEXT AS "value"
    FROM internal.prometheus_remote_write_tag AS t
    JOIN internal.prometheus_remote_write AS rw USING (tag_id)
    WHERE rw.name = p_metric_name
      AND rw.schema = p_schema
      AND rw.time >= p_from
      AND rw.time < p_to
    GROUP BY 1
    ORDER BY 1 DESC
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_agg_metric(TEXT, TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;

-- -----------------------------------------------------------------------------
-- 3. Cumsum aggregation function (simplified for single host)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_cumsum_metric(
    p_metric_name TEXT,
    p_schema      TEXT,
    p_interval    INTERVAL,
    p_from        TIMESTAMPTZ,
    p_to          TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT)
LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = cumsum, public
AS $$
WITH base AS (
  SELECT COALESCE(SUM(sum_value), 0) AS base
  FROM cumsum.all_metrics_minute
  WHERE name = p_metric_name
    AND schema = p_schema
    AND bucket < p_from
),
increments AS (
  SELECT
    time_bucket(p_interval, bucket) AS ts,
    SUM(sum_value) AS period_sum
  FROM cumsum.all_metrics_minute
  WHERE name = p_metric_name
    AND schema = p_schema
    AND bucket >= p_from
    AND bucket < p_to
  GROUP BY ts
),
running AS (
  SELECT
    ts,
    SUM(period_sum) OVER (ORDER BY ts) AS running_sum
  FROM increments
)
SELECT
  r.ts AS "timestamp",
  ((SELECT base FROM base) + r.running_sum)::TEXT AS "value"
FROM running r
ORDER BY r.ts;
$$;

GRANT EXECUTE ON FUNCTION api.get_agg_cumsum_metric(TEXT, TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;

-- -----------------------------------------------------------------------------
-- 4. Geo coordinates function
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_latest_geo_coordinates()
RETURNS TABLE(
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    country_name TEXT,
    city TEXT
) AS $$
SELECT latitude, longitude, country_name, city
FROM geo.latest_coords
WHERE bucket = (SELECT MAX(bucket) FROM geo.latest_coords);
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = geo;

GRANT EXECUTE ON FUNCTION api.get_latest_geo_coordinates() TO web_anon;

-- -----------------------------------------------------------------------------
-- 5. Circulating supply functions
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_circulating_supply(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        (
            COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_excluded_supply' THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_tokens' THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_fees' THEN value::NUMERIC END), 0)
        )::TEXT AS "value"
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
    ORDER BY "timestamp" ASC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_circulating_supply(p_schema TEXT)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_circulating_supply(
        p_schema,
        INTERVAL '1 minute',
        now() - INTERVAL '1 day',
        now()
    )
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_agg_circulating_supply(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_circulating_supply(TEXT) TO web_anon;

-- -----------------------------------------------------------------------------
-- 6. Burned supply functions (total_mfx_burned only, no locked_fees)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_burned_supply(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        COALESCE(MAX(CASE WHEN name = 'total_mfx_burned' THEN value::NUMERIC END), 0)::TEXT AS "value"
    FROM internal.cagg_calculated_metric
    WHERE schema = p_schema
      AND name = 'total_mfx_burned'
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY time_bucket(p_interval, bucket)
    ORDER BY "timestamp" ASC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_burned_supply(p_schema TEXT)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_burned_supply(
        p_schema,
        INTERVAL '1 minute',
        now() - INTERVAL '1 day',
        now()
    )
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_agg_burned_supply(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_burned_supply(TEXT) TO web_anon;

-- -----------------------------------------------------------------------------
-- 7. FDV functions (optimized single scan)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_fdv(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        (
            COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN value::NUMERIC END), 0) *
            COALESCE(MAX(CASE WHEN name = 'talib_mfx_power_conversion' AND schema = 'common' THEN value::NUMERIC END), 0)
        )::TEXT AS "value"
    FROM internal.cagg_calculated_metric
    WHERE (
        (schema = p_schema AND name = 'manifest_tokenomics_total_supply')
        OR (schema = 'common' AND name = 'talib_mfx_power_conversion')
    )
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY time_bucket(p_interval, bucket)
    HAVING MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN 1 END) IS NOT NULL
    ORDER BY "timestamp" ASC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_fdv(p_schema TEXT)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_fdv(
        p_schema,
        INTERVAL '1 minute',
        now() - INTERVAL '1 day',
        now()
    )
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_agg_fdv(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_fdv(TEXT) TO web_anon;

-- -----------------------------------------------------------------------------
-- 8. Market cap functions (optimized single scan)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_agg_market_cap(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT
        time_bucket(p_interval, bucket) AS "timestamp",
        ((
            COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'manifest_tokenomics_excluded_supply' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_tokens' AND schema = p_schema THEN value::NUMERIC END), 0)
            - COALESCE(MAX(CASE WHEN name = 'locked_fees' AND schema = p_schema THEN value::NUMERIC END), 0)
        ) * COALESCE(MAX(CASE WHEN name = 'talib_mfx_power_conversion' AND schema = 'common' THEN value::NUMERIC END), 0))::TEXT AS "value"
    FROM internal.cagg_calculated_metric
    WHERE (
        (schema = p_schema AND name IN (
            'manifest_tokenomics_total_supply',
            'manifest_tokenomics_excluded_supply',
            'locked_tokens',
            'locked_fees'
        ))
        OR (schema = 'common' AND name = 'talib_mfx_power_conversion')
    )
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY time_bucket(p_interval, bucket)
    HAVING MAX(CASE WHEN name = 'manifest_tokenomics_total_supply' AND schema = p_schema THEN 1 END) IS NOT NULL
    ORDER BY "timestamp" ASC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_market_cap(p_schema TEXT)
RETURNS TABLE("timestamp" TIMESTAMPTZ, "value" TEXT) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_market_cap(
        p_schema,
        INTERVAL '1 minute',
        now() - INTERVAL '1 day',
        now()
    )
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_agg_market_cap(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_market_cap(TEXT) TO web_anon;

-- -----------------------------------------------------------------------------
-- 9. Token metrics helper functions
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_all_latest_token_metrics(p_schema TEXT)
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT "timestamp", 'circulating_supply' AS table_name, "value"
    FROM api.get_latest_circulating_supply(p_schema)
    UNION ALL
    SELECT "timestamp", 'fdv' AS table_name, "value"
    FROM api.get_latest_fdv(p_schema)
    UNION ALL
    SELECT "timestamp", 'market_cap' AS table_name, "value"
    FROM api.get_latest_market_cap(p_schema);
$$ LANGUAGE sql STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_mainnet_circulating_supply_value()
RETURNS NUMERIC AS $$
    SELECT "value"::NUMERIC
    FROM api.get_latest_circulating_supply('mainnet');
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_mainnet_total_supply_value()
RETURNS NUMERIC AS $$
    SELECT MAX(supply::NUMERIC) AS value
    FROM internal.prometheus_remote_write_tag
    WHERE supply IS NOT NULL;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal, public;

GRANT EXECUTE ON FUNCTION api.get_all_latest_token_metrics(TEXT) TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_mainnet_circulating_supply_value() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_latest_mainnet_total_supply_value() TO web_anon;

-- -----------------------------------------------------------------------------
-- 10. Get all latest metrics functions
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_all_latest_mainnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::TEXT
  FROM internal.prometheus_mainnet_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_testnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::TEXT
  FROM internal.prometheus_testnet_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_common_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::TEXT
  FROM internal.prometheus_common_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_cumsum_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = cumsum, public
AS $$
  SELECT
    MAX(bucket) AS "timestamp",
    name AS table_name,
    SUM(sum_value)::TEXT AS "value"
  FROM cumsum.all_metrics_minute
  GROUP BY name
  ORDER BY table_name;
$$;

GRANT EXECUTE ON FUNCTION api.get_all_latest_mainnet_metrics() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_all_latest_testnet_metrics() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_all_latest_common_metrics() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_all_latest_cumsum_metrics() TO web_anon;

COMMIT;
