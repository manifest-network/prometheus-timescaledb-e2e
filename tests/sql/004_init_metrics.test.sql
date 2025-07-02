BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(5);

SELECT has_table('internal', 'prometheus_remote_write', 'prometheus_remote_write table exists');
SELECT has_table('internal', 'prometheus_remote_write_tag', 'prometheus_remote_write_tag table exists');

SELECT has_function('api', 'get_agg_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_metric() exists');

SELECT results_eq(
  'SELECT name, value FROM internal.prometheus_remote_write where name=''node_count'' limit 1',
  'VALUES (''node_count'', 3::NUMERIC)',
  'internal.prometheus_remote_write has correct node_count value'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''node_count'', ''common'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''3'')',
  'api.get_agg_metric() returns correct node_count value'
);

SELECT * FROM finish();

COMMIT;
