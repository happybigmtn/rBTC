#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export MOCK_BUILD=1
export VERIFY=0
export RUN_NODE=0
export DATADIR="$TMPDIR/rbitcoin"

./scripts/agent_install.sh v0.0.0-test >/tmp/rbtc_agent_install.txt

if [[ ! -f "$DATADIR/bitcoin.conf" ]]; then
  echo "FAIL: bitcoin.conf not created"
  exit 1
fi

echo "PASS: agent_install.sh"
