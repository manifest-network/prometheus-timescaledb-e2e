BEGIN;

-- Metric (hyper)table
CREATE TABLE IF NOT EXISTS internal.prometheus_remote_write (
    time TIMESTAMPTZ NOT NULL,
    tag_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    schema TEXT NOT NULL,
    value NUMERIC NOT NULL,
    PRIMARY KEY (time, name, schema, tag_id)
);
SELECT create_hypertable('internal.prometheus_remote_write', 'time');
SELECT add_retention_policy('internal.prometheus_remote_write', INTERVAL '1 year');

CREATE INDEX ON internal.prometheus_remote_write (schema, name, time DESC);

CREATE TABLE internal.prometheus_remote_write_tag (
    tag_id BIGINT PRIMARY KEY,
    instance TEXT,
    country_name TEXT,
    city TEXT
);

COMMIT;
