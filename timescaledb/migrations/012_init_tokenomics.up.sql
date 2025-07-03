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

CREATE OR REPLACE FUNCTION api.get_latest_mainnet_circulating_supply_value()
RETURNS NUMERIC AS $$
    SELECT "value"::NUMERIC
    FROM api.get_latest_circulating_supply('mainnet')
    ORDER BY "timestamp" DESC
    LIMIT 1;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

CREATE OR REPLACE FUNCTION api.get_latest_mainnet_total_supply_value()
RETURNS NUMERIC AS $$
  SELECT COALESCE(t.supply::NUMERIC, 0)
  FROM internal.prometheus_remote_write AS rw
  JOIN internal.prometheus_remote_write_tag AS t USING (tag_id)
  WHERE rw.name='manifest_tokenomics_total_supply' AND rw.schema='mainnet'
  LIMIT 1;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

COMMIT;
