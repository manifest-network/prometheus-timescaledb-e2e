BEGIN;

-- =============================================================================
-- Migration 017: Staging tables for duplicate handling
-- =============================================================================
-- Telegraf uses COPY which fails entire batches on duplicate key violations.
-- This migration creates staging tables that accept all data, then uses
-- triggers to insert into main tables with ON CONFLICT DO NOTHING.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Rename existing tables to _main suffix
-- -----------------------------------------------------------------------------

ALTER TABLE internal.prometheus_remote_write RENAME TO prometheus_remote_write_main;
ALTER TABLE cumsum.prometheus_remote_write RENAME TO prometheus_remote_write_main;

-- -----------------------------------------------------------------------------
-- 2. Create staging tables (no constraints, same structure)
-- -----------------------------------------------------------------------------

CREATE TABLE internal.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL
);

CREATE TABLE cumsum.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL
);

-- -----------------------------------------------------------------------------
-- 3. Create trigger functions to move data with conflict handling
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION internal.staging_to_main()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO internal.prometheus_remote_write_main (time, tag_id, name, schema, value)
    VALUES (NEW.time, NEW.tag_id, NEW.name, NEW.schema, NEW.value)
    ON CONFLICT DO NOTHING;

    -- Don't keep data in staging table
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cumsum.staging_to_main()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO cumsum.prometheus_remote_write_main (time, tag_id, name, schema, value)
    VALUES (NEW.time, NEW.tag_id, NEW.name, NEW.schema, NEW.value)
    ON CONFLICT DO NOTHING;

    -- Don't keep data in staging table
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 4. Create triggers on staging tables
-- -----------------------------------------------------------------------------

CREATE TRIGGER staging_insert_trigger
    BEFORE INSERT ON internal.prometheus_remote_write
    FOR EACH ROW
    EXECUTE FUNCTION internal.staging_to_main();

CREATE TRIGGER staging_insert_trigger
    BEFORE INSERT ON cumsum.prometheus_remote_write
    FOR EACH ROW
    EXECUTE FUNCTION cumsum.staging_to_main();

COMMIT;
