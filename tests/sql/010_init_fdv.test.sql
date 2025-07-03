BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

SELECT has_function('api', 'get_agg_fdv', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_fdv() exists');

SELECT function_privs_are(
  'api',
  'get_agg_fdv',
  ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_fdv'
);

SELECT has_function('api', 'get_latest_fdv', ARRAY['text'], 'api.get_latest_fdv() exists');

SELECT function_privs_are(
  'api',
  'get_latest_fdv',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_fdv'
);

-- Total supply * PWR conversion factor = FDV
-- 123427004070058399998 * 0.379 = 46778834542552133599.242
SELECT set_eq(
  'SELECT value FROM api.get_agg_fdv(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''46778834542552133599.242'')',
  'api.get_agg_fdv() returns correct 1st row circulating supply value for testnet'
);

-- Total supply * PWR conversion factor = FDV
-- 123427004070058399997 * 0.379 = 46778834542552133598.863
SELECT set_eq(
  'SELECT value FROM api.get_agg_fdv(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''46778834542552133598.863'')',
  'api.get_agg_fdv() returns correct 1st row circulating supply value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_fdv(''testnet'')',
  'VALUES (''46778834542552133599.242'')',
  'api.get_latest_fdv() returns correct circulating supply value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_fdv(''mainnet'')',
  'VALUES (''46778834542552133598.863'')',
  'api.get_latest_fdv() returns correct circulating supply value for mainnet'
);


SELECT * FROM finish();

COMMIT;
