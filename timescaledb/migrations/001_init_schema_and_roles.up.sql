BEGIN;

CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS internal;

-- Anonymous role for web access
DO $$
BEGIN
CREATE ROLE web_anon nologin;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA internal TO web_anon;

-- Trusted user for web access
DO $$
BEGIN
CREATE ROLE authenticator noinherit nologin;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;
GRANT web_anon TO authenticator;

-- Dedicated role for writing to the database
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
