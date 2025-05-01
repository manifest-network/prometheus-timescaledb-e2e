BEGIN;

CREATE OR REPLACE FUNCTION get_aggregated_metrics(
    metric_name VARCHAR,
    interval_str VARCHAR DEFAULT '1 hour',
    time_from TIMESTAMPTZ DEFAULT NULL,
    time_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    "timestamp" TIMESTAMPTZ,
    "value" DOUBLE PRECISION
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
            AVG(value) AS value
        FROM %s
        WHERE time >= %L AND time <= %L',
        interval_str, metric_name, time_from, time_to
    );

    query_text := query_text || ' GROUP BY time_bucket(%L::INTERVAL, time) ORDER BY timestamp DESC';

    RETURN QUERY EXECUTE format(query_text, interval_str);
END;
$$ LANGUAGE plpgsql;

COMMIT;