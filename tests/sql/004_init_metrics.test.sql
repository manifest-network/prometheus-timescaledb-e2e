BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(20);

SELECT
  quote_literal(now() - INTERVAL '1 day') AS yesterday,
  quote_literal(now() - INTERVAL '1 day' - INTERVAL '1 hour') AS yesterdayy, -- Same day, different hour
  quote_literal(now() - INTERVAL '1 day' - INTERVAL '2 hour') AS yesterdayyy, -- Same day, different hour
  quote_literal(now() - INTERVAL '2 days') AS yesterday2,
  quote_literal(now() - INTERVAL '3 days') AS yesterday3,
  quote_literal(now() - INTERVAL '4 days') AS yesterday4
\gset

-- Core initializer functions exist
SELECT has_function('internal','initialize_metric',ARRAY['text','text'],'initialize_metric() exists');
SELECT has_function('internal','initialize_cumsum_metric',ARRAY['text'],'initialize_cumsum_metric() exists');

-- Exercise initialize_metric for a test metric in schema common
SELECT internal.initialize_metric('test_metric','common');

SELECT has_table('common','test_metric','common.test_metric table created');
SELECT ok(
  EXISTS(
    SELECT 1 FROM _timescaledb_catalog.hypertable
    WHERE schema_name='common' AND table_name='test_metric'
  ),
  'common.test_metric is a hypertable'
);
SELECT ok(
  EXISTS(
    SELECT 1 FROM timescaledb_information.jobs
    WHERE hypertable_schema='common' AND hypertable_name='test_metric' AND proc_name='policy_retention'
  ),
  'retention policy applied to common.test_metric'
);
SELECT has_function('api','get_common_agg_test_metric',ARRAY['INTERVAL','TIMESTAMPTZ','TIMESTAMPTZ'],'aggregation function created');
SELECT has_view('api','latest_common_test_metric','latest metric view created');
SELECT has_function('api','get_latest_common_test_metric_value',ARRAY[]::text[],'latest value function created');

INSERT INTO common.test_metric(time, tags, value) VALUES
  (:yesterday::TIMESTAMPTZ, '{}'::jsonb, 1.0),
  (:yesterdayy::TIMESTAMPTZ, '{}'::jsonb, 1.5), -- Insert another value around yesterday to make sure we get the MAX in the aggregation
  (:yesterday2::TIMESTAMPTZ, '{}'::jsonb, 2.0),
  (:yesterday3::TIMESTAMPTZ, '{}'::jsonb, 3.0) ON CONFLICT (time, tags) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM common.test_metric),
  4::BIGINT,
  '4 rows inserted into common.test_metric'
);

-- Check the latest value function
SELECT is(
  (SELECT api.get_latest_common_test_metric_value()),
  1.0,
  'latest value function returns correct value'
);

-- Check the latest view
SELECT results_eq(
  'SELECT * FROM api.latest_common_test_metric',
  'VALUES (':yesterday'::TIMESTAMPTZ, ''1.0'')',
  'latest view returns correct latest value'
);

-- Check the aggregation function
SELECT results_eq(
  'SELECT * FROM api.get_common_agg_test_metric(''1 day'', ':yesterday4'::TIMESTAMPTZ, ':yesterday'::TIMESTAMPTZ)',
  'VALUES
   (date_trunc(''day'', ':yesterday'::TIMESTAMPTZ), ''1.5''), -- We should get the MAX value from the two values inserted around yesterday
   (date_trunc(''day'', ':yesterday2'::TIMESTAMPTZ), ''2.0''),
   (date_trunc(''day'', ':yesterday3'::TIMESTAMPTZ), ''3.0'')',
  'aggregation function returns correct values'
);

DELETE FROM common.test_metric;

-- Exercise initialize_cumsum_metric for a cumulative metric
SELECT internal.initialize_cumsum_metric('cs_metric');

SELECT has_table('cumsum','cs_metric','cumsum.cs_metric table created');
SELECT ok(
  EXISTS(
    SELECT 1 FROM _timescaledb_catalog.hypertable
    WHERE schema_name='cumsum' AND table_name='cs_metric'
  ),
  'cumsum.cs_metric is a hypertable'
);
SELECT ok(
  EXISTS(
    SELECT 1 FROM timescaledb_information.jobs
    WHERE hypertable_schema='cumsum' AND hypertable_name='cs_metric' AND proc_name='policy_retention'
  ),
  'retention policy applied to cumsum.cs_metric'
);
SELECT has_function('api','get_cumsum_agg_cs_metric',ARRAY['INTERVAL','TIMESTAMPTZ','TIMESTAMPTZ'],'cumsum aggregation function created');
SELECT has_view('api','latest_cumsum_cs_metric','latest cumsum view created');

INSERT INTO cumsum.cs_metric(time, tags, value) VALUES
  (:yesterday4::TIMESTAMPTZ, '{}'::jsonb, 1.0),
  (:yesterday3::TIMESTAMPTZ, '{}'::jsonb, 2.0),
  (:yesterday2::TIMESTAMPTZ, '{}'::jsonb, 3.0),
  (:yesterdayy::TIMESTAMPTZ, '{}'::jsonb, 4.0),
  (:yesterday::TIMESTAMPTZ, '{}'::jsonb, 4.5)
ON CONFLICT (time, tags) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM cumsum.cs_metric),
  5::BIGINT,
  '5 rows inserted into cumsum.cs_metric'
);

SELECT results_eq(
  'SELECT * FROM api.latest_cumsum_cs_metric',
  'VALUES (':yesterday'::TIMESTAMPTZ, ''4.5'')',
  'latest cumsum view returns correct value'
);

SELECT results_eq(
  'SELECT * FROM api.get_cumsum_agg_cs_metric(''1 day'', ':yesterday4'::TIMESTAMPTZ, ':yesterday'::TIMESTAMPTZ)',
  'VALUES
     (date_trunc(''day'',':yesterday4'::TIMESTAMPTZ), ''1.0''),
     (date_trunc(''day'',':yesterday3'::TIMESTAMPTZ), ''3.0''),
     (date_trunc(''day'',':yesterday2'::TIMESTAMPTZ), ''6.0''),
     (date_trunc(''day'',':yesterday'::TIMESTAMPTZ), ''14.5'')',
  'cumsum aggregation returns correct cumulative sums'
);

DELETE FROM cumsum.cs_metric;

-- Insert some data to test the MAX(cumulative) behavior
INSERT INTO cumsum.cs_metric(time, tags, value) VALUES
  (:yesterdayy::TIMESTAMPTZ, '{}'::jsonb, 5.0),
  (:yesterdayyy::TIMESTAMPTZ, '{}'::jsonb, 15.0)
ON CONFLICT (time, tags) DO NOTHING;

SELECT results_eq(
  'SELECT * FROM api.get_cumsum_agg_cs_metric(''1 hours'', ':yesterday2'::TIMESTAMPTZ, ':yesterday'::TIMESTAMPTZ)',
  'VALUES
    (date_trunc(''hour'',':yesterdayyy'::TIMESTAMPTZ), ''15.0''),
    (date_trunc(''hour'',':yesterdayy'::TIMESTAMPTZ), ''20.0'')',
  'MAX(cumulative) picks the highest value in each bucket'
);

DELETE FROM cumsum.cs_metric;

SELECT * FROM finish();

COMMIT;
