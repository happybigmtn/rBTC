#!/usr/bin/env bash
set -euo pipefail

MOCK_LATEST_TAG="v99.88.77" ./scripts/fetch_upstream_release.sh > /tmp/rbtc_tag.txt

tag=$(cat /tmp/rbtc_tag.txt | tr -d '\n')
if [[ "$tag" != "v99.88.77" ]]; then
  echo "FAIL: expected v99.88.77 got $tag"
  exit 1
fi

echo "PASS: fetch_upstream_release.sh returns mock tag"
