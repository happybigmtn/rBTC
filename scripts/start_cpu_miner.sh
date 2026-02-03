#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-$HOME/.rbitcoin}"
NETWORK="${NETWORK:-main}"
ADDRESS=""
AUTO_INSTALL="${AUTO_INSTALL:-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datadir)
      DATADIR="$2"; shift 2;;
    --network)
      NETWORK="$2"; shift 2;;
    --address)
      ADDRESS="$2"; shift 2;;
    *)
      shift;;
  esac
done

CONF="$DATADIR/bitcoin.conf"

if [[ ! -f "$CONF" ]]; then
  echo "FAIL: config not found: $CONF" >&2
  exit 1
fi

RPC_USER=$(grep -E '^rpcuser=' "$CONF" | head -n1 | cut -d= -f2)
RPC_PASS=$(grep -E '^rpcpassword=' "$CONF" | head -n1 | cut -d= -f2)
RPC_PORT=$(grep -E '^rpcport=' "$CONF" | head -n1 | cut -d= -f2)

if [[ -z "$RPC_PORT" ]]; then
  RPC_PORT=19332
fi

if [[ -z "$RPC_USER" || -z "$RPC_PASS" ]]; then
  echo "FAIL: rpcuser/rpcpassword not set in $CONF" >&2
  exit 1
fi

if [[ "$AUTO_INSTALL" == "1" ]]; then
  if ! ./scripts/ensure_cpu_miner.sh; then
    echo "WARN: CPU miner auto-install failed; continuing if miner exists" >&2
  fi
fi

if command -v minerd >/dev/null 2>&1; then
  MINER=minerd
elif command -v cpuminer >/dev/null 2>&1; then
  MINER=cpuminer
else
  echo "FAIL: no CPU miner found. Install cpuminer/minerd." >&2
  exit 1
fi

if [[ -z "$ADDRESS" ]]; then
  if [[ ! -x ./build/bitcoin-cli ]]; then
    echo "FAIL: bitcoin-cli not found at ./build/bitcoin-cli" >&2
    exit 1
  fi
  ADDRESS=$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getnewaddress)
fi

$MINER -a sha256d -o http://127.0.0.1:"$RPC_PORT" -u "$RPC_USER" -p "$RPC_PASS"
