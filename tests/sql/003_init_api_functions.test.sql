-- Tests for Migration 003: API Functions
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(82);

-- =============================================================================
-- 1. Excluded addresses functions
-- =============================================================================

SELECT has_function('api', 'get_excluded_addresses', ARRAY[]::text[], 'api.get_excluded_addresses() exists');
SELECT function_privs_are('api', 'get_excluded_addresses', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute get_excluded_addresses');

SELECT has_function('api', 'add_excluded_address', ARRAY['text'], 'api.add_excluded_address() exists');
SELECT function_privs_are('api', 'add_excluded_address', ARRAY['text'], 'writer', ARRAY['EXECUTE'],
  'writer can execute add_excluded_address');
SELECT function_privs_are('api', 'add_excluded_address', ARRAY['text'], 'web_anon', ARRAY[]::text[],
  'web_anon cannot execute add_excluded_address');

SELECT has_function('api', 'rm_excluded_address', ARRAY['text'], 'api.rm_excluded_address() exists');
SELECT function_privs_are('api', 'rm_excluded_address', ARRAY['text'], 'writer', ARRAY['EXECUTE'],
  'writer can execute rm_excluded_address');
SELECT function_privs_are('api', 'rm_excluded_address', ARRAY['text'], 'web_anon', ARRAY[]::text[],
  'web_anon cannot execute rm_excluded_address');

-- Test excluded addresses CRUD
INSERT INTO internal.excluded_addresses(value) VALUES ('foo'), ('bar') ON CONFLICT (value) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM internal.excluded_addresses),
  2::BIGINT,
  'two addresses inserted'
);

SELECT results_eq(
  'SELECT value FROM api.get_excluded_addresses() ORDER BY value',
  ARRAY['bar', 'foo'],
  'get_excluded_addresses returns inserted addresses'
);

SELECT api.add_excluded_address('gazooo');
SELECT results_eq(
  'SELECT value FROM api.get_excluded_addresses() ORDER BY value',
  ARRAY['bar', 'foo', 'gazooo'],
  'get_excluded_addresses returns addresses w/ gazooo'
);

SELECT api.rm_excluded_address('gazooo');
SELECT results_eq(
  'SELECT value FROM api.get_excluded_addresses() ORDER BY value',
  ARRAY['bar', 'foo'],
  'get_excluded_addresses returns addresses w/o gazooo'
);

-- =============================================================================
-- 2. Raw metrics aggregation function
-- =============================================================================

SELECT has_function('api', 'get_agg_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_metric() exists');
SELECT function_privs_are('api', 'get_agg_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_metric');

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
  'api.get_agg_metric() returns correct locked_tokens value for testnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_fees'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''134244018'')',
  'api.get_agg_metric() returns correct locked_fees value for testnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_total_supply'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''123427004070058399998'')',
  'api.get_agg_metric() returns correct total_supply value for testnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_excluded_supply'', ''testnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''122999999987062065853'')',
  'api.get_agg_metric() returns correct excluded_supply value for testnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_tokens'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''12000002'')',
  'api.get_agg_metric() returns correct locked_tokens value for mainnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''locked_fees'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''134244017'')',
  'api.get_agg_metric() returns correct locked_fees value for mainnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_total_supply'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''123427004070058399997'')',
  'api.get_agg_metric() returns correct total_supply value for mainnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_metric(''manifest_tokenomics_excluded_supply'', ''mainnet'', ''1 minute'', now() - interval ''1 day'', now())',
  'VALUES (''122999999987062065852'')',
  'api.get_agg_metric() returns correct excluded_supply value for mainnet'
);

-- =============================================================================
-- 3. Cumsum aggregation function
-- =============================================================================

SELECT has_function('api', 'get_agg_cumsum_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_cumsum_metric() exists');
SELECT function_privs_are('api', 'get_agg_cumsum_metric', ARRAY['text', 'text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_cumsum_metric');

SELECT ok(
  (SELECT count(*) FROM api.get_agg_cumsum_metric('system_tcp_sent', 'cumsum', '1 minute', now() - interval '1 day', now())) > 2,
  'api.get_agg_cumsum_metric() returns more than two rows'
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

-- =============================================================================
-- 4. Geo coordinates function
-- =============================================================================

SELECT has_function('api', 'get_latest_geo_coordinates', ARRAY[]::text[], 'api.get_latest_geo_coordinates() exists');
SELECT function_privs_are('api', 'get_latest_geo_coordinates', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute get_latest_geo_coordinates');

SELECT results_eq(
  'SELECT * FROM api.get_latest_geo_coordinates()',
  'VALUES (40.804::DOUBLE PRECISION, -74.012::DOUBLE PRECISION, ''United States'', ''North Bergen'')',
  'get_latest_geo_coordinates() returns fixture values'
);

-- =============================================================================
-- 5. Circulating supply functions
-- =============================================================================

SELECT has_function('api', 'get_agg_circulating_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_circulating_supply() exists');
SELECT function_privs_are('api', 'get_agg_circulating_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_circulating_supply');

SELECT has_function('api', 'get_latest_circulating_supply', ARRAY['text'], 'api.get_latest_circulating_supply() exists');
SELECT function_privs_are('api', 'get_latest_circulating_supply', ARRAY['text'], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_circulating_supply');

-- Total supply - excluded supply - locked tokens - locked fees
-- 123427004070058399998 - 122999999987062065853 - 12000000 - 134244018 = 427004082850090127
SELECT set_eq(
  'SELECT value FROM api.get_agg_circulating_supply(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''427004082850090127'')',
  'api.get_agg_circulating_supply() returns correct value for testnet'
);

-- 123427004070058399997 - 122999999987062065852 - 12000002 - 134244017 = 427004082850090126
SELECT set_eq(
  'SELECT value FROM api.get_agg_circulating_supply(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''427004082850090126'')',
  'api.get_agg_circulating_supply() returns correct value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_circulating_supply(''testnet'')',
  'VALUES (''427004082850090127'')',
  'api.get_latest_circulating_supply() returns correct value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_circulating_supply(''mainnet'')',
  'VALUES (''427004082850090126'')',
  'api.get_latest_circulating_supply() returns correct value for mainnet'
);

-- =============================================================================
-- 6. Burned supply functions
-- =============================================================================

SELECT has_function('api', 'get_agg_burned_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_burned_supply() exists');
SELECT function_privs_are('api', 'get_agg_burned_supply', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_burned_supply');

SELECT has_function('api', 'get_latest_burned_supply', ARRAY['text'], 'api.get_latest_burned_supply() exists');
SELECT function_privs_are('api', 'get_latest_burned_supply', ARRAY['text'], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_burned_supply');

SELECT set_eq(
  'SELECT value FROM api.get_agg_burned_supply(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''4710007'')',
  'api.get_agg_burned_supply() returns correct value for testnet'
);

SELECT set_eq(
  'SELECT value FROM api.get_agg_burned_supply(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''135304300855652060000'')',
  'api.get_agg_burned_supply() returns correct value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_burned_supply(''testnet'')',
  'VALUES (''4710007'')',
  'api.get_latest_burned_supply() returns correct value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_burned_supply(''mainnet'')',
  'VALUES (''135304300855652060000'')',
  'api.get_latest_burned_supply() returns correct value for mainnet'
);

-- =============================================================================
-- 7. FDV functions
-- =============================================================================

SELECT has_function('api', 'get_agg_fdv', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_fdv() exists');
SELECT function_privs_are('api', 'get_agg_fdv', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_fdv');

SELECT has_function('api', 'get_latest_fdv', ARRAY['text'], 'api.get_latest_fdv() exists');
SELECT function_privs_are('api', 'get_latest_fdv', ARRAY['text'], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_fdv');

-- Total supply * PWR conversion factor = FDV
-- 123427004070058399998 * 0.379 = 46778834542552133599.242
SELECT set_eq(
  'SELECT value FROM api.get_agg_fdv(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''46778834542552133599.242'')',
  'api.get_agg_fdv() returns correct value for testnet'
);

-- 123427004070058399997 * 0.379 = 46778834542552133598.863
SELECT set_eq(
  'SELECT value FROM api.get_agg_fdv(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''46778834542552133598.863'')',
  'api.get_agg_fdv() returns correct value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_fdv(''testnet'')',
  'VALUES (''46778834542552133599.242'')',
  'api.get_latest_fdv() returns correct value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_fdv(''mainnet'')',
  'VALUES (''46778834542552133598.863'')',
  'api.get_latest_fdv() returns correct value for mainnet'
);

-- =============================================================================
-- 8. Market cap functions
-- =============================================================================

SELECT has_function('api', 'get_agg_market_cap', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'api.get_agg_market_cap() exists');
SELECT function_privs_are('api', 'get_agg_market_cap', ARRAY['text', 'interval', 'timestamptz', 'timestamptz'],
  'web_anon', ARRAY['EXECUTE'], 'web_anon can execute api.get_agg_market_cap');

SELECT has_function('api', 'get_latest_market_cap', ARRAY['text'], 'api.get_latest_market_cap() exists');
SELECT function_privs_are('api', 'get_latest_market_cap', ARRAY['text'], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_latest_market_cap');

-- (Total supply - Excluded supply - locked Tokens - Locked fees) * PWR conversion factor = Market Cap
-- (123427004070058399998 - 122999999987062065853 - 12000000 - 134244018) * 0.379 = 161834547400184158.133
SELECT set_eq(
  'SELECT value FROM api.get_agg_market_cap(''testnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''161834547400184158.133'')',
  'api.get_agg_market_cap() returns correct value for testnet'
);

-- (123427004070058399997 - 122999999987062065852 - 12000002 - 134244017) * 0.379 = 161834547400184157.754
SELECT set_eq(
  'SELECT value FROM api.get_agg_market_cap(''mainnet'', ''1 minute'', now() - interval ''1 day'', now()) LIMIT 1',
  'VALUES (''161834547400184157.754'')',
  'api.get_agg_market_cap() returns correct value for mainnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_market_cap(''testnet'')',
  'VALUES (''161834547400184158.133'')',
  'api.get_latest_market_cap() returns correct value for testnet'
);

SELECT results_eq(
  'SELECT value FROM api.get_latest_market_cap(''mainnet'')',
  'VALUES (''161834547400184157.754'')',
  'api.get_latest_market_cap() returns correct value for mainnet'
);

-- =============================================================================
-- 9. Token metrics helper functions
-- =============================================================================

SELECT has_function('api', 'get_all_latest_token_metrics', ARRAY['text'], 'api.get_all_latest_token_metrics() exists');
SELECT function_privs_are('api', 'get_all_latest_token_metrics', ARRAY['text'], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_token_metrics');

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

-- =============================================================================
-- 10. Get all latest metrics functions
-- =============================================================================

SELECT has_function('api', 'get_all_latest_common_metrics', ARRAY[]::text[], 'api.get_all_latest_common_metrics() exists');
SELECT has_function('api', 'get_all_latest_testnet_metrics', ARRAY[]::text[], 'api.get_all_latest_testnet_metrics() exists');
SELECT has_function('api', 'get_all_latest_mainnet_metrics', ARRAY[]::text[], 'api.get_all_latest_mainnet_metrics() exists');
SELECT has_function('api', 'get_all_latest_cumsum_metrics', ARRAY[]::text[], 'api.get_all_latest_cumsum_metrics() exists');

SELECT function_privs_are('api', 'get_all_latest_common_metrics', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_common_metrics');
SELECT function_privs_are('api', 'get_all_latest_testnet_metrics', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_testnet_metrics');
SELECT function_privs_are('api', 'get_all_latest_mainnet_metrics', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_mainnet_metrics');
SELECT function_privs_are('api', 'get_all_latest_cumsum_metrics', ARRAY[]::text[], 'web_anon', ARRAY['EXECUTE'],
  'web_anon can execute api.get_all_latest_cumsum_metrics');

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_common_metrics()',
  'VALUES (''node_count'', ''3''), (''talib_mfx_power_conversion'', ''0.379'')',
  'api.get_all_latest_common_metrics() returns correct values'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_testnet_metrics()',
  'VALUES
    (''locked_fees'', ''134244018''),
    (''locked_tokens'', ''12000000''),
    (''manifest_tokenomics_excluded_supply'', ''122999999987062065853''),
    (''manifest_tokenomics_total_supply'', ''123427004070058399998''),
    (''total_mfx_burned'', ''4710007'')',
  'api.get_all_latest_testnet_metrics() returns correct values'
);

SELECT results_eq(
  'SELECT table_name, value FROM api.get_all_latest_mainnet_metrics()',
  'VALUES
    (''locked_fees'', ''134244017''),
    (''locked_tokens'', ''12000002''),
    (''manifest_tokenomics_excluded_supply'', ''122999999987062065852''),
    (''manifest_tokenomics_total_supply'', ''123427004070058399997''),
    (''total_mfx_burned'', ''135304300855652060000'')',
  'api.get_all_latest_mainnet_metrics() returns correct values'
);

SELECT results_eq(
  'SELECT COUNT(*) FROM api.get_all_latest_cumsum_metrics() WHERE (value::BIGINT % 60) <> 0',
  'VALUES (0::BIGINT)',
  'api.get_all_latest_cumsum_metrics() returns multiples of 60'
);

SELECT * FROM finish();

COMMIT;
