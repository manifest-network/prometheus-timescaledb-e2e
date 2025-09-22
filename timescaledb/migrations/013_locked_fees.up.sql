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

-- Add function to get aggregated locked fees
CREATE OR REPLACE FUNCTION api.get_agg_locked_fees(
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
        COALESCE(locked_fees, 0)::TEXT AS "value"
    FROM (
        SELECT
            time_bucket(p_interval, bucket) AS bucket,
            MAX(CASE WHEN name = 'locked_fees' THEN value::NUMERIC END) AS locked_fees
        FROM internal.cagg_calculated_metric
        WHERE schema = p_schema
          AND name IN ('locked_fees')
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

-- Add function to get the latest locked fees
CREATE OR REPLACE FUNCTION api.get_latest_locked_fees(
    p_schema TEXT
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_locked_fees(
        p_schema,
        INTERVAL '1 minute',
        now() - INTERVAL '1 day',
        now()
    )
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

-- Add locked fees to the get_all_latest_token_metrics function
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
    SELECT "timestamp", 'burned_supply' AS table_name, "value"
    FROM api.get_latest_burned_supply(p_schema)
    UNION ALL
    SELECT "timestamp", 'locked_fees' AS table_name, "value"
    FROM api.get_latest_locked_fees(p_schema)
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
