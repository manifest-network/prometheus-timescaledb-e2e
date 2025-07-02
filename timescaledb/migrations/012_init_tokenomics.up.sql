BEGIN;

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
