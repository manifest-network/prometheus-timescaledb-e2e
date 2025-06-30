BEGIN;

-- get_all_latest_metrics functions
CREATE OR REPLACE FUNCTION api.get_all_latest_common_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT DISTINCT ON (name) time AS "timestamp", name AS table_name, value::TEXT AS "value"
    FROM internal.prometheus_remote_write
    WHERE schema = 'common'
    ORDER BY name, time DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_testnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT DISTINCT ON (name) time AS "timestamp", name AS table_name, value::TEXT AS "value"
    FROM internal.prometheus_remote_write
    WHERE schema = 'testnet'
    ORDER BY name, time DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_mainnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT DISTINCT ON (name) time AS "timestamp", name AS table_name, value::TEXT AS "value"
    FROM internal.prometheus_remote_write
    WHERE schema = 'mainnet'
    ORDER BY name, time DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

-- Grant permissions to web_anon role
GRANT EXECUTE ON FUNCTION api.get_all_latest_common_metrics() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_all_latest_testnet_metrics() TO web_anon;
GRANT EXECUTE ON FUNCTION api.get_all_latest_mainnet_metrics() TO web_anon;

COMMIT;
