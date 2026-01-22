BEGIN;

DROP FUNCTION IF EXISTS api.get_all_latest_cumsum_metrics();
DROP FUNCTION IF EXISTS api.get_all_latest_common_metrics();
DROP FUNCTION IF EXISTS api.get_all_latest_testnet_metrics();
DROP FUNCTION IF EXISTS api.get_all_latest_mainnet_metrics();
DROP FUNCTION IF EXISTS api.get_latest_mainnet_total_supply_value();
DROP FUNCTION IF EXISTS api.get_latest_mainnet_circulating_supply_value();
DROP FUNCTION IF EXISTS api.get_all_latest_token_metrics(TEXT);
DROP FUNCTION IF EXISTS api.get_latest_market_cap(TEXT);
DROP FUNCTION IF EXISTS api.get_agg_market_cap(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.get_latest_fdv(TEXT);
DROP FUNCTION IF EXISTS api.get_agg_fdv(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.get_latest_burned_supply(TEXT);
DROP FUNCTION IF EXISTS api.get_agg_burned_supply(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.get_latest_circulating_supply(TEXT);
DROP FUNCTION IF EXISTS api.get_agg_circulating_supply(TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.get_latest_geo_coordinates();
DROP FUNCTION IF EXISTS api.get_agg_cumsum_metric(TEXT, TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.get_agg_metric(TEXT, TEXT, INTERVAL, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS api.rm_excluded_address(TEXT);
DROP FUNCTION IF EXISTS api.add_excluded_address(TEXT);
DROP FUNCTION IF EXISTS api.get_excluded_addresses();

COMMIT;
