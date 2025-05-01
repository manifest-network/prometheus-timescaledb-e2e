#!/bin/sh
set -e

# BusyBox date doesn't support -d option, so we need to install coreutils
apk add --update coreutils --no-cache

FROM=""
VMALERT_ARGS=""

while [ $# -gt 0 ]; do
  case $1 in
    --from=*)
      FROM="${1#*=}"
      shift
      ;;
    *)
      # Append to space-separated string instead of using bash array
      if [ -z "$VMALERT_ARGS" ]; then
        VMALERT_ARGS="$1"
      else
        VMALERT_ARGS="$VMALERT_ARGS $1"
      fi
      shift
      ;;
  esac
done

REPLAY_TIME_ARG=""
if [ -n "$FROM" ]; then
  REPLAY_TIME_ARG="--replay.timeFrom=$(date -u -d "$FROM" "+%Y-%m-%dT%H:%M:%SZ")"
fi

# Execute the original command with passed arguments
exec /vmalert-prod \
  --remoteWrite.disablePathAppend \
  --remoteWrite.showURL \
  --remoteWrite.url="${TELEGRAF_URL}" \
  --datasource.showURL \
  --datasource.url="${DATASOURCE_URL}" \
  --replay.maxDatapointsPerQuery=1 \
  --replay.disableProgressBar \
  "$REPLAY_TIME_ARG" \
  "$VMALERT_ARGS"