#!/usr/bin/env sh

if ! migrate -path /migrations -database postgres://postgres:postgres@timescaledb_pgtap:5432/metrics?sslmode=disable up
then
  echo "Migration failed"
  exit 1
fi
touch /tmp/SUCCESS
tail -f /dev/null