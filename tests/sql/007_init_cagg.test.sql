BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(1);

SELECT has_view(
  'internal',
  'cagg_calculated_metric',
  'internal.cagg_calculated_metric is a view'
);

SELECT * FROM finish();

COMMIT;
