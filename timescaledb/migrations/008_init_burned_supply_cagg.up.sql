BEGIN;

DO
$outer$
DECLARE
  rec RECORD;
BEGIN
FOR rec IN (
  VALUES
    ('testnet'),
    ('mainnet')
) LOOP
  EXECUTE format(
    $func$
      SELECT internal.initialize_metric('total_mfx_burned', '%1$I');
    $func$, rec.column1);

  EXECUTE format(
    $func$
    CREATE MATERIALIZED VIEW IF NOT EXISTS %1$I.cagg_total_mfx_burned
      WITH (
        timescaledb.continuous,
        timescaledb.materialized_only = false -- Enable real-time aggregation
      )
    AS
      SELECT
        time_bucket('1 minute', d.time)      AS "timestamp",
        max(d.value::NUMERIC)                AS "value"
      FROM %1$I.total_mfx_burned as d
      GROUP BY 1
    WITH NO DATA;
    $func$, rec.column1);

  EXECUTE format(
    $func$
    SELECT add_continuous_aggregate_policy(
      '%1$I.cagg_total_mfx_burned',
      start_offset      => INTERVAL '1 year',
      end_offset        => INTERVAL '1 hour',
      schedule_interval => INTERVAL '1 hour',
      if_not_exists => TRUE
    );
    $func$, rec.column1);

  EXECUTE format(
    $func$
      CREATE OR REPLACE FUNCTION api.get_%1$I_burned_supply(
        p_interval INTERVAL,
        p_from TIMESTAMPTZ,
        p_to   TIMESTAMPTZ
      )
      RETURNS TABLE (
        "timestamp" TIMESTAMPTZ,
        "value"    TEXT
      )
      LANGUAGE plpgsql STABLE
      SECURITY DEFINER
      SET search_path = %1$I, internal, public
      STRICT
      AS $$
      BEGIN
        RETURN QUERY
          SELECT
            time_bucket(p_interval, t."timestamp") AS "timestamp",
            max(t."value" + COALESCE(f."value", 0))::TEXT AS "value"
          FROM cagg_total_mfx_burned AS t
          LEFT JOIN cagg_locked_fees AS f USING ("timestamp")
          WHERE t."timestamp" BETWEEN p_from AND p_to
          GROUP BY 1
          ORDER BY 1 DESC;
      END;
      $$;
    $func$, rec.column1
  );

  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION api.get_%I_burned_supply(INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;',
    rec.column1
  );


  EXECUTE format(
    $func$
    CREATE OR REPLACE VIEW api.latest_%1$I_burned_supply AS
      SELECT
        t."timestamp",
        (t."value" + COALESCE(f."value", 0))::TEXT AS value -- locked fees (virtually burned)
      FROM %1$I.cagg_total_mfx_burned         AS t
      LEFT JOIN %1$I.cagg_locked_fees         AS f USING ("timestamp")
      ORDER BY 1 DESC
      LIMIT 1;
    $func$, rec.column1);

  EXECUTE format('GRANT SELECT ON api.latest_%I_burned_supply TO web_anon;', rec.column1);

  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.get_latest_%1$I_burned_supply()
      RETURNS TABLE (
        "timestamp" TIMESTAMPTZ,
        "value"     TEXT
      )
      LANGUAGE plpgsql STABLE
      SECURITY DEFINER
      SET search_path = %1$I, internal, public
      AS $$
      BEGIN
        RETURN QUERY
          SELECT t.timestamp, t.value
          FROM api.latest_%1$I_burned_supply as t;
      END;
      $$;
    $func$, rec.column1);

  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION api.get_latest_%I_burned_supply() TO web_anon;',
    rec.column1
  );
  END LOOP;
END;
$outer$;

COMMIT;
