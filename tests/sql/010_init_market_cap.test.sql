BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(24);

-- existence checks
SELECT has_function('api','get_testnet_market_cap',   ARRAY['interval','timestamptz','timestamptz'], 'get_testnet_market_cap() exists');
SELECT has_function('api','get_mainnet_market_cap',   ARRAY['interval','timestamptz','timestamptz'], 'get_mainnet_market_cap() exists');
SELECT has_view    ('api','latest_testnet_market_cap',                                    'latest_testnet_market_cap view exists');
SELECT has_view    ('api','latest_mainnet_market_cap',                                    'latest_mainnet_market_cap view exists');
SELECT has_function('api','get_latest_testnet_market_cap', ARRAY[]::text[],               'get_latest_testnet_market_cap() exists');
SELECT has_function('api','get_latest_mainnet_market_cap', ARRAY[]::text[],               'get_latest_mainnet_market_cap() exists');
SELECT has_function('api','get_latest_testnet_market_cap_value', ARRAY[]::text[],         'get_latest_testnet_market_cap_value() exists');
SELECT has_function('api','get_latest_mainnet_market_cap_value', ARRAY[]::text[],         'get_latest_mainnet_market_cap_value() exists');

-- empty-data behavior (testnet)
SELECT is(
  (SELECT count(*) FROM api.get_testnet_market_cap(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_testnet_market_cap() returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.latest_testnet_market_cap),
  0::BIGINT,
  'latest_testnet_market_cap view returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_testnet_market_cap()),
  0::BIGINT,
  'get_latest_testnet_market_cap() returns no rows when empty'
);
SELECT is(
  (SELECT api.get_latest_testnet_market_cap_value()),
  NULL,
  'get_latest_testnet_market_cap_value() returns NULL when empty'
);

-- empty-data behavior (mainnet)
SELECT is(
  (SELECT count(*) FROM api.get_mainnet_market_cap(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_mainnet_market_cap() returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.latest_mainnet_market_cap),
  0::BIGINT,
  'latest_mainnet_market_cap view returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_mainnet_market_cap()),
  0::BIGINT,
  'get_latest_mainnet_market_cap() returns no rows when empty'
);
SELECT is(
  (SELECT api.get_latest_mainnet_market_cap_value()),
  NULL,
  'get_latest_mainnet_market_cap_value() returns NULL when empty'
);

-- capture two reference timestamps
SELECT
  quote_literal(now() - INTERVAL '1 day')  AS yesterday,
  quote_literal(now() - INTERVAL '2 days') AS yesterday2
\gset

-- testnet sample data
INSERT INTO tmp_testnet.manifest_tokenomics_total_supply (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}'::JSONB,'100'),
         (:yesterday2::timestamptz,'{}'::JSONB,'200');
INSERT INTO tmp_testnet.manifest_tokenomics_excluded_supply (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','10'),
         (:yesterday2::timestamptz,'{}','20');
INSERT INTO tmp_testnet.locked_tokens (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','5'),
         (:yesterday2::timestamptz,'{}','10');
INSERT INTO tmp_testnet.locked_fees (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','2'),
         (:yesterday2::timestamptz,'{}','4');
INSERT INTO common.talib_mfx_power_conversion (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','2'),
         (:yesterday2::timestamptz,'{}','3');
COMMIT;

-- refresh all aggregates
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply',    now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_tokens',                      now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees',                        now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());

BEGIN;
-- range query
SELECT results_eq(
  'SELECT * FROM api.get_testnet_market_cap(interval ''1 day'', '':yesterday''::timestamptz - interval ''3 days'', now())',
  'VALUES
    (date_trunc(''day'',':yesterday'::timestamptz), ''16.6''),
    (date_trunc(''day'',':yesterday2'::timestamptz), ''49.8'')',
  'get_testnet_market_cap() returns correct values'
);
-- latest view
SELECT results_eq(
  'SELECT * FROM api.latest_testnet_market_cap',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''16.6'')',
  'latest_testnet_market_cap returns most recent row'
);
-- latest function
SELECT results_eq(
  'SELECT * FROM api.get_latest_testnet_market_cap()',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''16.6'')',
  'get_latest_testnet_market_cap() returns most recent row'
);
-- latest scalar
SELECT is(
  (SELECT api.get_latest_testnet_market_cap_value()),
  16.6::NUMERIC,
  'get_latest_testnet_market_cap_value() returns numeric value'
);

-- cleanup testnet
DELETE FROM tmp_testnet.manifest_tokenomics_total_supply;
DELETE FROM tmp_testnet.manifest_tokenomics_excluded_supply;
DELETE FROM tmp_testnet.locked_tokens;
DELETE FROM tmp_testnet.locked_fees;
DELETE FROM testnet.manifest_tokenomics_total_supply;
DELETE FROM testnet.manifest_tokenomics_excluded_supply;
DELETE FROM testnet.locked_tokens;
DELETE FROM testnet.locked_fees;
DELETE FROM common.talib_mfx_power_conversion;

COMMIT;

CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply',    now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_tokens',                      now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees',                        now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());

BEGIN;

-- mainnet sample data
INSERT INTO tmp_mainnet.manifest_tokenomics_total_supply (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','300'),
         (:yesterday2::timestamptz,'{}','400');
INSERT INTO tmp_mainnet.manifest_tokenomics_excluded_supply (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','30'),
         (:yesterday2::timestamptz,'{}','40');
INSERT INTO tmp_mainnet.locked_tokens (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','15'),
         (:yesterday2::timestamptz,'{}','20');
INSERT INTO tmp_mainnet.locked_fees (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','3'),
         (:yesterday2::timestamptz,'{}','4');
INSERT INTO common.talib_mfx_power_conversion (time,tags,value)
  VALUES (:yesterday::timestamptz,'{}','4'),
         (:yesterday2::timestamptz,'{}','5');
COMMIT;

-- refresh all aggregates for mainnet
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply',    now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_tokens',                      now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees',                        now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());

BEGIN;
SELECT results_eq(
  'SELECT * FROM api.get_mainnet_market_cap(interval ''1 day'', '':yesterday''::timestamptz - interval ''3 days'', now())',
  'VALUES
    (date_trunc(''day'',':yesterday'::timestamptz), ''100.8''),
    (date_trunc(''day'',':yesterday2'::timestamptz), ''168'')',
  'get_mainnet_market_cap() returns correct values'
);
SELECT results_eq(
  'SELECT * FROM api.latest_mainnet_market_cap',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''100.8'')',
  'latest_mainnet_market_cap returns most recent row'
);
SELECT results_eq(
  'SELECT * FROM api.get_latest_mainnet_market_cap()',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''100.8'')',
  'get_latest_mainnet_market_cap() returns most recent row'
);
SELECT is(
  (SELECT api.get_latest_mainnet_market_cap_value()),
  100.8::NUMERIC,
  'get_latest_mainnet_market_cap_value() returns numeric value'
);

-- cleanup mainnet
DELETE FROM tmp_mainnet.manifest_tokenomics_total_supply;
DELETE FROM tmp_mainnet.manifest_tokenomics_excluded_supply;
DELETE FROM tmp_mainnet.locked_tokens;
DELETE FROM tmp_mainnet.locked_fees;
DELETE FROM mainnet.manifest_tokenomics_total_supply;
DELETE FROM mainnet.manifest_tokenomics_excluded_supply;
DELETE FROM mainnet.locked_tokens;
DELETE FROM mainnet.locked_fees;
DELETE FROM common.talib_mfx_power_conversion;
COMMIT;

CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply',    now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_tokens',                      now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees',                        now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());

BEGIN;
SELECT * FROM finish();
COMMIT;
