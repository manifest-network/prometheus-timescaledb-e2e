BEGIN;

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

CREATE OR REPLACE FUNCTION api.get_latest_fdv(
    p_schema TEXT
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_fdv(
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

COMMIT;
