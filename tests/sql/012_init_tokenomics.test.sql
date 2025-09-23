BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(4);

SELECT has_function('api', 'get_all_latest_token_metrics', ARRAY['text'], 'api.get_all_latest_token_metrics() exists');

SELECT function_privs_are(
  'api',
  'get_all_latest_token_metrics',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_token_metrics'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_token_metrics(''testnet'')',
  'VALUES
    (''circulating_supply'', ''427004082850090127''),
    (''fdv'', ''46778834542552133599.242''),
    (''market_cap'', ''161834547400184158.133'')',
  'api.get_all_latest_token_metrics() returns correct values for testnet'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_token_metrics(''mainnet'')',
  'VALUES
    (''circulating_supply'', ''427004082850090126''),
    (''fdv'', ''46778834542552133598.863''),
    (''market_cap'', ''161834547400184157.754'')',
  'api.get_all_latest_token_metrics() returns correct values for mainnet'
);

SELECT * FROM finish();

COMMIT;
