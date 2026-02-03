#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-$HOME/.rbitcoin}"
NETWORK="${NETWORK:-main}"
ADDRESS=""
AUTO_INSTALL="${AUTO_INSTALL:-1}"
MINER_THREADS="${MINER_THREADS:-}"
MINER_CPU_PERCENT="${MINER_CPU_PERCENT:-25}"
MINER_MAX_THREADS="${MINER_MAX_THREADS:-2}"
WALLET_NAME="${WALLET_NAME:-rbtc}"
MINER_BACKGROUND="${MINER_BACKGROUND:-0}"
PEER_BOOTSTRAP="${PEER_BOOTSTRAP:-1}"
ADDRESS_TYPE="${ADDRESS_TYPE:-legacy}"

# Ensure locally installed tools are discoverable
export PATH="$HOME/.local/bin:$PATH"

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
P2P_PORT=$(grep -E '^port=' "$CONF" | head -n1 | cut -d= -f2)

if [[ -z "$RPC_PORT" ]]; then
  RPC_PORT=19332
fi
if [[ -z "$P2P_PORT" ]]; then
  P2P_PORT=19333
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

get_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

maybe_start_peer() {
  if [[ "$PEER_BOOTSTRAP" != "1" ]]; then
    return
  fi
  local conn
  conn=$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getconnectioncount 2>/dev/null || echo "")
  if [[ "$conn" != "0" && -n "$conn" ]]; then
    return
  fi

  local peer_datadir="${DATADIR}-peer"
  mkdir -p "$peer_datadir"
  local peer_port
  peer_port=$(get_free_port)

  echo "No peers detected. Starting local peer on port $peer_port..."
  nohup ./build/bitcoind \
    -datadir="$peer_datadir" \
    -port="$peer_port" \
    -bind=127.0.0.1 \
    -listen=1 \
    -server=0 \
    -dnsseed=0 \
    -connect=127.0.0.1:"$P2P_PORT" \
    >/tmp/rbitcoin-peer.log 2>&1 &

  # wait briefly for connection
  for _ in {1..10}; do
    sleep 1
    conn=$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getconnectioncount 2>/dev/null || echo "")
    if [[ "$conn" != "0" && -n "$conn" ]]; then
      echo "Peer connected."
      break
    fi
  done
}

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
    MINER_CPU_PERCENT=25
  fi
  if (( MINER_CPU_PERCENT < 1 )); then MINER_CPU_PERCENT=1; fi
  if (( MINER_CPU_PERCENT > 100 )); then MINER_CPU_PERCENT=100; fi

  MINER_THREADS=$(( (cores * MINER_CPU_PERCENT + 99) / 100 ))
  if (( MINER_THREADS < 1 )); then MINER_THREADS=1; fi

  # Cap by max threads if set
  if [[ -n "$MINER_MAX_THREADS" ]]; then
    if (( MINER_MAX_THREADS < 1 )); then MINER_MAX_THREADS=1; fi
    if (( MINER_THREADS > MINER_MAX_THREADS )); then
      MINER_THREADS=$MINER_MAX_THREADS
    fi
  fi
fi

if [[ -z "$ADDRESS" ]]; then
  if [[ ! -x ./build/bitcoin-cli ]]; then
    echo "FAIL: bitcoin-cli not found at ./build/bitcoin-cli" >&2
    exit 1
  fi
  # Ensure a wallet is loaded or created
  if ! ./build/bitcoin-cli -rpcwait -datadir="$DATADIR" listwallets | grep -q "\"$WALLET_NAME\""; then
    if ./build/bitcoin-cli -rpcwait -datadir="$DATADIR" listwalletdir | grep -q "\"$WALLET_NAME\""; then
      ./build/bitcoin-cli -rpcwait -datadir="$DATADIR" loadwallet "$WALLET_NAME" >/dev/null
    else
      ./build/bitcoin-cli -rpcwait -datadir="$DATADIR" -named createwallet wallet_name="$WALLET_NAME" disable_private_keys=false blank=false passphrase="" >/dev/null
    fi
  fi
  ADDRESS=$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" -rpcwallet="$WALLET_NAME" getnewaddress "" "$ADDRESS_TYPE")
fi

maybe_start_peer

echo "Starting CPU miner with $MINER_THREADS thread(s) (~${MINER_CPU_PERCENT}% CPU, max ${MINER_MAX_THREADS})"

MINER_ARGS=(-a sha256d -t "$MINER_THREADS" -o "http://127.0.0.1:$RPC_PORT" -u "$RPC_USER" -p "$RPC_PASS" --coinbase-addr "$ADDRESS" --no-getwork)

if [[ "$MINER_BACKGROUND" == "1" ]]; then
  LOG_FILE="$DATADIR/miner.log"
  nohup "$MINER" "${MINER_ARGS[@]}" >"$LOG_FILE" 2>&1 &
  echo "Miner started in background (log: $LOG_FILE)"
  exit 0
fi

$MINER "${MINER_ARGS[@]}"
