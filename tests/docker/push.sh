#!/usr/bin/env sh

if ! curl --data-binary @/geo.prom http://pushgateway_test:9091/metrics/job/geo
then
  echo "Common fixture failed"
  exit 1
fi

if ! curl --data-binary @/common.prom http://pushgateway_test:9091/metrics/job/common
then
  echo "Common fixture failed"
  exit 1
fi

if ! curl --data-binary @/tokenomic.prom http://pushgateway_test:9091/metrics/job/tokenomic
then
  echo "Tokenomic fixture failed"
  exit 1
fi

touch /tmp/SUCCESS
tail -f /dev/null