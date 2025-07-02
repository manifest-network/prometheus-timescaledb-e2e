BEGIN;

CREATE OR REPLACE FUNCTION api.get_all_latest_token_metrics(
    p_schema TEXT
)
RETURNS TABLE(
    circulating_supply NUMERIC,
    burned_supply NUMERIC,
    fdv NUMERIC,
    market_cap NUMERIC
) AS $$
    SELECT
        cs.value AS circulating_supply,
        bs.value AS burned_supply,
        fdv.value AS fdv,
        mc.value AS market_cap
    FROM
        api.get_latest_circulating_supply(p_schema) cs,
        api.get_latest_burned_supply(p_schema) bs,
        api.get_latest_fdv(p_schema) fdv,
        api.get_latest_market_cap(p_schema) mc;
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

COMMIT;
