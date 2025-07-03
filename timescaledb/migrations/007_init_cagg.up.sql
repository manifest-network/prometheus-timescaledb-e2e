BEGIN;

CREATE MATERIALIZED VIEW IF NOT EXISTS internal.cagg_calculated_metric
      WITH (
        timescaledb.continuous,
        timescaledb.materialized_only = false -- Enable real-time aggregation
      )
    AS
      SELECT
        time_bucket('1 minute', rw.time)      AS bucket,
        rw.name                               AS name,
        rw.schema                             AS "schema",
        COALESCE(
          max(t.supply::NUMERIC),
          max(t.excluded_supply::NUMERIC),
          max(t.amount::NUMERIC),
          max(rw.value::NUMERIC)
        ) AS "value"
      FROM internal.prometheus_remote_write_tag as t
      JOIN internal.prometheus_remote_write as rw using (tag_id)
      WHERE rw.name IN ('manifest_tokenomics_total_supply',
                        'manifest_tokenomics_excluded_supply',
                        'locked_tokens',
                        'locked_fees',
                        'total_mfx_burned',
                        'talib_mfx_power_conversion')
      GROUP BY 1, 2, 3
    WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'internal.cagg_calculated_metric',
  start_offset => NULL,
  end_offset   => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

COMMIT;
