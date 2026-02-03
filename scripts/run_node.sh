#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-./data}"
NETWORK="${NETWORK:-regtest}"
BITCOIND="${BITCOIND:-./build/bitcoind}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datadir)
      DATADIR="$2"; shift 2;;
    --network)
      NETWORK="$2"; shift 2;;
    *)
      shift;;
  esac
done

if [[ ! -x "$BITCOIND" ]]; then
  echo "FAIL: bitcoind not found: $BITCOIND" >&2
  exit 1
fi

mkdir -p "$DATADIR"

$BITCOIND -$NETWORK -datadir="$DATADIR" -daemon

echo "Node started ($NETWORK) with datadir=$DATADIR"
