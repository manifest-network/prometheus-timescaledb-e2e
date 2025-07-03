BEGIN;

-- Metric (hyper)table
CREATE TABLE IF NOT EXISTS internal.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL,
    PRIMARY KEY (time, name, schema, tag_id)
);
SELECT create_hypertable('internal.prometheus_remote_write', 'time');
SELECT add_retention_policy('internal.prometheus_remote_write', INTERVAL '1 year');

CREATE INDEX ON internal.prometheus_remote_write (schema, name, time DESC);
CREATE INDEX IF NOT EXISTS idx_metric_name_time ON internal.prometheus_remote_write (name, time DESC);

-- Tag table for metrics
-- Initialize with known tags used in init scripts
CREATE TABLE internal.prometheus_remote_write_tag (
    tag_id BIGINT PRIMARY KEY,
    instance TEXT,
    country_name TEXT,
    city TEXT,
    supply TEXT,
    excluded_supply TEXT,
    amount TEXT
);

CREATE OR REPLACE FUNCTION api.get_agg_metric(
    p_metric_name TEXT,
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
        time_bucket(p_interval, time) AS "timestamp",
        COALESCE(
          max(t.supply::NUMERIC),
          max(t.excluded_supply::NUMERIC),
          max(t.amount::NUMERIC),
          max(rw.value::NUMERIC)
        )::TEXT AS "value"
    FROM internal.prometheus_remote_write_tag AS t
    JOIN internal.prometheus_remote_write as rw using (tag_id)
    WHERE rw.name = p_metric_name
      AND rw.schema = p_schema
      AND rw.time >= p_from
      AND rw.time < p_to
    GROUP BY 1
    ORDER BY 1 DESC
$$
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = internal, public;

-- Grant permissions to web_anon role
GRANT EXECUTE ON FUNCTION api.get_agg_metric(TEXT, TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;

COMMIT;
