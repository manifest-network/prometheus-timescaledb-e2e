BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(12);

SELECT has_table('cumsum', 'prometheus_remote_write', 'cumsum.prometheus_remote_write table exists');
SELECT has_table('cumsum', 'prometheus_remote_write_tag', 'cumsum.prometheus_remote_write_tag table exists');

SELECT table_privs_are(
  'cumsum',
  'prometheus_remote_write',
  'web_anon',
  ARRAY[]::text[],
  'web_anon has no privileges on cumsum.prometheus_remote_write'
);

SELECT table_privs_are(
  'cumsum',
  'prometheus_remote_write_tag',
  'web_anon',
  ARRAY[]::text[],
  'web_anon has no privileges on cumsum.prometheus_remote_write_tag'
);

-- has_materialized_view doesn't work. TimescaleDB doesn't support it?
SELECT has_view(
  'cumsum',
  'all_metrics_minute',
  'cumsum.all_metrics_minute is a materialized view'
);

SELECT has_function('api', 'get_agg_cumsum_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_cumsum_metric() exists');

SELECT function_privs_are(
  'api',
  'get_agg_cumsum_metric',
  ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_cumsum_metric'
);

SELECT ok(
  (SELECT count(*) FROM api.get_agg_cumsum_metric('system_tcp_sent', 'cumsum', '1 minute', now() - interval '1 day', now())) > 2,
  'api.get_agg_cumsum_metric() returns more than three row'
);

SELECT results_eq(
  'SELECT value FROM api.get_agg_cumsum_metric(''system_tcp_sent'', ''cumsum'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''60'')',
  'api.get_agg_cumsum_metric() returns correct 1st row system_tcp_sent value'
);

SELECT results_eq(
  'SELECT value FROM api.get_agg_cumsum_metric(''system_tcp_sent'', ''cumsum'', ''1 minute'', now() - interval ''1 day'', now()) OFFSET 1 LIMIT 1',
  'VALUES (''120'')',
  'api.get_agg_cumsum_metric() returns correct 2nd row system_tcp_sent value'
);

SELECT results_eq(
  'SELECT value FROM api.get_agg_cumsum_metric(''system_tcp_sent'', ''cumsum'', ''1 minute'', now() - interval ''1 day'', now()) OFFSET 2 LIMIT 1',
  'VALUES (''180'')',
  'api.get_agg_cumsum_metric() returns correct 3rd row system_tcp_sent value'
);

SELECT * FROM finish();

COMMIT;
