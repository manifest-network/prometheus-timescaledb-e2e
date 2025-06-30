BEGIN;

CREATE TABLE IF NOT EXISTS cumsum.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL,
    PRIMARY KEY (time, name, schema, tag_id)
);
SELECT create_hypertable('cumsum.prometheus_remote_write', 'time');

SET timescaledb.enable_cagg_window_functions TO TRUE;

CREATE MATERIALIZED VIEW IF NOT EXISTS cumsum.all_metrics_minute
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 minute', time) AS bucket,
  name,
  tag_id,
  SUM(value) AS sum_value
FROM cumsum.prometheus_remote_write
GROUP BY bucket, name, tag_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'cumsum.all_metrics_minute',
  NULL,
  INTERVAL '1 minute',
  INTERVAL '1 minute'
);

CREATE OR REPLACE VIEW cumsum.all_metrics_cumsum AS
SELECT
  bucket,
  name,
  tag_id,
  SUM(sum_value) OVER (PARTITION BY name, tag_id ORDER BY bucket) AS cumulative_sum
FROM cumsum.all_metrics_minute;

CREATE OR REPLACE FUNCTION api.get_all_latest_cumsum_metrics()
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    table_name TEXT,
    value TEXT
) AS $$
    SELECT DISTINCT ON (name, tag_id)
        bucket AS "timestamp",
        name AS table_name,
        cumulative_sum::TEXT AS value
    FROM cumsum.all_metrics_cumsum
    ORDER BY name, tag_id, bucket DESC
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = cumsum, internal;

GRANT EXECUTE ON FUNCTION api.get_all_latest_cumsum_metrics() TO web_anon;

COMMIT;
