#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-$HOME/.rbitcoin}"
NETWORK="${NETWORK:-main}"
ADDRESS=""
AUTO_INSTALL="${AUTO_INSTALL:-1}"
MINER_THREADS="${MINER_THREADS:-}"
MINER_CPU_PERCENT="${MINER_CPU_PERCENT:-50}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datadir)
      DATADIR="$2"; shift 2;;
    --network)
      NETWORK="$2"; shift 2;;
    --address)
      ADDRESS="$2"; shift 2;;
    --threads)
      MINER_THREADS="$2"; shift 2;;
    --cpu-percent)
      MINER_CPU_PERCENT="$2"; shift 2;;
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

MINER=""
if command -v minerd >/dev/null 2>&1; then
  MINER=minerd
elif command -v cpuminer >/dev/null 2>&1; then
  MINER=cpuminer
elif [[ -x "$HOME/.local/bin/minerd" ]]; then
  MINER="$HOME/.local/bin/minerd"
elif [[ -x "$HOME/.local/bin/cpuminer" ]]; then
  MINER="$HOME/.local/bin/cpuminer"
fi

if [[ -z "$MINER" ]]; then
  echo "FAIL: no CPU miner found. Install cpuminer/minerd." >&2
  exit 1
fi

# Compute threads if not explicitly set
if [[ -z "$MINER_THREADS" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    cores=$(nproc)
  elif command -v getconf >/dev/null 2>&1; then
    cores=$(getconf _NPROCESSORS_ONLN)
  else
    cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
  fi

  # Clamp percent 1-100
  if [[ -z "$MINER_CPU_PERCENT" ]]; then
    MINER_CPU_PERCENT=50
  fi
  if (( MINER_CPU_PERCENT < 1 )); then MINER_CPU_PERCENT=1; fi
  if (( MINER_CPU_PERCENT > 100 )); then MINER_CPU_PERCENT=100; fi

  MINER_THREADS=$(( (cores * MINER_CPU_PERCENT + 99) / 100 ))
  if (( MINER_THREADS < 1 )); then MINER_THREADS=1; fi
fi

if [[ -z "$ADDRESS" ]]; then
  if [[ ! -x ./build/bitcoin-cli ]]; then
    echo "FAIL: bitcoin-cli not found at ./build/bitcoin-cli" >&2
    exit 1
  fi
  ADDRESS=$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getnewaddress)
fi

echo "Starting CPU miner with $MINER_THREADS thread(s) (~${MINER_CPU_PERCENT}% CPU)"

$MINER -a sha256d -t "$MINER_THREADS" -o http://127.0.0.1:"$RPC_PORT" -u "$RPC_USER" -p "$RPC_PASS"
