-- Install pgTAP and declare the number of tests
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(17);

-- Table and columns
SELECT has_table('internal', 'excluded_addresses', 'excluded_addresses table exists');
SELECT has_column('internal', 'excluded_addresses', 'id', 'column id exists');
SELECT has_column('internal', 'excluded_addresses', 'value', 'column value exists');

-- Constraints
SELECT has_pk('internal', 'excluded_addresses', 'excluded_addresses has primary key');
SELECT col_is_pk('internal', 'excluded_addresses', 'id', 'id is primary key');
SELECT has_unique('internal', 'excluded_addresses', 'excluded_addresses has unique constraint');
SELECT col_is_unique('internal', 'excluded_addresses', 'value', 'value is unique');
--
---- Table privileges
SELECT table_privs_are(
  'internal',
  'excluded_addresses',
  'writer',
  ARRAY['SELECT','INSERT','DELETE'],
  'writer has correct table privileges'
);

SELECT table_privs_are(
  'internal',
  'excluded_addresses',
  'web_anon',
  ARRAY['SELECT'],
  'web_anon has correct table privileges'
);

SELECT has_function(
  'api',
  'get_excluded_addresses',
  ARRAY[]::text[],
  'get_excluded_addresses exists'
);
SELECT function_privs_are(
  'api',
  'get_excluded_addresses',
  ARRAY[]::text[],
  'web_anon',
  ARRAY['EXECUTE'],
  'web_anon can execute get_excluded_addresses'
);

SELECT has_function(
  'api',
  'add_excluded_address',
  ARRAY['text'],
  'add_excluded_address exists'
);
SELECT function_privs_are(
  'api',
  'add_excluded_address',
  ARRAY['text'],
  'writer',
  ARRAY['EXECUTE'],
  'writer can execute add_excluded_address'
);
SELECT function_privs_are(
  'api',
  'add_excluded_address',
  ARRAY['text'],
  'web_anon',
  ARRAY[]::text[],
  'web_anon cannot execute add_excluded_address'
);

SELECT has_function(
  'api',
  'rm_excluded_address',
  ARRAY['text'],
  'rm_excluded_address exists'
);
SELECT function_privs_are(
  'api',
  'rm_excluded_address',
  ARRAY['text'],
  'writer',
  ARRAY['EXECUTE'],
  'writer can execute rm_excluded_address'
);
SELECT function_privs_are(
  'api',
  'rm_excluded_address',
  ARRAY['text'],
  'web_anon',
  ARRAY[]::text[],
  'web_anon cannot execute rm_excluded_address'
);

---- Complete the test
SELECT * FROM finish();