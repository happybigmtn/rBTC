#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-}"
DATADIR="${DATADIR:-$HOME/.rbitcoin}"
NETWORK="${NETWORK:-main}"
VERIFY="${VERIFY:-1}"
START_MINER="${START_MINER:-0}"
RUN_NODE="${RUN_NODE:-1}"
RPC_USER="${RPC_USER:-rbtc}"
RPC_PASS="${RPC_PASS:-}"
RPC_ALLOWIP="${RPC_ALLOWIP:-127.0.0.1}"
RPC_BIND="${RPC_BIND:-0.0.0.0}"
SEED_BOOTSTRAP="${SEED_BOOTSTRAP:-1}"
SEED_PORT="${SEED_PORT:-19333}"
SEED_NODES="${SEED_NODES:-95.111.227.14,95.111.229.108,95.111.239.142,161.97.83.147,161.97.97.83,161.97.114.192,161.97.117.0,194.163.144.177,185.218.126.23,185.239.209.227}"
INSTALL_WRAPPERS="${INSTALL_WRAPPERS:-1}"
ENFORCE_NETWORK_PATCH_PIN="${ENFORCE_NETWORK_PATCH_PIN:-1}"
AUTO_ACCEPT_NETWORK_PATCH_HASH="${AUTO_ACCEPT_NETWORK_PATCH_HASH:-1}"
AUTO_RESET_CHAINSTATE="${AUTO_RESET_CHAINSTATE:-1}"

CONF_MANAGED_START="# rbitcoin-install-start"
CONF_MANAGED_END="# rbitcoin-install-end"

stop_existing_local_node() {
  local had_running=0
  local -a pids=()

  if [[ -x ./build/bitcoin-cli ]]; then
    if ./build/bitcoin-cli -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1; then
      had_running=1
      ./build/bitcoin-cli -datadir="$DATADIR" stop >/dev/null 2>&1 || true
    fi
  fi

  mapfile -t pids < <(pgrep -f -- "$ROOT_DIR/build/bitcoind" || true)
  if [[ "${#pids[@]}" -gt 0 ]]; then
    had_running=1
    kill -TERM "${pids[@]}" >/dev/null 2>&1 || true
  fi

  if [[ "$had_running" != "1" ]]; then
    return
  fi

  for _ in {1..60}; do
    if pgrep -f -- "$ROOT_DIR/build/bitcoind" >/dev/null 2>&1; then
      sleep 1
      continue
    fi
    return
  done

  echo "FAIL: existing rBTC node is still running from $ROOT_DIR/build/bitcoind" >&2
  echo "Stop it manually and rerun install." >&2
  exit 1
}

wait_for_rpc_ready() {
  for _ in {1..60}; do
    if ./build/bitcoin-cli -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done

  echo "FAIL: node did not become RPC-ready on datadir=$DATADIR" >&2
  exit 1
}

find_chain_data_dir() {
  local log_path

  log_path="$(find "$DATADIR" -maxdepth 4 -type f -name debug.log 2>/dev/null | head -n1 || true)"
  if [[ -n "$log_path" ]]; then
    dirname "$log_path"
    return
  fi

  echo "$DATADIR/rbitcoin"
}

stop_node_for_datadir() {
  local -a pids=()

  ./build/bitcoin-cli -datadir="$DATADIR" stop >/dev/null 2>&1 || true
  for _ in {1..20}; do
    if ./build/bitcoin-cli -datadir="$DATADIR" getblockchaininfo >/dev/null 2>&1; then
      sleep 1
      continue
    fi
    break
  done

  mapfile -t pids < <(pgrep -f -- "$ROOT_DIR/build/bitcoind" || true)
  if [[ "${#pids[@]}" -gt 0 ]]; then
    kill -TERM "${pids[@]}" >/dev/null 2>&1 || true
  fi
}

reset_chain_data() {
  local chain_dir

  chain_dir="$(find_chain_data_dir)"
  rm -rf \
    "$chain_dir/blocks" \
    "$chain_dir/chainstate" \
    "$chain_dir/indexes" \
    "$chain_dir/banlist.json" \
    "$chain_dir/mempool.dat" \
    "$chain_dir/peers.dat"
}

has_chainstate_corruption_warning() {
  local log_path

  log_path="$(find "$DATADIR" -maxdepth 4 -type f -name debug.log 2>/dev/null | head -n1 || true)"
  if [[ -z "$log_path" ]]; then
    return 1
  fi

  tail -n 400 "$log_path" | rg -q 'Chain state database corruption likely\.'
}

check_mainnet_seed_sync() {
  if [[ "$NETWORK" != "main" && "$NETWORK" != "mainnet" ]]; then
    return
  fi

  if [[ "$SEED_BOOTSTRAP" != "1" ]]; then
    return
  fi

  local peered_seconds=0
  local height=0
  local conns=0
  local peer_max=0
  local log_path=""

  log_path="$(find "$DATADIR" -maxdepth 4 -type f -name debug.log 2>/dev/null | head -n1 || true)"

  for _ in {1..180}; do
    height="$(./build/bitcoin-cli -datadir="$DATADIR" getblockcount 2>/dev/null || echo 0)"
    if [[ "$height" =~ ^[0-9]+$ ]] && (( height > 0 )); then
      return
    fi

    conns="$(./build/bitcoin-cli -datadir="$DATADIR" getconnectioncount 2>/dev/null || echo 0)"
    if [[ "$conns" =~ ^[0-9]+$ ]] && (( conns > 0 )); then
      peered_seconds=$((peered_seconds + 1))
      peer_max="$(./build/bitcoin-cli -datadir="$DATADIR" getpeerinfo 2>/dev/null | \
        python3 -c 'import json, sys
try:
    peers = json.load(sys.stdin)
except Exception:
    print(0)
    raise SystemExit(0)
max_height = 0
for peer in peers:
    for field in ("synced_headers", "startingheight", "presynced_headers", "synced_blocks"):
        value = peer.get(field)
        if isinstance(value, int) and value > max_height:
            max_height = value
print(max_height)')"

      if (( peered_seconds >= 45 )) && [[ -n "$log_path" ]]; then
        if tail -n 400 "$log_path" | rg -q 'bad-cb-height|AcceptBlock:|AcceptBlock FAILED'; then
          echo "FAIL: connected peers report non-zero height (${peer_max}), local height is still 0." >&2
          echo "Consensus rejection detected in $log_path (likely patch mismatch)." >&2
          exit 1
        fi
      fi
    else
      peered_seconds=0
    fi

    sleep 1
  done

  if (( peered_seconds >= 45 )); then
    echo "FAIL: node stayed at height 0 while connected to peers (peer max=${peer_max})." >&2
    echo "Check local debug log for consensus errors and patch alignment." >&2
    exit 1
  fi
}

if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

if [[ -z "$RPC_PASS" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    RPC_PASS=$(openssl rand -hex 16)
  else
    RPC_PASS="rbtc$(date +%s)"
  fi
fi

mapfile -t SEED_NODE_ARRAY < <(
  printf '%s\n' "$SEED_NODES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
)

mkdir -p "$DATADIR"
CONF="$DATADIR/bitcoin.conf"

if [[ ! -f "$CONF" ]]; then
  cat <<CONF > "$CONF"
server=1
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=$RPC_BIND
rpcallowip=$RPC_ALLOWIP
rpcport=19332
port=19333
listen=1
txindex=1
CONF
fi

tmp_conf="$(mktemp)"
awk -v start="$CONF_MANAGED_START" -v end="$CONF_MANAGED_END" '
  $0 == start { skip=1; next }
  $0 == end { skip=0; next }
  skip == 0 { print }
' "$CONF" > "$tmp_conf"
mv "$tmp_conf" "$CONF"

if [[ "$SEED_BOOTSTRAP" == "1" && "${#SEED_NODE_ARRAY[@]}" -gt 0 ]]; then
  {
    echo "$CONF_MANAGED_START"
    echo "dnsseed=0"
    for seed in "${SEED_NODE_ARRAY[@]}"; do
      echo "addnode=${seed}:${SEED_PORT}"
    done
    echo "$CONF_MANAGED_END"
  } >> "$CONF"
fi

if [[ "$ENFORCE_NETWORK_PATCH_PIN" == "1" ]]; then
  if ! pin_output="$(./scripts/enforce_network_patch_pin.sh 2>&1)"; then
    if [[ "$AUTO_ACCEPT_NETWORK_PATCH_HASH" != "1" ]]; then
      echo "$pin_output" >&2
      echo "FAIL: network patch pin mismatch and auto-accept disabled" >&2
      exit 1
    fi

    local_patch_hash="$(tr -d ' \n' < ./patch/immutable.patch.sha256)"
    if [[ -z "$local_patch_hash" ]]; then
      echo "FAIL: local patch hash file is empty" >&2
      exit 1
    fi

    printf '%s\n' "$local_patch_hash" > ./references/NETWORK_PATCH_HASH
    echo "WARN: network patch pin mismatch; auto-updated required network patch hash to $local_patch_hash"
    ./scripts/enforce_network_patch_pin.sh
  else
    echo "$pin_output"
  fi
fi

if [[ "$VERIFY" == "1" ]]; then
  ./scripts/verify_upstream_release.sh "$TAG"
  ./scripts/enforce_patch_scope.sh ./patch/immutable.patch
fi

if [[ "${MOCK_BUILD:-0}" != "1" ]]; then
  stop_existing_local_node
fi
./scripts/build_from_tag.sh "$TAG"
./scripts/make_update_manifest.sh "$TAG"
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest-$TAG.json

if [[ "$RUN_NODE" == "1" ]]; then
  ./scripts/run_node.sh --datadir "$DATADIR" --network "$NETWORK"
  wait_for_rpc_ready
  check_mainnet_seed_sync

  if has_chainstate_corruption_warning; then
    if [[ "$AUTO_RESET_CHAINSTATE" != "1" ]]; then
      echo "FAIL: chainstate corruption warning detected; rerun with clean chain data." >&2
      exit 1
    fi

    echo "WARN: detected chainstate corruption warning; resetting chain data and retrying sync."
    stop_node_for_datadir
    reset_chain_data
    ./scripts/run_node.sh --datadir "$DATADIR" --network "$NETWORK"
    wait_for_rpc_ready
    check_mainnet_seed_sync

    if has_chainstate_corruption_warning; then
      echo "FAIL: chainstate corruption warning persisted after reset." >&2
      exit 1
    fi
  fi

  echo "Node running. Config: $CONF"
fi

if [[ "$START_MINER" == "1" ]]; then
  ./scripts/start_cpu_miner.sh --datadir "$DATADIR" --network "$NETWORK"
fi

if [[ "$INSTALL_WRAPPERS" == "1" ]]; then
  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/rbtc-cli" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$ROOT_DIR/build/bitcoin-cli" -datadir="$DATADIR" "\$@"
EOF
  chmod +x "$HOME/.local/bin/rbtc-cli"

  cat > "$HOME/.local/bin/rbtc-bitcoind" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$ROOT_DIR/build/bitcoind" -datadir="$DATADIR" "\$@"
EOF
  chmod +x "$HOME/.local/bin/rbtc-bitcoind"
fi

echo
echo "Install complete for rBTC."
echo "Use: $ROOT_DIR/build/bitcoin-cli -datadir=\"$DATADIR\" getblockcount"
if [[ "$INSTALL_WRAPPERS" == "1" ]]; then
  echo "Wrapper: $HOME/.local/bin/rbtc-cli getblockcount"
fi
