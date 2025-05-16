-- The metric tables are created by Telegraf.
-- See the Telegraf configuration file.
BEGIN;

CREATE OR REPLACE FUNCTION get_aggregated_metrics(
    metric_name VARCHAR,
    interval_str VARCHAR DEFAULT '1 hour',
    time_from TIMESTAMPTZ DEFAULT NULL,
    time_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
DECLARE
    query_text TEXT;
BEGIN
    IF time_from IS NULL THEN
        time_from := NOW() - INTERVAL '1 day';
    END IF;

    IF time_to IS NULL THEN
        time_to := NOW();
    END IF;

    query_text := format(
        'SELECT
            time_bucket(%L::INTERVAL, time)::TIMESTAMPTZ AS timestamp,
            AVG(value)::TEXT AS value
        FROM %s
        WHERE time >= %L AND time <= %L',
        interval_str, metric_name, time_from, time_to
    );

    query_text := query_text || ' GROUP BY time_bucket(%L::INTERVAL, time) ORDER BY timestamp DESC';

    RETURN QUERY EXECUTE format(query_text, interval_str);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_latest_geo_coordinates()
RETURNS TABLE (
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "country_name" TEXT,
    "city" TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_latitude AS (
        SELECT DISTINCT ON (tags->>'instance')
            tags->>'instance' AS instance,
            value AS latitude,
            time
        FROM manifest_geo_latitude
        ORDER BY tags->>'instance', time DESC
    ),
    latest_longitude AS (
        SELECT DISTINCT ON (tags->>'instance')
            tags->>'instance' AS instance,
            value AS longitude,
            time
        FROM manifest_geo_longitude
        ORDER BY tags->>'instance', time DESC
    ),
    latest_geo_metadata AS (
        SELECT DISTINCT ON (tags->>'instance')
            tags->>'instance' AS instance,
            tags->>'country_name' AS country_name,
            tags->>'city' AS city,
            time
        FROM manifest_geo_metadata
        ORDER BY tags->>'instance', time DESC
    )
    SELECT
        llat.latitude,
        llon.longitude,
        lgi.country_name,
        lgi.city
    FROM latest_latitude llat
    JOIN latest_longitude llon ON llat.instance = llon.instance
    JOIN latest_geo_metadata lgi ON llat.instance = lgi.instance;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_latest_values_from(metric_names TEXT[])
RETURNS JSON AS $$
DECLARE
    query_parts TEXT[] := '{}';
    query_text TEXT;
    i INTEGER;
    result JSON;
BEGIN
    IF array_length(metric_names, 1) IS NULL THEN
        RETURN '{}'::JSON;
    END IF;

    -- Build a query that creates a JSON object directly
    query_text := 'SELECT json_object_agg(metric_name, latest_value) FROM (';

    FOR i IN 1..array_length(metric_names, 1) LOOP
        query_parts := query_parts || format(
            'SELECT %L AS metric_name,
             (SELECT value FROM %I ORDER BY time DESC LIMIT 1) AS latest_value',
            metric_names[i], metric_names[i]
        );
    END LOOP;

    query_text := query_text || array_to_string(query_parts, ' UNION ALL ') || ') subq';

    -- Execute the combined query
    EXECUTE query_text INTO result;
    RETURN COALESCE(result, '{}'::JSON);

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %, Query: %', SQLERRM, query_text;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- The total supply is too large to be stored as a number in netdata.
CREATE OR REPLACE FUNCTION get_latest_total_supply()
RETURNS TEXT AS $$
DECLARE
    supply TEXT;
BEGIN
    SELECT (tags->>'supply') INTO supply
    FROM manifest_tokenomics_total_supply
    ORDER BY time DESC
    LIMIT 1;

    RETURN COALESCE(supply, '0');
END;
$$ LANGUAGE plpgsql;

-- The total supply is too large to be stored as a number in netdata.
CREATE OR REPLACE FUNCTION get_aggregated_total_supply(
    interval_str VARCHAR DEFAULT '1 hour',
    time_from TIMESTAMPTZ DEFAULT NULL,
    time_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    "timestamp" TIMESTAMPTZ,
    "value" TEXT
) AS $$
BEGIN
    IF time_from IS NULL THEN
        time_from := NOW() - INTERVAL '1 day';
    END IF;

    IF time_to IS NULL THEN
        time_to := NOW();
    END IF;

    RETURN QUERY EXECUTE format(
        'SELECT
            time_bucket(%L::INTERVAL, time)::TIMESTAMPTZ AS timestamp,
            AVG((tags->>''supply'')::NUMERIC)::TEXT AS value
        FROM manifest_tokenomics_total_supply
        WHERE time >= %L AND time <= %L
        GROUP BY time_bucket(%L::INTERVAL, time)
        ORDER BY timestamp DESC',
        interval_str, time_from, time_to, interval_str
    );
END;
$$ LANGUAGE plpgsql;

COMMIT;
