#!/usr/bin/env bash
set -euo pipefail

ADDRESS=""
DATADIR="${DATADIR:-./data}"
NETWORK="${NETWORK:-regtest}"
BTC_CLI="${BTC_CLI:-./build/bitcoin-cli}"
WALLET_NAME="${WALLET_NAME:-rbtc}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --address)
      ADDRESS="$2"; shift 2;;
    --datadir)
      DATADIR="$2"; shift 2;;
    --network)
      NETWORK="$2"; shift 2;;
    *)
      shift;;
  esac
done

if [[ ! -x "$BTC_CLI" ]]; then
  echo "FAIL: bitcoin-cli not found: $BTC_CLI" >&2
  exit 1
fi

if [[ -z "$ADDRESS" ]]; then
  if ! $BTC_CLI -$NETWORK -datadir="$DATADIR" listwallets | grep -q "\"$WALLET_NAME\""; then
    if $BTC_CLI -$NETWORK -datadir="$DATADIR" listwalletdir | grep -q "\"$WALLET_NAME\""; then
      $BTC_CLI -$NETWORK -datadir="$DATADIR" loadwallet "$WALLET_NAME" >/dev/null
    else
      $BTC_CLI -$NETWORK -datadir="$DATADIR" -named createwallet wallet_name="$WALLET_NAME" disable_private_keys=false blank=false passphrase="" >/dev/null
    fi
  fi
  ADDRESS=$($BTC_CLI -$NETWORK -datadir="$DATADIR" -rpcwallet="$WALLET_NAME" getnewaddress)
fi

$BTC_CLI -$NETWORK -datadir="$DATADIR" -rpcwallet="$WALLET_NAME" generatetoaddress 1 "$ADDRESS" >/tmp/rbtc_mine.json

height=$($BTC_CLI -$NETWORK -datadir="$DATADIR" getblockcount)

echo "Mined block at height $height to $ADDRESS"
