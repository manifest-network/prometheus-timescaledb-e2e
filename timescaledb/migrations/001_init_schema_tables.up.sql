BEGIN;

-- =============================================================================
-- Migration 001: Schemas, Roles, and Base Tables
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Create schemas
-- -----------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS internal;
CREATE SCHEMA IF NOT EXISTS cumsum;
CREATE SCHEMA IF NOT EXISTS geo;
CREATE SCHEMA IF NOT EXISTS staging_internal;
CREATE SCHEMA IF NOT EXISTS staging_cumsum;

-- -----------------------------------------------------------------------------
-- 2. Create roles
-- -----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authenticator';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'writer') THEN
        CREATE ROLE writer NOLOGIN;
    END IF;
END
$$;

GRANT web_anon TO authenticator;
GRANT writer TO authenticator;

-- Grant usage on schemas
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA api TO writer;

-- -----------------------------------------------------------------------------
-- 3. Create internal metrics hypertable
-- -----------------------------------------------------------------------------

CREATE TABLE internal.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL,
    UNIQUE (time, tag_id, name, schema)
);

SELECT create_hypertable('internal.prometheus_remote_write', 'time');
SELECT add_retention_policy('internal.prometheus_remote_write', INTERVAL '1 year');

CREATE INDEX idx_internal_schema_name_time ON internal.prometheus_remote_write (schema, name, time DESC);
CREATE INDEX idx_internal_name_time ON internal.prometheus_remote_write (name, time DESC);

-- -----------------------------------------------------------------------------
-- 4. Create internal tag table
-- -----------------------------------------------------------------------------

CREATE TABLE internal.prometheus_remote_write_tag (
    tag_id BIGINT PRIMARY KEY,
    host TEXT,
    instance TEXT,
    country_name TEXT,
    city TEXT,
    supply TEXT,
    excluded_supply TEXT,
    amount TEXT
);

-- -----------------------------------------------------------------------------
-- 5. Create cumsum metrics hypertable
-- -----------------------------------------------------------------------------

CREATE TABLE cumsum.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL,
    UNIQUE (time, tag_id, name, schema)
);

SELECT create_hypertable('cumsum.prometheus_remote_write', 'time');

-- -----------------------------------------------------------------------------
-- 6. Create excluded addresses table
-- -----------------------------------------------------------------------------

CREATE TABLE internal.excluded_addresses (
    id SERIAL PRIMARY KEY,
    value TEXT NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- 7. Create staging tables for Telegraf (bulk insert with duplicate handling)
-- -----------------------------------------------------------------------------
-- Uses UNLOGGED tables for faster writes and statement-level triggers with
-- transition tables for bulk INSERT ... ON CONFLICT DO NOTHING.

-- Staging table for internal metrics (Telegraf COPYs here)
CREATE UNLOGGED TABLE staging_internal.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL
);

CREATE FUNCTION staging_internal.flush_prometheus_remote_write()
RETURNS TRIGGER AS $$
BEGIN
    -- Bulk insert to main table, ignore duplicates
    INSERT INTO internal.prometheus_remote_write (time, tag_id, name, schema, value)
    SELECT time, tag_id, name, schema, value FROM new_rows
    ON CONFLICT (time, tag_id, name, schema) DO NOTHING;

    -- Clean up staging table
    DELETE FROM staging_internal.prometheus_remote_write s
    USING new_rows n
    WHERE s.time = n.time
      AND s.tag_id = n.tag_id
      AND s.name = n.name
      AND s.schema = n.schema;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flush_prometheus_remote_write
AFTER INSERT ON staging_internal.prometheus_remote_write
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION staging_internal.flush_prometheus_remote_write();

-- Staging table for internal tag table
CREATE UNLOGGED TABLE staging_internal.prometheus_remote_write_tag (
    tag_id BIGINT PRIMARY KEY,
    host TEXT,
    instance TEXT,
    country_name TEXT,
    city TEXT,
    supply TEXT,
    excluded_supply TEXT,
    amount TEXT
);

CREATE FUNCTION staging_internal.flush_prometheus_remote_write_tag()
RETURNS TRIGGER AS $$
BEGIN
    -- Bulk upsert to main tag table
    INSERT INTO internal.prometheus_remote_write_tag (tag_id, host, instance, country_name, city, supply, excluded_supply, amount)
    SELECT tag_id, host, instance, country_name, city, supply, excluded_supply, amount FROM new_rows
    ON CONFLICT (tag_id) DO UPDATE SET
        host = COALESCE(EXCLUDED.host, internal.prometheus_remote_write_tag.host),
        instance = COALESCE(EXCLUDED.instance, internal.prometheus_remote_write_tag.instance),
        country_name = COALESCE(EXCLUDED.country_name, internal.prometheus_remote_write_tag.country_name),
        city = COALESCE(EXCLUDED.city, internal.prometheus_remote_write_tag.city),
        supply = COALESCE(EXCLUDED.supply, internal.prometheus_remote_write_tag.supply),
        excluded_supply = COALESCE(EXCLUDED.excluded_supply, internal.prometheus_remote_write_tag.excluded_supply),
        amount = COALESCE(EXCLUDED.amount, internal.prometheus_remote_write_tag.amount);

    -- Clean up staging table
    DELETE FROM staging_internal.prometheus_remote_write_tag s
    USING new_rows n
    WHERE s.tag_id = n.tag_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flush_prometheus_remote_write_tag
AFTER INSERT ON staging_internal.prometheus_remote_write_tag
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION staging_internal.flush_prometheus_remote_write_tag();

-- Staging table for cumsum metrics (Telegraf COPYs here)
CREATE UNLOGGED TABLE staging_cumsum.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL
);

CREATE FUNCTION staging_cumsum.flush_prometheus_remote_write()
RETURNS TRIGGER AS $$
BEGIN
    -- Bulk insert to main table, ignore duplicates
    INSERT INTO cumsum.prometheus_remote_write (time, tag_id, name, schema, value)
    SELECT time, tag_id, name, schema, value FROM new_rows
    ON CONFLICT (time, tag_id, name, schema) DO NOTHING;

    -- Clean up staging table
    DELETE FROM staging_cumsum.prometheus_remote_write s
    USING new_rows n
    WHERE s.time = n.time
      AND s.tag_id = n.tag_id
      AND s.name = n.name
      AND s.schema = n.schema;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flush_prometheus_remote_write
AFTER INSERT ON staging_cumsum.prometheus_remote_write
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION staging_cumsum.flush_prometheus_remote_write();

-- Staging table for cumsum tag table (shares main tag table with internal)
CREATE UNLOGGED TABLE staging_cumsum.prometheus_remote_write_tag (
    tag_id BIGINT PRIMARY KEY,
    host TEXT,
    instance TEXT,
    country_name TEXT,
    city TEXT,
    supply TEXT,
    excluded_supply TEXT,
    amount TEXT
);

CREATE FUNCTION staging_cumsum.flush_prometheus_remote_write_tag()
RETURNS TRIGGER AS $$
BEGIN
    -- Bulk upsert to main tag table
    INSERT INTO internal.prometheus_remote_write_tag (tag_id, host, instance, country_name, city, supply, excluded_supply, amount)
    SELECT tag_id, host, instance, country_name, city, supply, excluded_supply, amount FROM new_rows
    ON CONFLICT (tag_id) DO UPDATE SET
        host = COALESCE(EXCLUDED.host, internal.prometheus_remote_write_tag.host),
        instance = COALESCE(EXCLUDED.instance, internal.prometheus_remote_write_tag.instance),
        country_name = COALESCE(EXCLUDED.country_name, internal.prometheus_remote_write_tag.country_name),
        city = COALESCE(EXCLUDED.city, internal.prometheus_remote_write_tag.city),
        supply = COALESCE(EXCLUDED.supply, internal.prometheus_remote_write_tag.supply),
        excluded_supply = COALESCE(EXCLUDED.excluded_supply, internal.prometheus_remote_write_tag.excluded_supply),
        amount = COALESCE(EXCLUDED.amount, internal.prometheus_remote_write_tag.amount);

    -- Clean up staging table
    DELETE FROM staging_cumsum.prometheus_remote_write_tag s
    USING new_rows n
    WHERE s.tag_id = n.tag_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flush_prometheus_remote_write_tag
AFTER INSERT ON staging_cumsum.prometheus_remote_write_tag
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION staging_cumsum.flush_prometheus_remote_write_tag();

COMMIT;
