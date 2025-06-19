BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(20);

SELECT
  quote_literal(now() - INTERVAL '1 day') AS yesterday,
  quote_literal(now() - INTERVAL '2 days') AS yesterday2
\gset


-- existence checks
SELECT has_function('api','get_testnet_circulating_supply', ARRAY['interval','timestamptz','timestamptz'], 'get_testnet_circulating_supply() exists');
SELECT has_function('api','get_mainnet_circulating_supply', ARRAY['interval','timestamptz','timestamptz'], 'get_mainnet_circulating_supply() exists');
SELECT has_view('api','latest_testnet_circulating_supply', 'latest_testnet_circulating_supply view exists');
SELECT has_view('api','latest_mainnet_circulating_supply', 'latest_mainnet_circulating_supply view exists');
SELECT has_function('api','get_latest_testnet_circulating_supply', ARRAY[]::text[], 'get_latest_testnet_circulating_supply() exists');
SELECT has_function('api','get_latest_mainnet_circulating_supply', ARRAY[]::text[], 'get_latest_mainnet_circulating_supply() exists');
SELECT has_function('api','get_latest_testnet_circulating_supply_value', ARRAY[]::text[], 'get_latest_testnet_circulating_supply_value() exists');
SELECT has_function('api','get_latest_mainnet_circulating_supply_value', ARRAY[]::text[], 'get_latest_mainnet_circulating_supply_value() exists');

-- behavior with no underlying data
SELECT is(
  (SELECT count(*) FROM api.get_testnet_circulating_supply(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_testnet_circulating_supply() returns no rows on empty data'
);

SELECT is(
  (SELECT count(*) FROM api.get_latest_testnet_circulating_supply()),
  0::BIGINT,
  'get_latest_testnet_circulating_supply() returns no rows on empty data'
);

SELECT is(
  (SELECT api.get_latest_testnet_circulating_supply_value()),
  NULL,
  'get_latest_testnet_circulating_supply_value() returns NULL on empty data'
);

SELECT is(
  (SELECT count(*) FROM api.get_mainnet_circulating_supply(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_mainnet_circulating_supply() returns no rows on empty data'
);

SELECT is(
  (SELECT count(*) FROM api.get_latest_mainnet_circulating_supply()),
  0::BIGINT,
  'get_latest_mainnet_circulating_supply() returns no rows on empty data'
);

SELECT is(
  (SELECT api.get_latest_mainnet_circulating_supply_value()),
  NULL,
  'get_latest_mainnet_circulating_supply_value() returns NULL on empty data'
);

INSERT INTO tmp_testnet.manifest_tokenomics_total_supply (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '100'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '200');
INSERT INTO tmp_testnet.manifest_tokenomics_excluded_supply (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '10'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '20');
INSERT INTO tmp_testnet.locked_tokens (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '5'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '10');
INSERT INTO tmp_testnet.locked_fees (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '2'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '4');

COMMIT;

CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_tokens', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees', now() - INTERVAL '4 days', now());

BEGIN;

-- Circulating supply is calculated as:
-- circulating_supply = total_supply - excluded_supply - locked_tokens - locked_fees
SELECT results_eq(
  'SELECT * FROM api.get_testnet_circulating_supply(interval ''1 day'', ':yesterday'::timestamptz - interval ''3 day'', now())',
  'VALUES
    (date_trunc(''day'', ':yesterday'::timestamptz), ''83''),
    (date_trunc(''day'', ':yesterday2'::timestamptz), ''166'')',
  'get_testnet_circulating_supply() returns correct values'
);

SELECT is(
  (SELECT value FROM api.get_latest_testnet_circulating_supply()),
  '83',
  'get_latest_testnet_circulating_supply() returns 83'
);

SELECT is(
  (SELECT api.get_latest_testnet_circulating_supply_value()),
  83::NUMERIC,
  'get_latest_testnet_circulating_supply_value() returns 83'
);

DELETE FROM tmp_testnet.manifest_tokenomics_total_supply;
DELETE FROM tmp_testnet.manifest_tokenomics_excluded_supply;
DELETE FROM tmp_testnet.locked_tokens;
DELETE FROM tmp_testnet.locked_fees;

DELETE FROM testnet.manifest_tokenomics_total_supply;
DELETE FROM testnet.manifest_tokenomics_excluded_supply;
DELETE FROM testnet.locked_tokens;
DELETE FROM testnet.locked_fees;

INSERT INTO tmp_mainnet.manifest_tokenomics_total_supply (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '1000'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '2000');
INSERT INTO tmp_mainnet.manifest_tokenomics_excluded_supply (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '100'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '200');
INSERT INTO tmp_mainnet.locked_tokens (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '50'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '100');
INSERT INTO tmp_mainnet.locked_fees (time, tags, value) VALUES (:yesterday::TIMESTAMPTZ, '{}'::JSONB, '20'), (:yesterday2::TIMESTAMPTZ, '{}'::JSONB, '40');

COMMIT;

CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_tokens', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees', now() - INTERVAL '4 days', now());

BEGIN;

SELECT results_eq(
  'SELECT * FROM api.get_mainnet_circulating_supply(interval ''1 day'', ':yesterday'::timestamptz - interval ''3 day'', now())',
  'VALUES
    (date_trunc(''day'', ':yesterday'::timestamptz), ''830''),
    (date_trunc(''day'', ':yesterday2'::timestamptz), ''1660'')',
  'get_mainnet_circulating_supply() returns correct values'
);
SELECT is(
  (SELECT value FROM api.get_latest_mainnet_circulating_supply()),
  '830',
  'get_latest_mainnet_circulating_supply() returns 830'
);
SELECT is(
  (SELECT api.get_latest_mainnet_circulating_supply_value()),
  830::NUMERIC,
  'get_latest_mainnet_circulating_supply_value() returns 830'
);

DELETE FROM tmp_mainnet.manifest_tokenomics_total_supply;
DELETE FROM tmp_mainnet.manifest_tokenomics_excluded_supply;
DELETE FROM tmp_mainnet.locked_tokens;
DELETE FROM tmp_mainnet.locked_fees;

DELETE FROM mainnet.manifest_tokenomics_total_supply;
DELETE FROM mainnet.manifest_tokenomics_excluded_supply;
DELETE FROM mainnet.locked_tokens;
DELETE FROM mainnet.locked_fees;

COMMIT;

CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_total_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_tokens', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_total_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_manifest_tokenomics_excluded_supply', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_tokens', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees', now() - INTERVAL '4 days', now());

BEGIN;

SELECT * FROM finish();

COMMIT;