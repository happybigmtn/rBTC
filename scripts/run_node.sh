#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-./data}"
NETWORK="${NETWORK:-main}"
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

CHAIN_FLAG=""
if [[ "$NETWORK" != "main" && "$NETWORK" != "mainnet" ]]; then
  CHAIN_FLAG="-$NETWORK"
fi

$BITCOIND $CHAIN_FLAG -datadir="$DATADIR" -daemon

echo "Node started ($NETWORK) with datadir=$DATADIR"
