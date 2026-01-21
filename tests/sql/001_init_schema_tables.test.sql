-- Tests for Migration 001: Schemas, Roles, and Base Tables
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(42);

-- =============================================================================
-- 1. Schemas exist
-- =============================================================================

SELECT has_schema('api', 'schema api exists');
SELECT has_schema('internal', 'schema internal exists');
SELECT has_schema('cumsum', 'schema cumsum exists');
SELECT has_schema('geo', 'schema geo exists');
SELECT has_schema('staging_internal', 'schema staging_internal exists');
SELECT has_schema('staging_cumsum', 'schema staging_cumsum exists');

-- =============================================================================
-- 2. Roles exist
-- =============================================================================

SELECT has_role('web_anon', 'role web_anon exists');
SELECT has_role('authenticator', 'role authenticator exists');
SELECT has_role('writer', 'role writer exists');

-- =============================================================================
-- 3. Schema privileges
-- =============================================================================

SELECT schema_privs_are('api', 'web_anon', ARRAY['USAGE'], 'web_anon has usage on api schema');
SELECT schema_privs_are('internal', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on internal schema');
SELECT schema_privs_are('cumsum', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on cumsum schema');
SELECT schema_privs_are('geo', 'web_anon', ARRAY[]::TEXT[], 'web_anon has no privileges on geo schema');

SELECT schema_privs_are('api', 'writer', ARRAY['USAGE'], 'writer has usage on api schema');

-- =============================================================================
-- 4. Role memberships
-- =============================================================================

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

-- =============================================================================
-- 5. Internal tables exist
-- =============================================================================

SELECT has_table('internal', 'prometheus_remote_write', 'internal.prometheus_remote_write table exists');
SELECT has_table('internal', 'prometheus_remote_write_tag', 'internal.prometheus_remote_write_tag table exists');
SELECT has_table('internal', 'excluded_addresses', 'internal.excluded_addresses table exists');

SELECT table_privs_are(
  'internal', 'prometheus_remote_write', 'web_anon', ARRAY[]::text[],
  'web_anon has no privileges on internal.prometheus_remote_write'
);

SELECT table_privs_are(
  'internal', 'prometheus_remote_write_tag', 'web_anon', ARRAY[]::text[],
  'web_anon has no privileges on internal.prometheus_remote_write_tag'
);

-- =============================================================================
-- 6. Cumsum tables exist
-- =============================================================================

SELECT has_table('cumsum', 'prometheus_remote_write', 'cumsum.prometheus_remote_write table exists');
-- Note: cumsum shares internal.prometheus_remote_write_tag (no separate cumsum tag table)

SELECT table_privs_are(
  'cumsum', 'prometheus_remote_write', 'web_anon', ARRAY[]::text[],
  'web_anon has no privileges on cumsum.prometheus_remote_write'
);

-- =============================================================================
-- 7. Staging tables exist (UNLOGGED)
-- =============================================================================

SELECT has_table('staging_internal', 'prometheus_remote_write', 'staging_internal.prometheus_remote_write table exists');
SELECT has_table('staging_internal', 'prometheus_remote_write_tag', 'staging_internal.prometheus_remote_write_tag table exists');
SELECT has_table('staging_cumsum', 'prometheus_remote_write', 'staging_cumsum.prometheus_remote_write table exists');
SELECT has_table('staging_cumsum', 'prometheus_remote_write_tag', 'staging_cumsum.prometheus_remote_write_tag table exists');

-- =============================================================================
-- 8. Excluded addresses table
-- =============================================================================

SELECT has_column('internal', 'excluded_addresses', 'id', 'excluded_addresses.id column exists');
SELECT has_column('internal', 'excluded_addresses', 'value', 'excluded_addresses.value column exists');
SELECT has_pk('internal', 'excluded_addresses', 'excluded_addresses has primary key');
SELECT col_is_pk('internal', 'excluded_addresses', 'id', 'id is primary key');
SELECT has_unique('internal', 'excluded_addresses', 'excluded_addresses has unique constraint');
SELECT col_is_unique('internal', 'excluded_addresses', 'value', 'value is unique');

SELECT table_privs_are(
  'internal', 'excluded_addresses', 'writer', ARRAY['SELECT','INSERT','DELETE'],
  'writer has correct table privileges on excluded_addresses'
);

SELECT table_privs_are(
  'internal', 'excluded_addresses', 'web_anon', ARRAY['SELECT'],
  'web_anon has SELECT on excluded_addresses'
);

-- =============================================================================
-- 9. Staging triggers exist
-- =============================================================================

SELECT has_trigger('staging_internal', 'prometheus_remote_write', 'trg_flush_prometheus_remote_write',
  'staging_internal.prometheus_remote_write has flush trigger');
SELECT has_trigger('staging_internal', 'prometheus_remote_write_tag', 'trg_flush_prometheus_remote_write_tag',
  'staging_internal.prometheus_remote_write_tag has flush trigger');
SELECT has_trigger('staging_cumsum', 'prometheus_remote_write', 'trg_flush_prometheus_remote_write',
  'staging_cumsum.prometheus_remote_write has flush trigger');
SELECT has_trigger('staging_cumsum', 'prometheus_remote_write_tag', 'trg_flush_prometheus_remote_write_tag',
  'staging_cumsum.prometheus_remote_write_tag has flush trigger');

SELECT * FROM finish();

COMMIT;
