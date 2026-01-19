BEGIN;

-- =============================================================================
-- Migration 015: Simplify cumsum functions
-- =============================================================================
-- Since there is only a single Telegraf host, we no longer need to select
-- between multiple hosts. This simplifies the cumsum calculations.
-- =============================================================================

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
  -- Cumulative sum BEFORE p_from
  SELECT COALESCE(SUM(sum_value), 0) AS base
  FROM cumsum.all_metrics_minute
  WHERE name = p_metric_name
    AND schema = p_schema
    AND bucket < p_from
),
increments AS (
  -- Per-interval increments inside [p_from, p_to)
  SELECT
    time_bucket(p_interval, bucket) AS ts,
    SUM(sum_value) AS period_sum
  FROM cumsum.all_metrics_minute
  WHERE name = p_metric_name
    AND schema = p_schema
    AND bucket >= p_from
    AND bucket < p_to
  GROUP BY ts
),
running AS (
  -- Running sum over the chosen intervals
  SELECT
    ts,
    SUM(period_sum) OVER (ORDER BY ts) AS running_sum
  FROM increments
)
SELECT
  r.ts AS "timestamp",
  ((SELECT base FROM base) + r.running_sum)::TEXT AS "value"
FROM running r
ORDER BY r.ts;
$$;

CREATE OR REPLACE FUNCTION api.get_all_latest_cumsum_metrics()
RETURNS TABLE("timestamp" TIMESTAMPTZ, table_name TEXT, "value" TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = cumsum, public
AS $$
  SELECT
    MAX(bucket) AS "timestamp",
    name AS table_name,
    SUM(sum_value)::TEXT AS "value"
  FROM cumsum.all_metrics_minute
  GROUP BY name
  ORDER BY table_name;
$$;

COMMIT;
