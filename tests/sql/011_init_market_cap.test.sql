BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

SELECT has_function('api', 'get_agg_market_cap', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'], 'api.get_agg_market_cap() exists');

SELECT function_privs_are(
  'api',
  'get_agg_market_cap',
  ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_agg_market_cap'
);

SELECT has_function('api', 'get_latest_market_cap', ARRAY['text'], 'api.get_latest_market_cap() exists');

SELECT function_privs_are(
  'api',
  'get_latest_market_cap',
  ARRAY['text'],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_market_cap'
);

-- (Total supply - Excluded supply - locked Tokens - Locked fees) * PWR conversion factor = Market Cap
-- (123427004070058399998 - 122999999987062065853 - 12000000 - 134244018) * 0.379 = 161834547400184158.133
SELECT set_eq(
  'SELECT value FROM api.get_agg_market_cap(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''161834547400184158.133'')',
  'api.get_agg_market_cap() returns correct 1st row circulating supply value for testnet'
);

-- (Total supply - Excluded supply - locked Tokens - Locked fees) * PWR conversion factor = Market Cap
-- (123427004070058399997 - 122999999987062065852 - 12000002 - 134244017) = 161834547400184157.754
SELECT set_eq(
  'SELECT value FROM api.get_agg_market_cap(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''161834547400184157.754'')',
  'api.get_agg_market_cap() returns correct 1st row circulating supply value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_market_cap(''testnet'')',
  'VALUES (''161834547400184158.133'')',
  'api.get_latest_market_cap() returns correct circulating supply value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_market_cap(''mainnet'')',
  'VALUES (''161834547400184157.754'')',
  'api.get_latest_market_cap() returns correct circulating supply value for mainnet'
);


SELECT * FROM finish();

COMMIT;
