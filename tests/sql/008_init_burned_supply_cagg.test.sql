BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(14);

SELECT has_function('api','get_testnet_burned_supply',   ARRAY['interval','timestamptz','timestamptz'], 'get_testnet_burned_supply() exists');
SELECT has_function('api','get_mainnet_burned_supply',  ARRAY['interval','timestamptz','timestamptz'], 'get_mainnet_burned_supply() exists');
SELECT has_view('api','latest_testnet_burned_supply',   'latest_testnet_burned_supply view exists');
SELECT has_view('api','latest_mainnet_burned_supply',  'latest_mainnet_burned_supply view exists');
SELECT has_function('api','get_latest_testnet_burned_supply', ARRAY[]::text[], 'get_latest_testnet_burned_supply() exists');
SELECT has_function('api','get_latest_mainnet_burned_supply',  ARRAY[]::text[], 'get_latest_mainnet_burned_supply() exists');

SELECT is(
  (SELECT count(*) FROM api.get_testnet_burned_supply(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_testnet_burned_supply() returns no rows on empty data'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_testnet_burned_supply()),
  0::BIGINT,
  'get_latest_testnet_burned_supply() returns no rows on empty data'
);

SELECT is(
  (SELECT count(*) FROM api.get_mainnet_burned_supply(interval '1 day', now() - interval '1 day', now())),
  0::BIGINT,
  'get_mainnet_burned_supply() returns no rows on empty data'
);
SELECT is(
  (SELECT count(*) FROM api.get_latest_mainnet_burned_supply()),
  0::BIGINT,
  'get_latest_mainnet_burned_supply() returns no rows on empty data'
);

SELECT
  quote_literal(now() - INTERVAL '1 day') AS yesterday,
  quote_literal(now() - INTERVAL '2 days') AS yesterday2
\gset

INSERT INTO testnet.total_mfx_burned (time, tags, value)
  VALUES (:yesterday::timestamptz, '{}'::JSONB, '50'),
         (:yesterday2::timestamptz, '{}'::JSONB, '60');
INSERT INTO tmp_testnet.locked_fees (time, tags, value)
  VALUES (:yesterday::timestamptz, '{}'::JSONB, '1'),
         (:yesterday2::timestamptz, '{}'::JSONB, '2');
COMMIT;

CALL refresh_continuous_aggregate('testnet.cagg_total_mfx_burned', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees',     now() - INTERVAL '4 days', now());

BEGIN;
SELECT results_eq(
  'SELECT * FROM api.get_testnet_burned_supply(interval ''1 day'', '':yesterday''::timestamptz - interval ''4 days'', now())',
  'VALUES
    (date_trunc(''day'',':yesterday'::timestamptz), ''51''),
    (date_trunc(''day'',':yesterday2'::timestamptz), ''62'')',
  'get_testnet_burned_supply() returns correct values'
);

SELECT is(
  (SELECT value FROM api.latest_testnet_burned_supply),
  '51',
  'latest_testnet_burned_supply() returns most recent value'
);

-- cleanup testnet
DELETE FROM tmp_testnet.locked_fees;
DELETE FROM testnet.total_mfx_burned;
DELETE FROM testnet.locked_fees;

COMMIT;

CALL refresh_continuous_aggregate('testnet.cagg_total_mfx_burned', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('testnet.cagg_locked_fees',     now() - INTERVAL '4 days', now());

BEGIN;
INSERT INTO mainnet.total_mfx_burned (time, tags, value)
  VALUES (:yesterday::timestamptz, '{}'::JSONB, '150'),
         (:yesterday2::timestamptz, '{}'::JSONB, '250');
INSERT INTO tmp_mainnet.locked_fees (time, tags, value)
  VALUES (:yesterday::timestamptz, '{}'::JSONB, '5'),
         (:yesterday2::timestamptz, '{}'::JSONB, '10');

COMMIT;

CALL refresh_continuous_aggregate('mainnet.cagg_total_mfx_burned', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees',     now() - INTERVAL '4 days', now());

BEGIN;

SELECT results_eq(
  'SELECT * FROM api.get_mainnet_burned_supply(interval ''1 day'', '':yesterday''::timestamptz - interval ''3 days'', now())',
  'VALUES
    (date_trunc(''day'',':yesterday'::timestamptz), ''155''),
    (date_trunc(''day'',':yesterday2'::timestamptz), ''260'')',
  'get_mainnet_burned_supply() returns correct values'
);
SELECT is(
  (SELECT value FROM api.latest_mainnet_burned_supply),
  '155',
  'latest_mainnet_burned_supply() returns most recent value'
);

DELETE FROM tmp_mainnet.locked_fees;
DELETE FROM mainnet.total_mfx_burned;
DELETE FROM mainnet.locked_fees;

COMMIT;

CALL refresh_continuous_aggregate('mainnet.cagg_total_mfx_burned', now() - INTERVAL '4 days', now());
CALL refresh_continuous_aggregate('mainnet.cagg_locked_fees',     now() - INTERVAL '4 days', now());

BEGIN;

SELECT * FROM finish();

COMMIT;
