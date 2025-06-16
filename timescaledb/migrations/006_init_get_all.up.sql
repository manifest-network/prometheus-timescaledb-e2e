BEGIN;

-- Create functions for testnet, mainnet, cumsum, and common schemas to get the latest metrics
DO
$outer$
DECLARE
  rec RECORD;
BEGIN
FOR rec IN (
  VALUES
    ('testnet'),
    ('mainnet'),
    ('cumsum'),
    ('common')
) LOOP
  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.get_all_latest_%1$I_metrics()
      RETURNS TABLE(
        table_name    TEXT,
        "timestamp"   TIMESTAMPTZ,
        "value"       TEXT
      )
    LANGUAGE plpgsql STABLE
    SECURITY DEFINER
    SET search_path = %1$I, internal, public
    AS $body$
    DECLARE
      sql TEXT;
    BEGIN
      SELECT string_agg(
               format(
                 '(SELECT %%L AS table_name, "timestamp", "value"::TEXT FROM api.latest_%1$I_%%I)',
                 t.table_name,
                 t.table_name
               ),
               E'\nUNION ALL\n'
             )
        INTO sql
        FROM information_schema.tables AS t
       WHERE t.table_schema = %1$L
         AND t.table_type   = 'BASE TABLE';

      RETURN QUERY EXECUTE sql;
    END;
    $body$
    $func$, rec.column1
  );

  EXECUTE format('GRANT EXECUTE ON FUNCTION api.get_all_latest_%I_metrics() TO web_anon;', rec.column1);
END LOOP;
END;
$outer$;

COMMIT;
