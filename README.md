# E2E Prometheus to TimescaleDB

This project provides a complete end-to-end pipeline for storing Prometheus metrics in TimescaleDB with a REST API via PostgREST.

## Architecture

```mermaid
flowchart LR
    Prometheus[Prometheus]

    subgraph DockerCompose[Docker Compose Stack]
        vmalert[vmalert]
        Telegraf[Telegraf]
        TimescaleDB[(TimescaleDB)]
        PostgREST[PostgREST]
        Caddy[Caddy]

        subgraph Backfill
            backfill_1Y[backfill_1Y]
            backfill_1W[backfill_1W]
            backfill_forever[backfill_forever]
        end
        refresh[refresh_aggregates]
    end

    Client[API Client]

    Prometheus -->|query| vmalert
    Prometheus -->|query| Backfill
    vmalert -->|remote write| Telegraf
    Backfill -->|remote write| Telegraf
    Backfill -.->|completed| refresh
    Telegraf -->|insert| TimescaleDB
    refresh -->|bulk refresh| TimescaleDB
    TimescaleDB --> PostgREST
    PostgREST --> Caddy
    Caddy --> Client
```

### Components

| Service | Description |
|---------|-------------|
| **TimescaleDB** | PostgreSQL with time-series extensions for metric storage |
| **Telegraf** | Receives Prometheus remote write and writes to TimescaleDB |
| **PostgREST** | Auto-generates REST API from database schema |
| **Caddy** | Reverse proxy with rate limiting |
| **vmalert** | Processes recording rules and backfills historical data |

## Quick Start

```bash
# Start everything
docker compose up -d

# View logs
docker compose logs -f
```

## Clean Slate Setup

When starting from scratch with historical data backfill:

```bash
docker compose up -d
```

Docker Compose handles the dependency chain automatically:

1. **timescaledb** starts and waits for healthy
2. **migrate** runs and completes
3. **telegraf**, **vmalert**, and **backfill containers** start
4. **refresh_aggregates** runs after all backfill containers complete (bulk refreshes continuous aggregates)
5. **postgrest** and **caddy** start

## Database Schema

### Schemas

| Schema | Purpose |
|--------|---------|
| `api` | Public API functions (exposed via PostgREST) |
| `internal` | Core metrics hypertable and tag table |
| `cumsum` | Cumulative sum metrics (e.g., request counts) |
| `geo` | Geographic coordinate data |
| `staging_internal` | Staging tables for duplicate handling |
| `staging_cumsum` | Staging tables for cumulative metrics |

### Tables

**`internal.prometheus_remote_write`** - Main metrics hypertable
- `time`, `tag_id`, `name`, `schema`, `value`
- Unique constraint on `(time, tag_id, name, schema)`
- 1 year retention policy, compression after 7 days

**`cumsum.prometheus_remote_write`** - Cumulative metrics hypertable
- Same structure, no retention policy (needs full history)

**`internal.prometheus_remote_write_tag`** - Tag metadata
- `tag_id`, `host`, `instance`, `country_name`, `city`, `supply`, etc.

### Continuous Aggregates

| Aggregate | Source | Purpose |
|-----------|--------|---------|
| `cumsum.all_metrics_minute` | cumsum schema | 1-minute rollups of cumulative metrics |
| `internal.cagg_calculated_metric` | internal schema | Tokenomics calculations |
| `internal.prometheus_mainnet_1m` | internal (mainnet) | Mainnet metrics |
| `internal.prometheus_testnet_1m` | internal (testnet) | Testnet metrics |
| `internal.prometheus_common_1m` | internal (common) | Common metrics |
| `geo.latest_coords` | internal (geo) | Latest validator coordinates |

### Refresh Policies

Continuous aggregate policies use `start_offset => INTERVAL '1 hour'` to only process recent data incrementally. Historical data must be bulk-refreshed after backfill.

## Duplicate Handling

Telegraf may send duplicate metrics in batches. Since Telegraf's PostgreSQL output plugin doesn't natively support `ON CONFLICT DO NOTHING`, we implement a workaround using staging tables:

1. **Staging Tables** - Telegraf writes to `staging_*` schemas (UNLOGGED tables for speed)
2. **Statement-level Triggers** - Bulk insert to main tables with `ON CONFLICT DO NOTHING`
3. **No Data Loss** - Duplicates are silently ignored, unique data is preserved

```
Telegraf ──COPY──► staging_internal.prometheus_remote_write
                              │
                              ▼ (trigger)
                   INSERT ... ON CONFLICT DO NOTHING
                              │
                              ▼
                   internal.prometheus_remote_write
```

## API Functions

Available at `http://localhost:3000/rpc/<function_name>`

| Function | Description |
|----------|-------------|
| `get_agg_metric` | Aggregated raw metrics |
| `get_agg_cumsum_metric` | Cumulative sum metrics |
| `get_agg_circulating_supply` | Circulating supply over time |
| `get_agg_fdv` | Fully diluted valuation |
| `get_agg_market_cap` | Market capitalization |
| `get_agg_burned_supply` | Burned tokens |
| `get_latest_geo_coordinates` | Validator locations |
| `get_all_latest_mainnet_metrics` | All latest mainnet values |
| `get_excluded_addresses` | Excluded address list |

### Example API Calls

```bash
# Get circulating supply for last 24 hours
curl "http://localhost:3000/rpc/get_agg_circulating_supply?p_schema=mainnet&p_interval=1%20hour&p_from=2024-01-01T00:00:00Z&p_to=2024-01-02T00:00:00Z"

# Get latest FDV
curl "http://localhost:3000/rpc/get_latest_fdv?p_schema=mainnet"

# Get validator coordinates
curl "http://localhost:3000/rpc/get_latest_geo_coordinates"
```

## Migrations

Migrations are managed by [golang-migrate](https://github.com/golang-migrate/migrate) and located in `timescaledb/migrations/`:

| Migration | Description |
|-----------|-------------|
| `001_init_schema_tables` | Schemas, roles, hypertables, staging tables |
| `002_init_aggregates` | Continuous aggregates and refresh policies |
| `003_init_api_functions` | API functions for PostgREST |
| `004_init_performance` | Indexes and compression policies |

### Running Migrations Manually

```bash
docker compose up migrate
```

## Scripts

### Bulk Refresh Aggregates

After backfilling historical data, run this to populate continuous aggregates:

```bash
docker exec -i timescaledb psql -U postgres -d metrics < timescaledb/scripts/bulk_refresh_aggregates.sql
```

Or use the Docker service:

```bash
docker compose up refresh_aggregates
```

## Testing

Tests use [pgTAP](https://pgtap.org/) and are located in `tests/sql/`:

```bash
make test
```

> **Note:** Tests take around 6 minutes to complete as they wait for continuous aggregates to populate with test data.

## Configuration

### Environment Variables

Create a `.env` file with:

```env
TELEGRAF_URL=http://localhost:9273/write
DATASOURCE_URL=http://localhost:9090
```

### Telegraf

Configuration in `telegraf/telegraf.conf`:
- Receives Prometheus remote write on `:9273`
- Writes to staging tables with `tags_as_foreign_keys`
- Exposes metrics on `:9274/metrics`

### PostgREST

- Exposes `api` schema functions
- Anonymous role: `web_anon` (read-only)
- Authenticated role: `writer` (can modify excluded addresses)

JWT token for writer role:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoid3JpdGVyIn0.AVwQ4jGud_cxb8dzR_XTskiDq2CrfTX7QmPVndrsOGM
```

> **Warning:** The JWT secret and token are hardcoded. This project is intended for testing and demonstration purposes only, not for production use.

## Troubleshooting

### Continuous Aggregate Log Spam

If you see thousands of "continuous aggregate refresh" log messages:

```
LOG: continuous aggregate refresh (individual invalidation) on "all_metrics_minute" in window [...] (batch 44989 of 1119626)
```

This means aggregates are catching up minute-by-minute. Run the bulk refresh:

```bash
docker compose up refresh_aggregates
```

### Telegraf Duplicate Errors

If Telegraf logs show duplicate key violations, ensure it's writing to `staging_*` schemas (not directly to `internal`/`cumsum`).

### Database Connection Issues

```bash
# Check TimescaleDB is healthy
docker compose exec timescaledb pg_isready -U postgres -d metrics

# Connect directly
docker compose exec timescaledb psql -U postgres -d metrics
```
