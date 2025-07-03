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
    SELECT DISTINCT ON (rw.name) rw.time AS "timestamp", rw.name AS table_name,
        COALESCE(
          max(t.supply::NUMERIC),
          max(t.excluded_supply::NUMERIC),
          max(t.amount::NUMERIC),
          max(rw.value::NUMERIC)
        )::TEXT AS "value"
    FROM internal.prometheus_remote_write_tag AS t
    JOIN internal.prometheus_remote_write as rw using (tag_id)
    WHERE schema = 'testnet'
    GROUP BY rw.name, rw.time
    ORDER BY rw.name, rw.time DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_mainnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT DISTINCT ON (rw.name) rw.time AS "timestamp", rw.name AS table_name,
        COALESCE(
          max(t.supply::NUMERIC),
          max(t.excluded_supply::NUMERIC),
          max(t.amount::NUMERIC),
          max(rw.value::NUMERIC)
        )::TEXT AS "value"
    FROM internal.prometheus_remote_write_tag AS t
    JOIN internal.prometheus_remote_write as rw using (tag_id)
    WHERE schema = 'mainnet'
    GROUP BY rw.name, rw.time
    ORDER BY rw.name, rw.time DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_cumsum_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
    SELECT DISTINCT ON (name) bucket AS "timestamp", name AS table_name, cumulative_sum::TEXT AS "value"
    FROM cumsum.all_metrics_cumsum
    ORDER BY name, bucket DESC
$$
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = cumsum;

COMMIT;
