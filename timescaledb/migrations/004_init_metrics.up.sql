BEGIN;

-- Initialize the metrics tables and functions for each network
-- Regular metrics, i.e., those that are not cumulative
CREATE OR REPLACE FUNCTION internal.initialize_metric(
  p_metric_name TEXT,
  p_network TEXT)
RETURNS VOID AS $outer$
BEGIN
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', p_network);
  EXECUTE format(
    $fmt$
      CREATE TABLE IF NOT EXISTS %I.%I (
        "time" TIMESTAMPTZ NOT NULL,
        "tags" JSONB NOT NULL,
        "value" NUMERIC,
        PRIMARY KEY (time, tags)
      )
    $fmt$, p_network, p_metric_name
  );

  EXECUTE format(
    $fmt$
      SELECT create_hypertable('%I.%I', 'time', if_not_exists => TRUE)
    $fmt$, p_network, p_metric_name
  );

  EXECUTE format(
    $fmt$
      SELECT add_retention_policy('%I.%I', INTERVAL '1 year', if_not_exists => TRUE)
    $fmt$, p_network, p_metric_name
  );

  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.get_%1$I_agg_%2$I (
        p_interval INTERVAL,
        p_from TIMESTAMPTZ,
        p_to TIMESTAMPTZ
    )
    RETURNS TABLE (
        "timestamp" TIMESTAMPTZ,
        "value"     TEXT
    )
    LANGUAGE plpgsql STABLE
    STRICT
    SECURITY DEFINER
    SET search_path = %1$I, internal, public
    AS $body$
    BEGIN
      -- Ensure p_from is less than or equal to p_to
      IF p_from > p_to THEN
        RAISE EXCEPTION 'p_from must be less than or equal to p_to';
      END IF;

      -- Ensure p_interval is a positive interval
      IF  p_interval <= INTERVAL '0' THEN
        RAISE EXCEPTION 'p_interval must be a positive interval';
      END IF;

      -- Ensure p_interval is not larger than the time range
      IF p_interval > (p_to - p_from) THEN
        RAISE EXCEPTION 'p_interval must not be larger than the time range between p_from and p_to';
      END IF;

      RETURN QUERY
      SELECT
          time_bucket(p_interval, d.time)   AS "timestamp",
          max(d.value)::TEXT                AS "value"
      FROM %1$I.%2$I as d
      WHERE d.time >= p_from AND d.time <= p_to
      GROUP BY 1
      ORDER BY 1 DESC;
    END;
    $body$;
    $func$, p_network, p_metric_name
  );
  EXECUTE format('GRANT EXECUTE ON FUNCTION api.get_%I_agg_%I(interval, timestamptz, timestamptz) TO web_anon;', p_network, p_metric_name);

  EXECUTE format(
    $func$
      CREATE OR REPLACE VIEW api.latest_%1$I_%2$I AS
      SELECT
        d.time         AS "timestamp",
        d.value::TEXT  AS "value"
      FROM %1$I.%2$I as d
      ORDER BY d.time DESC
      LIMIT 1;
    $func$, p_network, p_metric_name
  );
  EXECUTE format('GRANT SELECT ON api.latest_%I_%I TO web_anon;', p_network, p_metric_name);

  EXECUTE FORMAT($func$
    CREATE OR REPLACE FUNCTION api.get_latest_%1$I_%2$I_value()
    RETURNS NUMERIC
    LANGUAGE SQL
    STABLE
    SECURITY DEFINER
    SET search_path = %1$I, common, internal, public
    AS $$
      SELECT t.value::NUMERIC
        FROM api.latest_%1$I_%2$I as t
        LIMIT 1;
    $$;
  $func$, p_network, p_metric_name);

  EXECUTE FORMAT('GRANT EXECUTE ON FUNCTION api.get_latest_%I_%I_value() TO web_anon;', p_network, p_metric_name);

END;
$outer$ LANGUAGE plpgsql VOLATILE;

-- Initialize the cumulative sum metrics
-- These metrics are used to calculate cumulative values over time, not regular metrics
CREATE OR REPLACE FUNCTION internal.initialize_cumsum_metric(p_metric_name TEXT)
RETURNS VOID AS $outer$
BEGIN
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS cumsum');
  EXECUTE format(
    $fmt$
      CREATE TABLE IF NOT EXISTS cumsum.%I (
        "time" TIMESTAMPTZ NOT NULL,
        "tags" JSONB NOT NULL,
        "value" NUMERIC,
        PRIMARY KEY (time, tags)
      )
    $fmt$, p_metric_name
  );

  EXECUTE format(
    $fmt$
      SELECT create_hypertable('cumsum.%I', 'time', if_not_exists => TRUE)
    $fmt$, p_metric_name
  );

  EXECUTE format(
    $fmt$
      SELECT add_retention_policy('cumsum.%I', INTERVAL '1 year', if_not_exists => TRUE)
    $fmt$, p_metric_name
  );

  EXECUTE format(
    $func$
    CREATE OR REPLACE FUNCTION api.get_cumsum_agg_%1$I (
        p_interval INTERVAL,
        p_from TIMESTAMPTZ,
        p_to TIMESTAMPTZ
    )
    RETURNS TABLE (
        "timestamp" TIMESTAMPTZ,
        "value"     TEXT
    )
    LANGUAGE plpgsql STABLE
    STRICT
    SECURITY DEFINER
    SET search_path = cumsum, internal, public
    AS $body$
    BEGIN
      -- Ensure p_from is less than or equal to p_to
      IF p_from > p_to THEN
        RAISE EXCEPTION 'p_from must be less than or equal to p_to';
      END IF;

      -- Ensure p_interval is a positive interval
      IF  p_interval <= INTERVAL '0' THEN
        RAISE EXCEPTION 'p_interval must be a positive interval';
      END IF;

      -- Ensure p_interval is not larger than the time range
      IF p_interval > (p_to - p_from) THEN
        RAISE EXCEPTION 'p_interval must not be larger than the time range between p_from and p_to';
      END IF;

      RETURN QUERY
      WITH raw AS (
        SELECT
          d.time as "time",
          SUM(sum(d.value)) OVER (ORDER BY time) AS cumulative
        FROM cumsum.%1$I as d
        GROUP BY d.time
      ),
      filtered AS (
        SELECT *
        FROM raw
        WHERE time >= p_from AND time <= p_to
      ),
      bucketed AS (
        SELECT
          time_bucket(p_interval, time) AS ts,
          MAX(cumulative)               AS mc
        FROM filtered
        GROUP BY ts
      )
      SELECT
        ts as "timestamp",
        mc::TEXT as "value"
      FROM bucketed
      ORDER BY ts;
    END;
    $body$;
    $func$, p_metric_name
  );
  EXECUTE format('GRANT EXECUTE ON FUNCTION api.get_cumsum_agg_%I(interval, timestamptz, timestamptz) TO web_anon;', p_metric_name);

  EXECUTE format(
    $func$
      CREATE OR REPLACE VIEW api.latest_cumsum_%1$I AS
      SELECT
        d.time         AS "timestamp",
        d.value::TEXT  AS "value"
      FROM cumsum.%1$I as d
      ORDER BY d.time DESC
      LIMIT 1;
    $func$, p_metric_name
  );
  EXECUTE format('GRANT SELECT ON api.latest_cumsum_%I TO web_anon;', p_metric_name);
END;
$outer$ LANGUAGE plpgsql VOLATILE;

COMMIT;
