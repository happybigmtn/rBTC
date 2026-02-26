#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${DEPLOY_LOG_DIR:-$ROOT_DIR/deploy-logs}"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"
REMOTE_ROOT="${FLEET_REMOTE_ROOT:-/opt/rbitcoin}"
DATADIR="${FLEET_DATADIR:-/root/.rbitcoin}"
RESET_DATADIR="${RESET_DATADIR:-1}"
MINER_CPU_PERCENT="${MINER_CPU_PERCENT:-25}"
MINER_MAX_THREADS="${MINER_MAX_THREADS:-2}"
TAG="${1:-}"

declare -a FLEET_IPS=(
  "95.111.227.14"
  "95.111.229.108"
  "95.111.239.142"
  "161.97.83.147"
  "161.97.97.83"
  "161.97.114.192"
  "161.97.117.0"
  "194.163.144.177"
  "185.218.126.23"
  "185.239.209.227"
)

if [[ -z "$TAG" ]]; then
  TAG="$("$ROOT_DIR/scripts/fetch_upstream_release.sh")"
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL: fleet SSH key not found at $KEY_PATH" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

SSH_OPTS=(
  -i "$KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=no
)

PEERS_CSV="$(IFS=,; echo "${FLEET_IPS[*]}")"

deploy_one() {
  local ip="$1"

  tar -C "$ROOT_DIR" \
    --exclude=".git" \
    --exclude=".cache" \
    --exclude=".gnupg" \
    --exclude="build" \
    --exclude="runtime" \
    --exclude="deploy-logs" \
    -czf - . \
    | ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" \
      "mkdir -p '$REMOTE_ROOT' && tar -xzf - -C '$REMOTE_ROOT'"

  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s -- \
    "$TAG" "$REMOTE_ROOT" "$DATADIR" "$RESET_DATADIR" "$MINER_CPU_PERCENT" \
    "$MINER_MAX_THREADS" "$ip" "$PEERS_CSV" <<'REMOTE'
set -euo pipefail
TAG="$1"
REMOTE_ROOT="$2"
DATADIR="$3"
RESET_DATADIR="$4"
MINER_CPU_PERCENT="$5"
MINER_MAX_THREADS="$6"
SELF_IP="$7"
PEERS_CSV="$8"

export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y >/dev/null
  apt-get install -y \
    autoconf automake build-essential cmake curl git gpg jq libcurl4-openssl-dev \
    libdb++-dev libdb-dev libtool pkg-config python3 >/dev/null
fi

mkdir -p "$REMOTE_ROOT"
cd "$REMOTE_ROOT"

if [[ "$RESET_DATADIR" == "1" && -d "$DATADIR" ]]; then
  ts="$(date -u +%Y%m%d-%H%M%S)"
  mv "$DATADIR" "${DATADIR}.bak-$ts"
fi

START_MINER=0 RUN_NODE=1 VERIFY=1 DATADIR="$DATADIR" NETWORK=main ./install.sh "$TAG"

CONF="$DATADIR/bitcoin.conf"
tmp_conf="$(mktemp)"
awk '
  BEGIN { skip=0 }
  /# rbitcoin-fleet-start/ { skip=1; next }
  /# rbitcoin-fleet-end/ { skip=0; next }
  skip == 0 { print }
' "$CONF" > "$tmp_conf"
mv "$tmp_conf" "$CONF"

IFS=',' read -r -a peers <<< "$PEERS_CSV"
{
  echo "# rbitcoin-fleet-start"
  echo "dnsseed=0"
  echo "listen=1"
  for peer in "${peers[@]}"; do
    [[ "$peer" == "$SELF_IP" ]] && continue
    echo "addnode=${peer}:19333"
  done
  echo "# rbitcoin-fleet-end"
} >> "$CONF"

if ./build/bitcoin-cli -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1; then
  ./build/bitcoin-cli -datadir="$DATADIR" stop || true
  sleep 2
fi

DETACH=1 ./scripts/run_node.sh --datadir "$DATADIR" --network main

MINER_BACKGROUND=1 PEER_BOOTSTRAP=0 \
MINER_CPU_PERCENT="$MINER_CPU_PERCENT" MINER_MAX_THREADS="$MINER_MAX_THREADS" \
./scripts/start_cpu_miner.sh --datadir "$DATADIR" --network main

height="$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getblockcount)"
besthash="$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getbestblockhash)"
conns="$(./build/bitcoin-cli -rpcwait -datadir="$DATADIR" getconnectioncount)"
miner_pid="$(pgrep -fa 'minerd|cpuminer' | head -n1 || true)"

echo "DEPLOY_OK ip=$SELF_IP height=$height conns=$conns hash=$besthash"
echo "MINER_PROCESS ${miner_pid:-not-found}"
REMOTE
}

declare -A DEPLOY_PIDS=()

for ip in "${FLEET_IPS[@]}"; do
  echo "[$ip] starting deploy..."
  deploy_one "$ip" >"$LOG_DIR/$ip.log" 2>&1 &
  DEPLOY_PIDS["$ip"]=$!
done

failed=0
echo
echo "Deployment results:"
for ip in "${FLEET_IPS[@]}"; do
  if wait "${DEPLOY_PIDS[$ip]}"; then
    echo "  $ip  OK"
  else
    echo "  $ip  FAIL (see $LOG_DIR/$ip.log)"
    failed=1
  fi
done

echo
echo "Per-node summary lines:"
for ip in "${FLEET_IPS[@]}"; do
  if [[ -f "$LOG_DIR/$ip.log" ]]; then
    grep -E 'DEPLOY_OK|MINER_PROCESS' "$LOG_DIR/$ip.log" || true
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo
echo "PASS: fleet deploy completed for tag $TAG"
