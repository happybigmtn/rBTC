#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-./data}"
NETWORK="${NETWORK:-main}"
BITCOIND="${BITCOIND:-./build/bitcoind}"
BITCOIN_CLI="${BITCOIN_CLI:-./build/bitcoin-cli}"
DETACH="${DETACH:-1}"

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

if [[ -x "$BITCOIN_CLI" ]]; then
  if "$BITCOIN_CLI" -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1; then
    echo "Node already running (datadir=$DATADIR)"
    exit 0
  fi
fi

mkdir -p "$DATADIR"

CHAIN_FLAG=""
if [[ "$NETWORK" != "main" && "$NETWORK" != "mainnet" ]]; then
  CHAIN_FLAG="-$NETWORK"
fi

if [[ "$DETACH" == "1" ]]; then
  nohup "$BITCOIND" $CHAIN_FLAG -datadir="$DATADIR" >/tmp/rbitcoin-node.log 2>&1 &
else
  "$BITCOIND" $CHAIN_FLAG -datadir="$DATADIR"
fi

echo "Node started ($NETWORK) with datadir=$DATADIR"
