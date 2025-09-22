BEGIN;

-- Remove locked fees from the burned supply calculation
CREATE OR REPLACE FUNCTION api.get_agg_burned_supply(
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
        bucket AS "timestamp",
        COALESCE(total_mfx_burned, 0)::TEXT AS "value"
    FROM (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(CASE WHEN name = 'total_mfx_burned' THEN value::NUMERIC END) AS total_mfx_burned
        FROM internal.cagg_calculated_metric
        WHERE schema = p_schema
          AND name IN ('total_mfx_burned')
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY time_bucket(p_interval, bucket)
    ) AS pivoted
    ORDER BY "timestamp" ASC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

-- Remove burned supply from the latest token metrics
CREATE OR REPLACE FUNCTION api.get_all_latest_token_metrics(
    p_schema TEXT
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    table_name TEXT,
    "value" TEXT
) AS $$
    SELECT "timestamp", 'circulating_supply' AS table_name, "value"
    FROM api.get_latest_circulating_supply(p_schema)
    UNION ALL
    SELECT "timestamp", 'fdv' AS table_name, "value"
    FROM api.get_latest_fdv(p_schema)
    UNION ALL
    SELECT "timestamp", 'market_cap' AS table_name, "value"
    FROM api.get_latest_market_cap(p_schema);
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

COMMIT;
