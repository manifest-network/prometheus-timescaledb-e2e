BEGIN;

-- =============================================================================
-- Migration 002: Continuous Aggregates
-- =============================================================================
-- Aggregates are created WITH NO DATA. After backfilling historical data,
-- run: timescaledb/scripts/bulk_refresh_aggregates.sql
-- Policies use bounded start_offset for incremental real-time updates only.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Cumsum 1-minute aggregate
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW cumsum.all_metrics_minute
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 minute', time) AS bucket,
  name,
  schema,
  SUM(value) AS sum_value
FROM cumsum.prometheus_remote_write
GROUP BY bucket, name, schema
WITH NO DATA;

-- Policy only looks back 1 hour for incremental real-time updates
SELECT add_continuous_aggregate_policy(
  'cumsum.all_metrics_minute',
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- -----------------------------------------------------------------------------
-- 2. Geo coordinates aggregate
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW geo.latest_coords
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 minute', rw.time) AS bucket,
  t.instance,
  last(rw.value::DOUBLE PRECISION, rw.time)
    FILTER (WHERE rw.name='manifest_geo_latitude')  AS latitude,
  last(rw.value::DOUBLE PRECISION, rw.time)
    FILTER (WHERE rw.name='manifest_geo_longitude') AS longitude,
  last(t.country_name, rw.time)
    FILTER (WHERE rw.name='manifest_geo_metadata')  AS country_name,
  last(t.city, rw.time)
    FILTER (WHERE rw.name='manifest_geo_metadata')  AS city
FROM internal.prometheus_remote_write rw
JOIN internal.prometheus_remote_write_tag t USING (tag_id)
WHERE rw.schema = 'geo'
  AND rw.name IN (
    'manifest_geo_latitude',
    'manifest_geo_longitude',
    'manifest_geo_metadata'
  )
GROUP BY bucket, t.instance
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'geo.latest_coords',
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- -----------------------------------------------------------------------------
-- 3. Calculated metrics aggregate (tokenomics)
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW internal.cagg_calculated_metric
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
  time_bucket('1 minute', rw.time) AS bucket,
  rw.name AS name,
  rw.schema AS "schema",
  COALESCE(
    MAX(t.supply::NUMERIC),
    MAX(t.excluded_supply::NUMERIC),
    MAX(t.amount::NUMERIC),
    last(rw.value, rw.time)
  ) AS value
FROM internal.prometheus_remote_write_tag AS t
JOIN internal.prometheus_remote_write AS rw USING (tag_id)
WHERE rw.name IN (
  'manifest_tokenomics_total_supply',
  'manifest_tokenomics_excluded_supply',
  'locked_tokens',
  'locked_fees',
  'total_mfx_burned',
  'talib_mfx_power_conversion'
)
GROUP BY bucket, rw.name, rw.schema
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'internal.cagg_calculated_metric',
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- -----------------------------------------------------------------------------
-- 4. Mainnet 1-minute aggregate
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW internal.prometheus_mainnet_1m
WITH (timescaledb.continuous) AS
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
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- -----------------------------------------------------------------------------
-- 5. Testnet 1-minute aggregate
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW internal.prometheus_testnet_1m
WITH (timescaledb.continuous) AS
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
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- -----------------------------------------------------------------------------
-- 6. Common 1-minute aggregate
-- -----------------------------------------------------------------------------

CREATE MATERIALIZED VIEW internal.prometheus_common_1m
WITH (timescaledb.continuous) AS
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
  start_offset => INTERVAL '1 hour',
  end_offset => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

COMMIT;
