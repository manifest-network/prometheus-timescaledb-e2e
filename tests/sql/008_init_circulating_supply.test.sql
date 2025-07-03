BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

SELECT has_function('api', 'get_agg_circulating_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_circulating_supply() exists');

SELECT function_privs_are(
  'api',
  'get_agg_circulating_supply',
  ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_circulating_supply'
);

SELECT has_function('api', 'get_latest_circulating_supply', ARRAY['text'], 'api.get_latest_circulating_supply() exists');

SELECT function_privs_are(
  'api',
  'get_latest_circulating_supply',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_circulating_supply'
);


-- Total supply - excluded supply - locked tokens - locked fees
-- 123427004070058399998 - 122999999987062065853 - 12000000 - 134244018 = 427004082850090127
SELECT set_eq(
  'SELECT value FROM api.get_agg_circulating_supply(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''427004082850090127'')',
  'api.get_agg_circulating_supply() returns correct 1st row circulating supply value for testnet'
);

-- Total supply - excluded supply - locked tokens - locked fees
-- 123427004070058399997 - 122999999987062065852 - 12000002 - 134244017 = 427004082850090126
SELECT set_eq(
  'SELECT value FROM api.get_agg_circulating_supply(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''427004082850090126'')',
  'api.get_agg_circulating_supply() returns correct 1st row circulating supply value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_circulating_supply(''testnet'')',
  'VALUES (''427004082850090127'')',
  'api.get_latest_circulating_supply() returns correct circulating supply value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_circulating_supply(''mainnet'')',
  'VALUES (''427004082850090126'')',
  'api.get_latest_circulating_supply() returns correct circulating supply value for mainnet'
);

SELECT * FROM finish();

COMMIT;
