BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(66);

CREATE TEMP TABLE networks(net text);
INSERT INTO networks(net) VALUES
  ('testnet'),
  ('mainnet');

CREATE TEMP TABLE metrics(tbl text);
INSERT INTO metrics(tbl) VALUES
  ('manifest_tokenomics_total_supply'),
  ('manifest_tokenomics_excluded_supply'),
  ('locked_tokens'),
  ('locked_fees');

SELECT has_schema('tmp_testnet', 'tmp_testnet schema exists');
SELECT has_schema('tmp_mainnet', 'tmp_mainnet schema exists');

SELECT has_table(
  format('tmp_%I', net),
  tbl,
  format('tmp_%I.%I table exists', net, tbl)
)
FROM networks
CROSS JOIN metrics;

SELECT ok(
  EXISTS (
    SELECT 1
    FROM _timescaledb_catalog.hypertable
    WHERE schema_name = format('tmp_%I', net)
      AND table_name   = tbl
  ),
  format('tmp_%I.%I is a hypertable', net, tbl)
)
FROM networks
CROSS JOIN metrics;

SELECT ok(
  EXISTS(
    SELECT 1
    FROM timescaledb_information.jobs
    WHERE hypertable_schema = format('tmp_%I', net)
      AND hypertable_name   = tbl
      AND proc_name         = 'policy_retention'
  ),
  format(
    'retention policy applied to tmp_%I.%I',
    net,
    tbl
  )
)
FROM networks
CROSS JOIN metrics;

SELECT has_trigger(
  format('tmp_%I', net),
  tbl,
  format('trg_tmp_to_%I_%I', net, tbl),
  format('insert trigger exists on tmp_%I.%I', net, tbl)
)
FROM networks
CROSS JOIN metrics;

SELECT has_view(
  net,
  format('cagg_%I', tbl),
  format('%I.cagg_%I view exists', net, tbl)
)
FROM networks
CROSS JOIN  metrics;

SELECT ok(
  EXISTS (
    SELECT 1
    FROM timescaledb_information.jobs
    WHERE hypertable_schema = net
      AND hypertable_name   = format('cagg_%I', tbl)
      AND proc_name         = 'policy_refresh_continuous_aggregate'
  ),
  format(
    'continuous aggregate policy on %I.cagg_%I exists',
    net,
    tbl
  )
)
FROM networks
CROSS JOIN metrics;

-- Verify the trigger moves data from tmp to the main table
WITH combos AS (
  SELECT
    net,
    tbl,
    row_number() OVER (ORDER BY net, tbl) AS val
  FROM networks
  CROSS JOIN metrics
)
SELECT format(
  $$
    INSERT INTO tmp_%1$I.%2$I (time, tags, value)
    VALUES (now(), '{}', %3$s);
    SELECT ok(
      (SELECT value FROM %1$I.%2$I LIMIT 1) = %3$s,
      'value %3$s moved from tmp_%1$I.%2$I to %1$I.%2$I'
    );
  $$,
  net,
  tbl,
  val
)
FROM combos
\gexec

COMMIT;

-- Refresh the continuous aggregates and check the values
WITH combos AS (
  SELECT
    net,
    tbl
  FROM networks
  CROSS JOIN metrics
)
SELECT format(
  $$
    CALL refresh_continuous_aggregate('%1$I.cagg_%2$I', now() - INTERVAL '1 hour', now());
  $$,
  net, tbl
)
FROM combos
\gexec

BEGIN;

-- Check the continuous aggregates return the expected values
WITH combos AS (
  SELECT
    net,
    tbl,
    row_number() OVER (ORDER BY net, tbl) AS val
  FROM networks
  CROSS JOIN metrics
)
SELECT format(
  $$
    SELECT is(
      (
        SELECT d.value
        FROM %1$I.cagg_%2$I AS d
        ORDER BY d.timestamp DESC
        LIMIT 1
      )::NUMERIC,
      %3$s::NUMERIC,
      'cagg_%1$I_%2$I returns %3$s'
    );
  $$, net, tbl, val)
FROM combos
\gexec

SELECT * FROM finish();

COMMIT;
