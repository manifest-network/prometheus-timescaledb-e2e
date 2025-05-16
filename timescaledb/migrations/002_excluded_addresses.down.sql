BEGIN;

DROP FUNCTION IF EXISTS get_excluded_addresses();
DROP TABLE IF EXISTS excluded_addresses;

REVOKE ALL ON SCHEMA public FROM writer;
REVOKE ALL ON SCHEMA public FROM authenticator;
REVOKE ALL ON SCHEMA public FROM web_anon;

DROP ROLE IF EXISTS writer;
DROP ROLE IF EXISTS authenticator;
DROP ROLE IF EXISTS web_anon;

COMMIT;
