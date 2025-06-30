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

CREATE OR REPLACE FUNCTION api.get_agg_cumsum_metric(
    p_metric_name TEXT,
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
        MAX(cumulative_sum) AS "value"
    FROM cumsum.all_metrics_cumsum
    WHERE name = p_metric_name
      AND bucket >= p_from
      AND bucket < p_to
    GROUP BY bucket
    ORDER BY bucket ASC
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = cumsum, public;

COMMIT;
