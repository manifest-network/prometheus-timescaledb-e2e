BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(17);

SELECT has_table('internal', 'prometheus_remote_write', 'internal.prometheus_remote_write table exists');
SELECT has_table('internal', 'prometheus_remote_write_tag', 'internal.prometheus_remote_write_tag table exists');

SELECT table_privs_are(
  'internal',
  'prometheus_remote_write',
  'web_anon',
  ARRAY[]::text[],
  'web_anon has no privileges on internal.prometheus_remote_write'
);

SELECT table_privs_are(
  'internal',
  'prometheus_remote_write_tag',
  'web_anon',
  ARRAY[]::text[],
  'web_anon has no privileges on internal.prometheus_remote_write_tag'
);

SELECT has_function('api', 'get_agg_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_metric() exists');

SELECT function_privs_are(
  'api',
  'get_agg_metric',
  ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_metric'
);

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

SELECT ok(
  (SELECT count(*) FROM api.get_agg_metric('node_count', 'common', '1 minute', now() - interval '1 day', now())) > 1,
  'api.get_agg_metric() returns more than one row'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_tokens'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''12000000'')',
  'api.get_agg_metric() returns correct locked_tokens value for testnet (amount tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_fees'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''134244018'')',
  'api.get_agg_metric() returns correct locked_tokens value for testnet (amount tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_total_supply'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''123427004070058399998'')',
  'api.get_agg_metric() returns correct locked_tokens value for testnet (supply tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_excluded_supply'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''122999999987062065853'')',
  'api.get_agg_metric() returns correct locked_tokens value for testnet (excluded_supply tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_tokens'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''12000002'')',
  'api.get_agg_metric() returns correct locked_tokens value for mainnet (amount tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_fees'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''134244017'')',
  'api.get_agg_metric() returns correct locked_tokens value for mainnet (amount tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_total_supply'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''123427004070058399997'')',
  'api.get_agg_metric() returns correct locked_tokens value for mainnet (supply tag)'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_excluded_supply'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''122999999987062065852'')',
  'api.get_agg_metric() returns correct locked_tokens value for mainnet (excluded_supply tag)'
);

SELECT * FROM finish();

COMMIT;
