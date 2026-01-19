BEGIN;

-- Restore previous cumsum functions from migration 014

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
  SELECT
    ts,
    tag_id,
    SUM(period_sum) OVER (PARTITION BY tag_id ORDER BY ts) AS running_sum
  FROM increments
)
SELECT
  r.ts AS "timestamp",
  MAX(COALESCE(b.base, 0) + r.running_sum)::TEXT AS "value"
FROM running r
LEFT JOIN base b USING (tag_id)
GROUP BY r.ts
ORDER BY r.ts;
$$;

COMMIT;
