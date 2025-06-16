BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(24);

-- schema exists
SELECT has_schema('geo', 'schema geo exists');

-- tables exist
SELECT has_table('geo', 'manifest_geo_latitude', 'latitude table exists');
SELECT has_table('geo', 'manifest_geo_longitude', 'longitude table exists');
SELECT has_table('geo', 'manifest_geo_metadata', 'metadata table exists');

-- columns for each table
SELECT has_column('geo', 'manifest_geo_latitude', 'time', 'latitude.time exists');
SELECT has_column('geo', 'manifest_geo_latitude', 'tags', 'latitude.tags exists');
SELECT has_column('geo', 'manifest_geo_latitude', 'value', 'latitude.value exists');

SELECT has_column('geo', 'manifest_geo_longitude', 'time', 'longitude.time exists');
SELECT has_column('geo', 'manifest_geo_longitude', 'tags', 'longitude.tags exists');
SELECT has_column('geo', 'manifest_geo_longitude', 'value', 'longitude.value exists');

SELECT has_column('geo', 'manifest_geo_metadata', 'time', 'metadata.time exists');
SELECT has_column('geo', 'manifest_geo_metadata', 'tags', 'metadata.tags exists');
SELECT has_column('geo', 'manifest_geo_metadata', 'value', 'metadata.value exists');

-- primary keys
SELECT has_pk('geo', 'manifest_geo_latitude', 'latitude PK(time,tags) exists');
SELECT has_pk('geo', 'manifest_geo_longitude', 'longitude PK(time,tags) exists');
SELECT has_pk('geo', 'manifest_geo_metadata', 'metadata PK(time,tags) exists');

-- indexes on (instance) and time desc
SELECT has_index('geo', 'manifest_geo_latitude', 'geo_manifest_geo_latitude_instance_time_desc', 'latitude index exists');
SELECT has_index('geo', 'manifest_geo_longitude', 'geo_manifest_geo_longitude_instance_time_desc', 'longitude index exists');
SELECT has_index('geo', 'manifest_geo_metadata', 'geo_manifest_geo_metadata_instance_time_desc', 'metadata index exists');

-- function existence and privileges
SELECT has_function('api', 'get_latest_geo_coordinates', ARRAY[]::text[], 'get_latest_geo_coordinates() exists');
SELECT function_privs_are(
  'api',
  'get_latest_geo_coordinates',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute get_latest_geo_coordinates'
);

INSERT INTO geo.manifest_geo_latitude(time, tags, value) VALUES
  ('2023-01-01T00:00:00Z', '{"instance": "foo", "country_name": "Canada", "city": "Nowhere"}'::JSONB, 10.0),
  ('2023-01-02T00:00:00Z', '{"instance": "bar", "country_name": "Canada", "city": "Plum"}'::JSONB, 20.0) ON CONFLICT (time, tags) DO NOTHING;
INSERT INTO geo.manifest_geo_longitude(time, tags, value) VALUES
  ('2023-01-01T00:00:00Z', '{"instance": "foo", "country_name": "Canada", "city": "Nowhere"}'::JSONB, 30.0),
  ('2023-01-02T00:00:00Z', '{"instance": "bar", "country_name": "Canada", "city": "Plum"}'::JSONB, 40.0) ON CONFLICT (time, tags) DO NOTHING;
INSERT INTO geo.manifest_geo_metadata(time, tags, value) VALUES
  ('2023-01-01T00:00:00Z', '{"instance": "foo", "country_name": "Canada", "city": "Nowhere"}'::JSONB, 1),
  ('2023-01-02T00:00:00Z', '{"instance": "bar", "country_name": "Canada", "city": "Plum"}'::JSONB, 1) ON CONFLICT (time, tags) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM geo.manifest_geo_latitude),
  2::BIGINT,
  'two latitude rows inserted'
);
SELECT is(
  (SELECT count(*) FROM geo.manifest_geo_longitude),
  2::BIGINT,
  'two longitude rows inserted'
);

SELECT results_eq(
  'SELECT * FROM api.get_latest_geo_coordinates()',
  $$VALUES (20.0, 40.0, 'Canada', 'Plum'), (10.0, 30.0, 'Canada', 'Nowhere')$$,
  'get_latest_geo_coordinates returns geo data');


SELECT * FROM finish();

COMMIT;
