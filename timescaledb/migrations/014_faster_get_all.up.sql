BEGIN;

CREATE MATERIALIZED VIEW internal.prometheus_mainnet_1m
WITH (timescaledb.continuous)
AS
SELECT
  time_bucket('1 minute', rw.time) AS bucket,
  rw.name,
  COALESCE(
    MAX(t.supply::NUMERIC),
    MAX(t.excluded_supply::NUMERIC),
    MAX(t.amount::NUMERIC),
    last(rw.value, rw.time)
  ) AS value
FROM internal.prometheus_remote_write AS rw
JOIN internal.prometheus_remote_write_tag AS t USING (tag_id)
WHERE rw.schema = 'mainnet'
GROUP BY bucket, rw.name
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'internal.prometheus_mainnet_1m',
  NULL,
  INTERVAL '1 minute',
  INTERVAL '1 minute'
);

CREATE MATERIALIZED VIEW internal.prometheus_testnet_1m
WITH (timescaledb.continuous)
AS
SELECT
  time_bucket('1 minute', rw.time) AS bucket,
  rw.name,
  COALESCE(
    MAX(t.supply::NUMERIC),
    MAX(t.excluded_supply::NUMERIC),
    MAX(t.amount::NUMERIC),
    last(rw.value, rw.time)
  ) AS value
FROM internal.prometheus_remote_write AS rw
JOIN internal.prometheus_remote_write_tag AS t USING (tag_id)
WHERE rw.schema = 'testnet'
GROUP BY bucket, rw.name
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'internal.prometheus_testnet_1m',
  NULL,
  INTERVAL '1 minute',
  INTERVAL '1 minute'
);

CREATE MATERIALIZED VIEW internal.prometheus_common_1m
WITH (timescaledb.continuous)
AS
SELECT
  time_bucket('1 minute', rw.time) AS bucket,
  rw.name,
  COALESCE(
    MAX(t.supply::NUMERIC),
    MAX(t.excluded_supply::NUMERIC),
    MAX(t.amount::NUMERIC),
    last(rw.value, rw.time)
  ) AS value
FROM internal.prometheus_remote_write AS rw
JOIN internal.prometheus_remote_write_tag AS t USING (tag_id)
WHERE rw.schema = 'common'
GROUP BY bucket, rw.name
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'internal.prometheus_common_1m',
  NULL,
  INTERVAL '1 minute',
  INTERVAL '1 minute'
);

CREATE OR REPLACE FUNCTION api.get_all_latest_mainnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::text
  FROM internal.prometheus_mainnet_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_testnet_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::text
  FROM internal.prometheus_testnet_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

CREATE OR REPLACE FUNCTION api.get_all_latest_common_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT) AS $$
  SELECT DISTINCT ON (name)
    bucket AS "timestamp",
    name   AS table_name,
    value::text
  FROM internal.prometheus_common_1m
  ORDER BY name, bucket DESC;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = internal;

-- We have 2 mirrored hosts. Pick one.
CREATE OR REPLACE FUNCTION api.get_all_latest_cumsum_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = cumsum, public
AS $$
  WITH per_tag AS (
    SELECT
      name,
      tag_id,
      MAX(bucket)    AS last_bucket,
      SUM(sum_value) AS last_cumsum
    FROM cumsum.all_metrics_minute
    GROUP BY name, tag_id
  ),
  chosen AS (
    -- pick one tag per metric at the latest bucket
    SELECT DISTINCT ON (name)
      name,
      last_bucket,
      last_cumsum
    FROM per_tag
    ORDER BY name, last_bucket DESC
  )
  SELECT
    last_bucket        AS "timestamp",
    name               AS table_name,
    last_cumsum::TEXT  AS "value"
  FROM chosen
  ORDER BY table_name;
$$;

CREATE OR REPLACE FUNCTION api.get_agg_cumsum_metric(
    p_metric_name TEXT,
    p_schema      TEXT,
    p_interval    INTERVAL,
    p_from        TIMESTAMPTZ,
    p_to          TIMESTAMPTZ
)
RETURNS TABLE(
    "timestamp" TIMESTAMPTZ,
    "value"     TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
STRICT
SET search_path = cumsum, public
AS $$
WITH base AS (
  -- cumulative sum BEFORE p_from, per tag (host)
  SELECT
    tag_id,
    COALESCE(SUM(sum_value), 0) AS base
  FROM cumsum.all_metrics_minute
  WHERE name   = p_metric_name
    AND schema = p_schema
    AND bucket < p_from
  GROUP BY tag_id
),
increments AS (
  -- per-interval increments inside [p_from, p_to), per tag
  SELECT
    time_bucket(p_interval, bucket) AS ts,
    tag_id,
    SUM(sum_value)                  AS period_sum
  FROM cumsum.all_metrics_minute
  WHERE name   = p_metric_name
    AND schema = p_schema
    AND bucket >= p_from
    AND bucket <  p_to
  GROUP BY ts, tag_id
),
running AS (
  -- running sum per tag over the chosen intervals
  SELECT
    ts,
    tag_id,
    SUM(period_sum) OVER (PARTITION BY tag_id ORDER BY ts) AS running_sum
  FROM increments
)
SELECT
  r.ts AS "timestamp",
  -- match old behavior: take the *max* cumulative_sum across tags for each bucket
  MAX(COALESCE(b.base, 0) + r.running_sum)::TEXT AS "value"
FROM running r
LEFT JOIN base b USING (tag_id)
GROUP BY r.ts
ORDER BY r.ts;
$$;

DROP VIEW IF EXISTS cumsum.all_metrics_cumsum CASCADE;

COMMIT;
