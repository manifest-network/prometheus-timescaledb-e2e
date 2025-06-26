#!/bin/sh
set -e

# BusyBox date doesn't support -d option, so we need to install coreutils
apk add --update coreutils --no-cache

FROM=""
TO=""
BINS=1
VMALERT_ARGS=""

while [ $# -gt 0 ]; do
  case $1 in
    --from=*) FROM="${1#*=}"; shift ;;
    --to=*) TO="${1#*=}"; shift ;;
    --bins=*) BINS="${1#*=}"; shift ;;
    *) VMALERT_ARGS="${VMALERT_ARGS:+$VMALERT_ARGS }$1"; shift ;;
  esac
done

[ -n "$FROM" ] || { echo "Error: missing --from=DATE"; exit 1; }

# Compute epoch seconds for start and end
FROM_SEC=$(date -u -d "$FROM 00:00:00" +%s)
TO_SEC=$(date -u -d "$TO" +%s)
INTERVAL=$(( (TO_SEC - FROM_SEC) / BINS ))

# initialize so first start is exactly FROM_SEC
last_end_sec=$((FROM_SEC - 86400))

for i in $(seq 0 $((BINS - 1))); do
  if [ "$i" -eq 0 ]; then
    START_SEC=$FROM_SEC
  else
    START_SEC=$((last_end_sec + 86400))
  fi

  if [ "$i" -eq $((BINS - 1)) ]; then
    END_SEC=$TO_SEC
  else
    END_SEC=$((START_SEC + INTERVAL))
  fi

  if [ "$END_SEC" -gt "$TO_SEC" ]; then
    END_SEC="$TO_SEC"
  fi

  if [ "$START_SEC" -gt "$END_SEC" ]; then
    continue
  fi

  last_end_sec=$END_SEC

  DATE_FROM=$(date -u -d "@$START_SEC" "+%Y-%m-%d")
  DATE_TO=$(date -u -d "@$END_SEC"   "+%Y-%m-%d")

  TIME_FROM="${DATE_FROM}T00:00:00Z"
  TIME_TO="${DATE_TO}T00:00:00Z"

  /vmalert-prod \
    --remoteWrite.disablePathAppend \
    --remoteWrite.showURL \
    --remoteWrite.url="${TELEGRAF_URL}" \
    --datasource.showURL \
    --datasource.url="${DATASOURCE_URL}" \
    --replay.disableProgressBar \
    --replay.timeFrom="$TIME_FROM" \
    --replay.timeTo="$TIME_TO" \
    --replay.rulesDelay=0 \
    $VMALERT_ARGS
done
