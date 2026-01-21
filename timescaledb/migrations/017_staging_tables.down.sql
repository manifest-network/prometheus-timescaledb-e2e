BEGIN;

-- =============================================================================
-- Migration 017 Rollback: Remove staging tables
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Drop triggers
-- -----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS staging_insert_trigger ON internal.prometheus_remote_write;
DROP TRIGGER IF EXISTS staging_insert_trigger ON cumsum.prometheus_remote_write;

-- -----------------------------------------------------------------------------
-- 2. Drop trigger functions
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS internal.staging_to_main();
DROP FUNCTION IF EXISTS cumsum.staging_to_main();

-- -----------------------------------------------------------------------------
-- 3. Drop staging tables
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS internal.prometheus_remote_write;
DROP TABLE IF EXISTS cumsum.prometheus_remote_write;

-- -----------------------------------------------------------------------------
-- 4. Rename main tables back to original names
-- -----------------------------------------------------------------------------

ALTER TABLE internal.prometheus_remote_write_main RENAME TO prometheus_remote_write;
ALTER TABLE cumsum.prometheus_remote_write_main RENAME TO prometheus_remote_write;

COMMIT;
