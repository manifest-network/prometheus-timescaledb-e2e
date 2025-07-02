BEGIN;

CREATE OR REPLACE FUNCTION api.get_agg_market_cap(
    p_schema TEXT,
    p_interval INTERVAL,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" NUMERIC
) AS $$
    SELECT
        ts.bucket AS "timestamp",
        (
            COALESCE(ts.total_supply, 0)
            - COALESCE(ts.excluded_supply, 0)
            - COALESCE(ts.locked_tokens, 0)
            - COALESCE(ts.locked_fees, 0)
        ) * COALESCE(pc.power_conversion, 0) AS "value"
    FROM (
        SELECT
            bucket,
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
        GROUP BY bucket
    ) ts
    LEFT JOIN (
        SELECT
            bucket,
            MAX(value::NUMERIC) AS power_conversion
        FROM internal.cagg_calculated_metric
        WHERE name = 'talib_mfx_power_conversion'
          AND bucket >= p_from
          AND bucket < p_to
        GROUP BY bucket
    ) pc ON ts.bucket = pc.bucket
    ORDER BY ts.bucket ASC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_market_cap(
    p_schema TEXT
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" NUMERIC
) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_market_cap(
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
