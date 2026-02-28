#!/usr/bin/env bash
set -euo pipefail

# One-time script: read each fleet node's current mining address from the
# running cpuminer process and pin it to <datadir>/mining_address so that
# restarts reuse the same address instead of calling getnewaddress.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"

FLEET_CONF="${FLEET_CONF:-$ROOT_DIR/scripts/fleet.conf}"
if [[ ! -f "$FLEET_CONF" ]]; then
  echo "FAIL: fleet config not found at $FLEET_CONF (copy fleet.conf.example)" >&2
  exit 1
fi
source "$FLEET_CONF"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL: fleet SSH key not found at $KEY_PATH" >&2
  exit 1
fi

SSH_OPTS=(
  -i "$KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=no
)

pin_one() {
  local ip="$1"

  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail

pin_address() {
  local label="$1"
  local datadir="$2"
  local addr_file="$datadir/mining_address"

  # Extract --coinbase-addr from running miner for this chain's RPC port
  local rpc_port
  rpc_port=$(grep -E '^rpcport=' "$datadir/bitcoin.conf" 2>/dev/null | head -n1 | cut -d= -f2 || true)
  if [[ -z "$rpc_port" ]]; then
    echo "  [$label] SKIP: no rpcport in $datadir/bitcoin.conf"
    return
  fi

  local addr=""
  # Find miner process targeting this chain's RPC port
  addr=$(ps aux | grep -oP "127\.0\.0\.1:${rpc_port}.*?--coinbase-addr\s+\K\S+" | head -n1 || true)

  if [[ -z "$addr" ]]; then
    echo "  [$label] WARN: no running miner found for port $rpc_port"
    if [[ -f "$addr_file" ]]; then
      echo "  [$label] KEEP: existing pin $(cat "$addr_file")"
    fi
    return
  fi

  if [[ -f "$addr_file" ]]; then
    local existing
    existing=$(cat "$addr_file")
    if [[ "$existing" == "$addr" ]]; then
      echo "  [$label] OK: already pinned $addr"
      return
    fi
    echo "  [$label] UPDATE: $existing -> $addr"
  else
    echo "  [$label] PIN: $addr"
  fi

  echo "$addr" > "$addr_file"
}

pin_address "rBTC" "/root/.rbitcoin"
pin_address "RNG"  "/root/.rng"
REMOTE
}

failed=0

for ip in "${FLEET_IPS[@]}"; do
  echo "[$ip]"
  if pin_one "$ip"; then
    echo "  done"
  else
    echo "  FAIL"
    failed=1
  fi
  echo
done

if [[ "$failed" -ne 0 ]]; then
  echo "FAIL: some nodes failed" >&2
  exit 1
fi

echo "PASS: mining addresses pinned on all ${#FLEET_IPS[@]} nodes"
