#!/usr/bin/env bash
set -euo pipefail

GOOD_HASH="$(tr -d ' \n' < ./patch/immutable.patch.sha256)"

NETWORK_PATCH_HASH="$GOOD_HASH" ./scripts/enforce_network_patch_pin.sh >/tmp/rbtc_patch_pin_pass.txt

if ! rg -q '^PASS: network patch pin verified' /tmp/rbtc_patch_pin_pass.txt; then
  echo "FAIL: expected pass output from enforce_network_patch_pin.sh"
  exit 1
fi

if NETWORK_PATCH_HASH="0000000000000000000000000000000000000000000000000000000000000000" \
  ./scripts/enforce_network_patch_pin.sh >/tmp/rbtc_patch_pin_fail.txt 2>&1; then
  echo "FAIL: expected enforce_network_patch_pin.sh to fail on mismatched hash"
  exit 1
fi

if ! rg -q 'FAIL: local patch hash does not match required network hash' /tmp/rbtc_patch_pin_fail.txt; then
  echo "FAIL: expected mismatch error output"
  exit 1
fi

echo "PASS: network patch pin"
