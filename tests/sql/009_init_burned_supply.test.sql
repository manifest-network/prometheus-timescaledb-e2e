BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

SELECT has_function('api', 'get_agg_burned_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_burned_supply() exists');

SELECT function_privs_are(
  'api',
  'get_agg_burned_supply',
  ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_burned_supply'
);

SELECT has_function('api', 'get_latest_burned_supply', ARRAY['text'], 'api.get_latest_burned_supply() exists');

SELECT function_privs_are(
  'api',
  'get_latest_burned_supply',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_burned_supply'
);

-- Total burned supply + Locked Fees = Burned Supply
-- 4710007 + 134244018 = 138954025
SELECT set_eq(
  'SELECT value FROM api.get_agg_burned_supply(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''138954025'')',
  'api.get_agg_burned_supply() returns correct 1st row circulating supply value for testnet'
);

-- Total burned supply + Locked Fees = Burned Supply
-- 135304300855652060000 + 134244017 = 135304300855786304017
SELECT set_eq(
  'SELECT value FROM api.get_agg_burned_supply(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''135304300855786304017'')',
  'api.get_agg_burned_supply() returns correct 1st row circulating supply value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_burned_supply(''testnet'')',
  'VALUES (''138954025'')',
  'api.get_latest_burned_supply() returns correct circulating supply value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_burned_supply(''mainnet'')',
  'VALUES (''135304300855786304017'')',
  'api.get_latest_burned_supply() returns correct circulating supply value for mainnet'
);

SELECT * FROM finish();

COMMIT;
