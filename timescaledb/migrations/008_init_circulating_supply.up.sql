BEGIN;

CREATE OR REPLACE FUNCTION api.get_agg_circulating_supply(
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
        (COALESCE(total_supply, 0)
         - COALESCE(excluded_supply, 0)
         - COALESCE(locked_tokens, 0)
         - COALESCE(locked_fees, 0))::TEXT AS "value"
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
    ) AS pivoted
    ORDER BY "timestamp" ASC;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_circulating_supply(
    p_schema TEXT
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
    SELECT "timestamp", "value"
    FROM api.get_agg_circulating_supply(
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