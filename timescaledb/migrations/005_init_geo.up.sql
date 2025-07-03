BEGIN;

-- Geo coordinates materialized view
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
  last(t.city,         rw.time)
    FILTER (WHERE rw.name='manifest_geo_metadata')  AS city
FROM internal.prometheus_remote_write rw
JOIN internal.prometheus_remote_write_tag t USING (tag_id)
WHERE rw.schema = 'geo'
  AND rw.name  IN (
    'manifest_geo_latitude',
    'manifest_geo_longitude',
    'manifest_geo_metadata'
  )
GROUP BY bucket, t.instance
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
  'geo.latest_coords',
  start_offset => INTERVAL '3 minutes',
  end_offset   => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute'
);

-- Get latest geo coordinates from materialized view
CREATE OR REPLACE FUNCTION api.get_latest_geo_coordinates()
RETURNS TABLE(
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    country_name TEXT,
    city TEXT
) AS $$
SELECT latitude, longitude, country_name, city
FROM geo.latest_coords
WHERE bucket = (SELECT max(bucket) FROM geo.latest_coords);
$$
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = geo;

COMMIT;
