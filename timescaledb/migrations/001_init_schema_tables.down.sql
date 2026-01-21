BEGIN;

-- Drop staging_cumsum tables and functions
DROP TRIGGER IF EXISTS trg_flush_prometheus_remote_write_tag ON staging_cumsum.prometheus_remote_write_tag;
DROP FUNCTION IF EXISTS staging_cumsum.flush_prometheus_remote_write_tag();
DROP TABLE IF EXISTS staging_cumsum.prometheus_remote_write_tag;

DROP TRIGGER IF EXISTS trg_flush_prometheus_remote_write ON staging_cumsum.prometheus_remote_write;
DROP FUNCTION IF EXISTS staging_cumsum.flush_prometheus_remote_write();
DROP TABLE IF EXISTS staging_cumsum.prometheus_remote_write;

-- Drop staging_internal tables and functions
DROP TRIGGER IF EXISTS trg_flush_prometheus_remote_write_tag ON staging_internal.prometheus_remote_write_tag;
DROP FUNCTION IF EXISTS staging_internal.flush_prometheus_remote_write_tag();
DROP TABLE IF EXISTS staging_internal.prometheus_remote_write_tag;

DROP TRIGGER IF EXISTS trg_flush_prometheus_remote_write ON staging_internal.prometheus_remote_write;
DROP FUNCTION IF EXISTS staging_internal.flush_prometheus_remote_write();
DROP TABLE IF EXISTS staging_internal.prometheus_remote_write;

-- Drop tables
DROP TABLE IF EXISTS internal.excluded_addresses;
DROP TABLE IF EXISTS cumsum.prometheus_remote_write;
DROP TABLE IF EXISTS internal.prometheus_remote_write_tag;
DROP TABLE IF EXISTS internal.prometheus_remote_write;

-- Drop schemas
DROP SCHEMA IF EXISTS staging_cumsum CASCADE;
DROP SCHEMA IF EXISTS staging_internal CASCADE;
DROP SCHEMA IF EXISTS geo CASCADE;
DROP SCHEMA IF EXISTS cumsum CASCADE;
DROP SCHEMA IF EXISTS internal CASCADE;
DROP SCHEMA IF EXISTS api CASCADE;

-- Drop roles
DROP ROLE IF EXISTS writer;
DROP ROLE IF EXISTS web_anon;
DROP ROLE IF EXISTS authenticator;

COMMIT;
