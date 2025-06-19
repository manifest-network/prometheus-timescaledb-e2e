BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(18);

-- existence checks
SELECT has_function('api','get_testnet_fdv',   ARRAY['interval','timestamptz','timestamptz'], 'get_testnet_fdv() exists');
SELECT has_function('api','get_mainnet_fdv',   ARRAY['interval','timestamptz','timestamptz'], 'get_mainnet_fdv() exists');
SELECT has_view    ('api','latest_testnet_fdv',                                    'latest_testnet_fdv view exists');
SELECT has_view    ('api','latest_mainnet_fdv',                                    'latest_mainnet_fdv view exists');
SELECT has_function('api','get_latest_testnet_fdv', ARRAY[]::text[],               'get_latest_testnet_fdv() exists');
SELECT has_function('api','get_latest_mainnet_fdv', ARRAY[]::text[],               'get_latest_mainnet_fdv() exists');

-- empty-data behavior
SELECT is(
  (SELECT count(*) FROM api.get_testnet_fdv(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_testnet_fdv() returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.latest_testnet_fdv),
  0::BIGINT,
  'latest_testnet_fdv view returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_testnet_fdv()),
  0::BIGINT,
  'get_latest_testnet_fdv() returns no rows when empty'
);

SELECT is(
  (SELECT count(*) FROM api.get_mainnet_fdv(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_mainnet_fdv() returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.latest_mainnet_fdv),
  0::BIGINT,
  'latest_mainnet_fdv view returns no rows when empty'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_mainnet_fdv()),
  0::BIGINT,
  'get_latest_mainnet_fdv() returns no rows when empty'
);

-- capture two reference timestamps
SELECT
  quote_literal(now() - INTERVAL '1 day')  AS yesterday,
  quote_literal(now() - INTERVAL '2 days') AS yesterday2
\gset

-- testnet sample data
INSERT INTO tmp_testnet.manifest_tokenomics_total_supply (time, tags, value)
  VALUES
    (:yesterday::timestamptz, '{}'::JSONB, '100'),
    (:yesterday2::timestamptz, '{}'::JSONB, '200');
INSERT INTO common.talib_mfx_power_conversion (time, tags, value)
  VALUES
    (:yesterday::timestamptz, '{}'::JSONB, '2'),
    (:yesterday2::timestamptz, '{}'::JSONB, '3');
COMMIT;

-- refresh both aggregates
CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',              now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply', now() - INTERVAL '4 days', now());

BEGIN;
-- range query for FDV = total_supply * (conversion / 10)
SELECT results_eq(
  'SELECT * FROM api.get_testnet_fdv(interval ''1 day'', '':yesterday''::timestamptz - interval ''3 days'', now())',
  'VALUES
     (date_trunc(''day'',':yesterday'::timestamptz), ''20''),
     (date_trunc(''day'',':yesterday2'::timestamptz), ''60'')',
  'get_testnet_fdv() returns correct values'
);

-- latest view
SELECT results_eq(
  'SELECT * FROM api.latest_testnet_fdv',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''20'')',
  'latest_testnet_fdv view returns most recent row'
);

-- latest function
SELECT results_eq(
  'SELECT * FROM api.get_latest_testnet_fdv()',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''20'')',
  'get_latest_testnet_fdv() returns most recent row'
);

-- cleanup testnet data
DELETE FROM tmp_testnet.manifest_tokenomics_total_supply;
DELETE FROM testnet.manifest_tokenomics_total_supply;
DELETE FROM common.talib_mfx_power_conversion;
COMMIT;

CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply',  now() - INTERVAL '4 days', now());

BEGIN;
-- mainnet sample data
INSERT INTO tmp_mainnet.manifest_tokenomics_total_supply (time, tags, value)
  VALUES
    (:yesterday::timestamptz, '{}'::JSONB, '300'),
    (:yesterday2::timestamptz, '{}'::JSONB, '400');
INSERT INTO common.talib_mfx_power_conversion (time, tags, value)
  VALUES
    (:yesterday::timestamptz, '{}'::JSONB, '4'),
    (:yesterday2::timestamptz, '{}'::JSONB, '5');
COMMIT;

CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply',  now() - INTERVAL '4 days', now());

BEGIN;
SELECT results_eq(
  'SELECT * FROM api.get_mainnet_fdv(interval ''1 day'', '':yesterday''::timestamptz - interval ''3 days'', now())',
  'VALUES
     (date_trunc(''day'',':yesterday'::timestamptz), ''120''),
     (date_trunc(''day'',':yesterday2'::timestamptz), ''200'')',
  'get_mainnet_fdv() returns correct values'
);

SELECT results_eq(
  'SELECT * FROM api.latest_mainnet_fdv',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''120'')',
  'latest_mainnet_fdv view returns most recent row'
);

SELECT results_eq(
  'SELECT * FROM api.get_latest_mainnet_fdv()',
  'VALUES (date_trunc(''minute'',':yesterday'::timestamptz), ''120'')',
  'get_latest_mainnet_fdv() returns most recent row'
);

-- cleanup mainnet data
DELETE FROM tmp_mainnet.manifest_tokenomics_total_supply;
DELETE FROM mainnet.manifest_tokenomics_total_supply;
DELETE FROM common.talib_mfx_power_conversion;
COMMIT;

CALL refresh_continuous_aggregate('common.cagg_mfx_power_conversion',               now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply',  now() - INTERVAL '4 days', now());

BEGIN;
SELECT * FROM finish();
COMMIT;
