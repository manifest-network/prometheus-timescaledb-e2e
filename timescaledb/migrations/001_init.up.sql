BEGIN;

---- Schema creation
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS internal;
CREATE SCHEMA IF NOT EXISTS common;
CREATE SCHEMA IF NOT EXISTS testnet;
CREATE SCHEMA IF NOT EXISTS mainnet;
CREATE SCHEMA IF NOT EXISTS cumsum;
CREATE SCHEMA IF NOT EXISTS geo;

-- Roles and permissions
DO $$
BEGIN
CREATE ROLE web_anon nologin;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA internal TO web_anon;

DO $$
BEGIN
CREATE ROLE authenticator noinherit nologin;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;
GRANT web_anon TO authenticator;

DO $$
BEGIN
CREATE ROLE writer nologin;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;
GRANT USAGE ON SCHEMA api TO writer;
GRANT USAGE ON SCHEMA internal TO writer;
GRANT writer TO authenticator;

COMMIT;
