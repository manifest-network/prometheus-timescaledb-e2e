BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(12);

CREATE TEMP TABLE schemas(sch text);
INSERT INTO schemas(sch) VALUES
  ('testnet'),
  ('mainnet'),
  ('cumsum'),
  ('common');

CREATE TEMP TABLE metrics(tbl text);
INSERT INTO metrics(tbl) VALUES
  ('test_metric_006'),
  ('test_metric_006_2');

SELECT
  quote_literal(now() - INTERVAL '1 day') AS yesterday,
  quote_literal(now() - INTERVAL '2 days') AS yesterday2,
  quote_literal(now() - INTERVAL '3 days') AS yesterday3
\gset

-- Initialize the metric in each schema and insert some data
WITH combos AS (
  SELECT
    sch,
    tbl,
    row_number() OVER (ORDER BY sch, tbl) AS val
  FROM schemas
  CROSS JOIN metrics
)
SELECT format(
  $$
    SELECT internal.initialize_metric(%2$L, %1$L);
    SELECT has_table(%1$L, %2$L, '%1$I.%2$I table created');
    INSERT INTO %1$I.%2$I(time, tags, value) VALUES
      (%4$L::TIMESTAMPTZ, '{}'::JSONB, %3$s),
      (%5$L::TIMESTAMPTZ, '{}'::JSONB, %3$s * 2),
      (%6$L::TIMESTAMPTZ, '{}'::JSONB, %3$s * 3);
  $$,
    sch,
    tbl,
    val,
    :yesterday,
    :yesterday2,
    :yesterday3
)
FROM combos
\gexec

-- Verify the `api.get_all_latest_<schema>_metrics` functions return correct values
-- `combos` produces a row for each schema and metric combination
WITH combos AS (
  SELECT
    sch,
    tbl,
    row_number() OVER (ORDER BY sch, tbl) AS val
  FROM schemas
  CROSS JOIN metrics
),
-- Create expected values for each schema
expected AS (
  SELECT
    sch,
    format(
      $$VALUES %s$$,
      string_agg(
        format('(%L, %L::TIMESTAMPTZ, %L)', tbl, :yesterday, val),
        ', ' ORDER BY tbl
      )
    ) AS exp
  FROM combos
  GROUP BY sch
)
-- Check the results once per schema
SELECT
  results_eq(
    format('SELECT * FROM api.get_all_latest_%I_metrics()', sch),
    exp,
    format('get_all_latest_%s_metrics() returns correct values', sch)
  )
FROM expected;

SELECT * FROM finish();

COMMIT;
