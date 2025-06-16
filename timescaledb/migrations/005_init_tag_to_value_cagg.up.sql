BEGIN;

-- Workaround for https://github.com/jackc/pgx/issues/1362
-- Telegraf still uses `pgx` v4
--
-- Initialize supply continuous aggregates and retention policies
DO
$outer$
DECLARE
  rec RECORD;
BEGIN
FOR rec IN (
  VALUES
    ('manifest_tokenomics_total_supply', 'testnet'),
    ('manifest_tokenomics_excluded_supply', 'testnet'),
    ('locked_tokens', 'testnet'),
    ('locked_fees', 'testnet'),
    ('manifest_tokenomics_total_supply', 'mainnet'),
    ('manifest_tokenomics_excluded_supply', 'mainnet'),
    ('locked_tokens', 'mainnet'),
    ('locked_fees', 'mainnet')
) LOOP
  PERFORM internal.initialize_metric(rec.column1, rec.column2);
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS tmp_%I', rec.column2);
  EXECUTE format('CREATE TABLE IF NOT EXISTS tmp_%I.%I ("time" TIMESTAMPTZ, "tags" JSONB, "value" TEXT, PRIMARY KEY (time, tags))', rec.column2, rec.column1);
  EXECUTE format(
    $func$
      SELECT create_hypertable('tmp_%I.%I', 'time', if_not_exists => TRUE)
    $func$, rec.column2, rec.column1
  );
  EXECUTE format(
    $func$
      SELECT add_retention_policy('tmp_%I.%I', INTERVAL '1 day', if_not_exists => TRUE)
    $func$, rec.column2, rec.column1
  );

  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.tmp_to_%2$I_%1$I()
    RETURNS trigger AS $$
    BEGIN
    INSERT INTO %2$I.%1$I(time, tags, value)
      VALUES (NEW.time, NEW.tags, NEW.value::NUMERIC)
    ON CONFLICT (time, tags)
      DO UPDATE SET value = EXCLUDED.value;
    RETURN NEW;
    END;
    $$
    LANGUAGE plpgsql;
    $func$, rec.column1, rec.column2
  );

  EXECUTE format(
    'CREATE OR REPLACE TRIGGER trg_tmp_to_%2$I_%1$I AFTER INSERT ON tmp_%2$I.%1$I FOR EACH ROW EXECUTE FUNCTION api.tmp_to_%2$I_%1$I();',
    rec.column1, rec.column2
  );

  EXECUTE format(
    $func$
    CREATE MATERIALIZED VIEW IF NOT EXISTS %2$I.cagg_%1$I
      WITH (
        timescaledb.continuous,
        timescaledb.materialized_only = false -- Enable real-time aggregation
      )
    AS
      SELECT
        time_bucket('1 minute', d.time)      AS "timestamp",
        max(d.value::NUMERIC)                AS "value"
      FROM %2$I.%1$I as d
      GROUP BY 1
    WITH NO DATA;
    $func$, rec.column1, rec.column2
  );

  EXECUTE format(
    $func$
    SELECT add_continuous_aggregate_policy(
      '%I.cagg_%I',
      start_offset      => INTERVAL '1 year',
      end_offset        => INTERVAL '1 hour',
      schedule_interval => INTERVAL '1 hour',
      if_not_exists => TRUE
    );
    $func$, rec.column2, rec.column1
  );

END LOOP;
END;
$outer$;

COMMIT;
