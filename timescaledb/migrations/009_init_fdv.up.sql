BEGIN;

SELECT internal.initialize_metric('talib_mfx_power_conversion', 'common');
CREATE MATERIALIZED VIEW IF NOT EXISTS common.cagg_mfx_power_conversion
  WITH (
    timescaledb.continuous,
    timescaledb.materialized_only = false -- Enable real-time aggregation
  )
AS
  SELECT
    time_bucket('1 minute', d.time)      AS "timestamp",
    max(d.value::NUMERIC) / 10           AS "value" -- Adjust with the 1:10 split
  FROM common.talib_mfx_power_conversion as d
  GROUP BY 1
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'common.cagg_mfx_power_conversion',
  start_offset      => INTERVAL '1 year',
  end_offset        => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour',
  if_not_exists => TRUE
);

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
      CREATE OR REPLACE FUNCTION api.get_%1$I_fdv(
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
      SET search_path = %1$I, common, internal, public
      STRICT
      AS $$
      BEGIN
        RETURN QUERY
          SELECT
            time_bucket(p_interval, t."timestamp") AS "timestamp",
            trim_scale(max(t."value" * COALESCE(f."value", 0)))::TEXT AS "value"
          FROM cagg_manifest_tokenomics_total_supply AS t
          LEFT JOIN common.cagg_mfx_power_conversion AS f USING ("timestamp")
          WHERE t."timestamp" BETWEEN p_from AND p_to
          GROUP BY 1
          ORDER BY 1 DESC;
      END;
      $$;
    $func$, rec.column1
  );

  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION api.get_%I_fdv(INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ) TO web_anon;',
    rec.column1
  );

  EXECUTE format(
    $func$
    CREATE OR REPLACE VIEW api.latest_%1$I_fdv AS
      SELECT
        t."timestamp",
        trim_scale((t."value" * COALESCE(f."value", 0)))::TEXT AS value
      FROM %1$I.cagg_manifest_tokenomics_total_supply         AS t
      LEFT JOIN common.cagg_mfx_power_conversion              AS f USING ("timestamp")
      ORDER BY 1 DESC
      LIMIT 1;
    $func$, rec.column1
  );

  EXECUTE format(
    'GRANT SELECT ON api.latest_%I_fdv TO web_anon;',
    rec.column1
  );

  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.get_latest_%1$I_fdv()
      RETURNS TABLE (
        "timestamp" TIMESTAMPTZ,
        "value"     TEXT
      )
      LANGUAGE plpgsql STABLE
      SECURITY DEFINER
      SET search_path = %1$I, common, internal, public
      AS $$
      BEGIN
        RETURN QUERY
          SELECT t.timestamp, t.value
          FROM api.latest_%1$I_fdv as t;
      END;
      $$;
    $func$, rec.column1
  );

  EXECUTE format(
    'GRANT EXECUTE ON FUNCTION api.get_latest_%I_fdv() TO web_anon;',
    rec.column1
  );
END LOOP;

END;
$outer$ LANGUAGE plpgsql;

COMMIT;
