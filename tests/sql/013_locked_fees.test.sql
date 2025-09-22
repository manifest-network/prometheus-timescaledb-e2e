BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

SELECT has_function('api', 'get_agg_locked_fees', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_locked_fees() exists');

SELECT function_privs_are(
  'api',
  'get_agg_locked_fees',
  ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_locked_fees'
);

SELECT has_function('api', 'get_latest_locked_fees', ARRAY['text'], 'api.get_latest_locked_fees() exists');

SELECT function_privs_are(
  'api',
  'get_latest_locked_fees',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_locked_fees'
);

-- Locked fees
-- 134244018
SELECT set_eq(
  'SELECT value FROM api.get_agg_locked_fees(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''134244018'')',
  'api.get_agg_locked_fees() returns correct 1st row locked fees supply value for testnet'
);

-- Locked fees
-- 134244017
SELECT set_eq(
  'SELECT value FROM api.get_agg_locked_fees(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''134244017'')',
  'api.get_agg_locked_fees() returns correct 1st row locked fees supply value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_locked_fees(''testnet'')',
  'VALUES (''134244018'')',
  'api.get_latest_locked_fees() returns correct locked fees supply value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_locked_fees(''mainnet'')',
  'VALUES (''134244017'')',
  'api.get_latest_locked_fees() returns correct locked fees supply value for mainnet'
);

SELECT * FROM finish();

COMMIT;