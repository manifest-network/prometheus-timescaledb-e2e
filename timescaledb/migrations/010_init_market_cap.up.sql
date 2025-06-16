BEGIN;

DO
$outer$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN (VALUES ('testnet'),('mainnet')) LOOP

    -- 1) function to page through history
    EXECUTE format($func$
    CREATE OR REPLACE FUNCTION api.get_%1$I_market_cap(
      p_interval INTERVAL,
      p_from     TIMESTAMPTZ,
      p_to       TIMESTAMPTZ
    )
    RETURNS TABLE (
      "timestamp" TIMESTAMPTZ,
      "value"     TEXT
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
        max(
          ( t."value"
            - COALESCE(e."value",0)     -- excluded
            - COALESCE(l."value",0)     -- locked tokens
            - COALESCE(f_fees."value",0) -- locked fees
          )
          * COALESCE(f_pow."value",0)    -- power conversion
        )::TEXT AS "value"
      FROM cagg_manifest_tokenomics_total_supply          AS t
      LEFT JOIN cagg_manifest_tokenomics_excluded_supply  AS e USING("timestamp")
      LEFT JOIN cagg_locked_tokens                        AS l USING("timestamp")
      LEFT JOIN cagg_locked_fees                          AS f_fees USING("timestamp")
      LEFT JOIN common.cagg_mfx_power_conversion          AS f_pow USING("timestamp")
      WHERE t."timestamp" BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1 DESC;
    END;
    $$;
    $func$, rec.column1);

    EXECUTE format(
      'GRANT EXECUTE ON FUNCTION api.get_%I_market_cap(INTERVAL,TIMESTAMPTZ,TIMESTAMPTZ) TO web_anon;',
      rec.column1
    );

    EXECUTE format($func$
    CREATE OR REPLACE VIEW api.latest_%1$I_market_cap AS
      SELECT
        cs."timestamp",
        ( cs."value" * COALESCE(f_pow."value",0) )::TEXT AS value
      FROM (
        SELECT
          t."timestamp",
          t."value"
            - COALESCE(e."value",0)
            - COALESCE(l."value",0)
            - COALESCE(f_fees."value",0) AS "value"
        FROM %1$I.cagg_manifest_tokenomics_total_supply         AS t
        LEFT JOIN %1$I.cagg_manifest_tokenomics_excluded_supply AS e USING("timestamp")
        LEFT JOIN %1$I.cagg_locked_tokens                       AS l USING("timestamp")
        LEFT JOIN %1$I.cagg_locked_fees                         AS f_fees USING("timestamp")
      ) AS cs
      LEFT JOIN common.cagg_mfx_power_conversion AS f_pow USING("timestamp")
      ORDER BY 1 DESC
      LIMIT 1;
    $func$, rec.column1);

    EXECUTE format(
      'GRANT SELECT ON api.latest_%I_market_cap TO web_anon;',
      rec.column1
    );

    EXECUTE format($func$
    CREATE OR REPLACE FUNCTION api.get_latest_%1$I_market_cap()
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
        FROM api.latest_%1$I_market_cap as t;
    END;
    $$;
    $func$, rec.column1);

    EXECUTE format(
      'GRANT EXECUTE ON FUNCTION api.get_latest_%I_market_cap() TO web_anon;',
      rec.column1
    );

    EXECUTE FORMAT($func$
      CREATE OR REPLACE FUNCTION api.get_latest_%1$I_market_cap_value()
      RETURNS NUMERIC
      LANGUAGE SQL
      STABLE
      SECURITY DEFINER
      SET search_path = %1$I, common, internal, public
      AS $$
        SELECT t.value::NUMERIC
          FROM api.latest_%1$I_market_cap as t
          LIMIT 1;
      $$;
    $func$, rec.column1);

    EXECUTE FORMAT('GRANT EXECUTE ON FUNCTION api.get_latest_%I_market_cap_value() TO web_anon;', rec.column1);

  END LOOP;
END;
$outer$ LANGUAGE plpgsql;

COMMIT;
