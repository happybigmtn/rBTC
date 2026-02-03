#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

BUILD_DIR="$TMPDIR/build"
MOCK_BUILD=1 BUILD_DIR="$BUILD_DIR" ./scripts/build_from_tag.sh v0.0.0-test >/dev/null

if [[ ! -x "$BUILD_DIR/bitcoind" ]]; then
  echo "FAIL: bitcoind not built"
  exit 1
fi

if [[ ! -x "$BUILD_DIR/bitcoin-cli" ]]; then
  echo "FAIL: bitcoin-cli not built"
  exit 1
fi

echo "PASS: mock build produced binaries"
