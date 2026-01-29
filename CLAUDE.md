# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

E2E Prometheus to TimescaleDB pipeline for storing and serving Manifest Network metrics. The system collects Prometheus metrics, stores them in TimescaleDB with continuous aggregates, and exposes data via PostgREST REST API.

## Common Commands

```bash
# Start all services
docker compose up -d

# Run tests (takes ~6 minutes, uses pgTAP)
make test

# Run migrations only
docker compose up migrate

# Refresh continuous aggregates after backfill
docker compose up refresh_aggregates

# Connect to database
docker exec -it timescaledb psql -U postgres -d metrics
```

## Architecture

**Data Flow:**
```
Prometheus → vmalert (recording rules) → Telegraf → TimescaleDB → PostgREST → Caddy → API Clients
```

**Key Services:**
- **timescaledb** - PostgreSQL 17 with TimescaleDB extension
- **telegraf** - Receives Prometheus remote write on port 9273, writes to staging tables
- **vmalert** - Live recording rules (runs continuously)
- **vmalert_backfill_*** - Historical data backfill services (1Y, 1W, forever)
- **postgrest** - Auto-generated REST API from `api` schema
- **caddy** - Reverse proxy on port 3000 with compression

**Database Schemas:**
- `api` - Public functions exposed via PostgREST
- `internal` - Core metrics hypertable and tags
- `cumsum` - Cumulative sum metrics (web requests, network transfers)
- `geo` - Geolocation data
- `staging_internal`, `staging_cumsum` - Unlogged staging tables for deduplication

## Deduplication Strategy

Telegraf may send duplicates. Staging tables with statement-level triggers handle this:
1. Telegraf writes to `staging_*` schemas (unlogged tables)
2. Triggers bulk insert to main tables with `ON CONFLICT DO NOTHING`
3. Unique constraint: `(time, tag_id, name, schema)`

## Migrations

Located in `timescaledb/migrations/`, run automatically via `migrate` service:
- `001_init_schema_tables.up.sql` - Schemas, roles, hypertables, staging tables
- `002_init_aggregates.up.sql` - Continuous aggregates and refresh policies
- `003_init_api_functions.up.sql` - API functions
- `004_init_performance.up.sql` - Indexes and compression policies

## Testing

Tests use pgTAP framework in `tests/sql/*.test.sql`. The test suite:
1. Starts Prometheus with pushgateway containing fixture data
2. vmalert records metrics to Telegraf
3. After 6-minute wait for aggregates, pg_prove runs tests

Run individual test exploration:
```bash
cd tests/docker && docker compose up --build
```

## Key Configuration Files

- `docker-compose.yml` - Service orchestration with health checks and dependencies
- `telegraf/telegraf.conf` - Starlark processors route metrics by schema
- `vmalert/live_rules.yml` - ~60+ recording rules for live metrics
- `vmalert/backfill_*.yml` - Recording rules for historical backfill
- `.env` - `DATASOURCE_URL` (Prometheus) and `TELEGRAF_URL` (remote write endpoint)

## API Endpoints

PostgREST exposes functions at `http://localhost:3000/rpc/`:
- `get_agg_metric` - Raw metrics with bucketing
- `get_agg_cumsum_metric` - Cumulative metrics
- `get_agg_circulating_supply`, `_fdv`, `_market_cap`, `_burned_supply` - Tokenomics
- `get_latest_geo_coordinates` - Validator locations
- `get_excluded_addresses` - Tokenomics exclusion list

## PostgREST Authentication

- Anonymous role `web_anon` (read-only)
- Authenticated role `writer` (can modify excluded addresses)
- Demo JWT for writer role in README.md
