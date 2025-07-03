BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(12);

SELECT has_function('api', 'get_all_latest_common_metrics', ARRAY[]::text[], 'api.get_all_latest_common_metrics() exists');
SELECT has_function('api', 'get_all_latest_testnet_metrics', ARRAY[]::text[], 'api.get_all_latest_testnet_metrics() exists');
SELECT has_function('api', 'get_all_latest_mainnet_metrics', ARRAY[]::text[], 'api.get_all_latest_mainnet_metrics() exists');
SELECT has_function('api', 'get_all_latest_cumsum_metrics', ARRAY[]::text[], 'api.get_all_latest_cumsum_metrics() exists');

SELECT function_privs_are(
  'api',
  'get_all_latest_common_metrics',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_common_metrics'
);

SELECT function_privs_are(
  'api',
  'get_all_latest_testnet_metrics',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_testnet_metrics'
);

SELECT function_privs_are(
  'api',
  'get_all_latest_mainnet_metrics',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_mainnet_metrics'
);

SELECT function_privs_are(
  'api',
  'get_all_latest_cumsum_metrics',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_cumsum_metrics'
);

SELECT results_eq(
  'SELECT value FROM api.get_all_latest_common_metrics()',
  'VALUES (''3'')',
  'api.get_all_latest_common_metrics() returns correct node_count value'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_testnet_metrics()',
  'VALUES
          (''locked_fees'', ''134244018''),
          (''locked_tokens'', ''12000000''),
          (''manifest_tokenomics_excluded_supply'', ''122999999987062065853''),
          (''manifest_tokenomics_total_supply'', ''123427004070058399998'')',
  'api.get_all_latest_testnet_metrics() returns correct values'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_mainnet_metrics()',
  'VALUES
          (''locked_fees'', ''134244017''),
          (''locked_tokens'', ''12000002''),
          (''manifest_tokenomics_excluded_supply'', ''122999999987062065852''),
          (''manifest_tokenomics_total_supply'', ''123427004070058399997'')',
  'api.get_all_latest_mainnet_metrics() returns correct values'
);

SELECT results_eq(
  'SELECT COUNT(*) FROM api.get_all_latest_cumsum_metrics() WHERE (value::BIGINT % 60) <> 0',
  'VALUES (0::BIGINT)',
  'api.get_all_latest_cumsum_metrics() returns multiples of 60'
);

SELECT * FROM finish();

COMMIT;
