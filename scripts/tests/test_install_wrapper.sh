#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export MOCK_BUILD=1
export VERIFY=0
export RUN_NODE=0
export DATADIR="$TMPDIR/rbitcoin"

# Avoid miner dependency in tests
export START_MINER=0

./install.sh v0.0.0-test >/tmp/rbtc_install_wrapper.txt

if [[ ! -f "$DATADIR/bitcoin.conf" ]]; then
  echo "FAIL: bitcoin.conf not created by install.sh"
  exit 1
fi

echo "PASS: install.sh wrapper"
