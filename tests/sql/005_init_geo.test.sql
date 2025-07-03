BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(4);

-- view exists
SELECT has_view('geo', 'latest_coords', 'view latest_coords exists');

-- function existence and privileges
SELECT has_function('api', 'get_latest_geo_coordinates', ARRAY[]::text[], 'api.get_latest_geo_coordinates() exists');
SELECT function_privs_are(
  'api',
  'get_latest_geo_coordinates',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute get_latest_geo_coordinates'
);

SELECT results_eq(
  'SELECT * FROM api.get_latest_geo_coordinates()',
  'VALUES (40.804::DOUBLE PRECISION, -74.012::DOUBLE PRECISION, ''United States'', ''North Bergen'')',
  'get_latest_geo_coordinates() returns fixture values'
);

SELECT * FROM finish();

COMMIT;
