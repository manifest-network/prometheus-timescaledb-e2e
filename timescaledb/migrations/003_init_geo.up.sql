BEGIN;

CREATE SCHEMA IF NOT EXISTS geo;

DO $$
DECLARE tbl text;
BEGIN
  FOR tbl IN (
    VALUES
    ('latitude'),
    ('longitude'),
    ('metadata')
  ) LOOP
    EXECUTE format(
      $fmt$
        CREATE TABLE IF NOT EXISTS geo.manifest_geo_%1$I (
          time  TIMESTAMPTZ NOT NULL,
          tags  JSONB         NOT NULL,
          value NUMERIC,
          PRIMARY KEY (time, tags)
        );
        SELECT create_hypertable('geo.manifest_geo_%1$I', 'time', if_not_exists=>TRUE);
        SELECT add_retention_policy('geo.manifest_geo_%1$I', INTERVAL '1 year', if_not_exists=>TRUE);
        CREATE INDEX IF NOT EXISTS geo_manifest_geo_%1$I_instance_time_desc ON geo.manifest_geo_%1$I (( (tags ->> 'instance') ), time DESC);
      $fmt$, tbl);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Return the latest geo coordinates from the `geo` schema
CREATE OR REPLACE FUNCTION api.get_latest_geo_coordinates()
RETURNS TABLE (
  latitude      NUMERIC,
  longitude     NUMERIC,
  country_name  TEXT,
  city          TEXT
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = geo, internal, public
AS $$
WITH instances AS (
  SELECT DISTINCT (tags->>'instance') AS instance
  FROM manifest_geo_metadata
)
SELECT
  lat.latitude,
  lon.longitude,
  meta.country_name,
  meta.city
FROM instances inst
CROSS JOIN LATERAL (
  SELECT value::NUMERIC AS latitude
  FROM manifest_geo_latitude
  WHERE tags->>'instance' = inst.instance
  ORDER BY time DESC
  LIMIT 1
) AS lat
CROSS JOIN LATERAL (
  SELECT value::NUMERIC AS longitude
  FROM manifest_geo_longitude
  WHERE tags->>'instance' = inst.instance
  ORDER BY time DESC
  LIMIT 1
) AS lon
CROSS JOIN LATERAL (
  SELECT
    tags->>'country_name' AS country_name,
    tags->>'city'         AS city
  FROM manifest_geo_metadata
  WHERE tags->>'instance' = inst.instance
  ORDER BY time DESC
  LIMIT 1
) AS meta
WHERE lat.latitude IS NOT NULL
  AND lon.longitude IS NOT NULL
$$;

GRANT EXECUTE
  ON FUNCTION api.get_latest_geo_coordinates()
  TO web_anon;

COMMIT;
