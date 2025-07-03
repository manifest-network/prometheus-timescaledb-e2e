-- `tests/001_init_schema_and_roles.sql`
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(15);

-- schemas exist
SELECT has_schema('api', 'schema api exists');
SELECT has_schema('internal', 'schema internal exists');
SELECT has_schema('cumsum', 'schema cumsum exists');
SELECT has_schema('geo', 'schema geo exists');

-- roles exist
SELECT has_role('web_anon', 'role web_anon exists');
SELECT has_role('authenticator', 'role authenticator exists');
SELECT has_role('writer', 'role writer exists');

-- schema USAGE grants
SELECT schema_privs_are('api', 'web_anon', ARRAY['USAGE'], 'web_anon has usage on api schema');
SELECT schema_privs_are('internal', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on internal schema');
SELECT schema_privs_are('cumsum', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on cumsum schema');
SELECT schema_privs_are('geo', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on geo schema');

SELECT schema_privs_are('api', 'writer', ARRAY['USAGE'], 'writer has usage on api schema');
SELECT schema_privs_are('internal', 'writer', ARRAY['USAGE'], 'writer has usage on internal schema');

-- role memberships
SELECT ok(
  EXISTS(
    SELECT 1
      FROM pg_auth_members am
      JOIN pg_roles r ON am.roleid = r.oid
      JOIN pg_roles m ON am.member = m.oid
     WHERE r.rolname = 'web_anon'
       AND m.rolname = 'authenticator'
  ),
  'authenticator inherits web_anon'
);

SELECT ok(
  EXISTS(
    SELECT 1
      FROM pg_auth_members am
      JOIN pg_roles r ON am.roleid = r.oid
      JOIN pg_roles m ON am.member = m.oid
     WHERE r.rolname = 'writer'
       AND m.rolname = 'authenticator'
  ),
  'authenticator inherits writer'
);

SELECT * FROM finish();

COMMIT;
