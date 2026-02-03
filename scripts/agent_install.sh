#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
DATADIR="${DATADIR:-$HOME/.rbitcoin}"
NETWORK="${NETWORK:-main}"
VERIFY="${VERIFY:-1}"
START_MINER="${START_MINER:-0}"
RUN_NODE="${RUN_NODE:-1}"
RPC_USER="${RPC_USER:-rbtc}"
RPC_PASS="${RPC_PASS:-}"

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

mkdir -p "$DATADIR"
CONF="$DATADIR/bitcoin.conf"

if [[ ! -f "$CONF" ]]; then
  cat <<CONF > "$CONF"
server=1
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
rpcport=19332
port=19333
listen=1
txindex=1
CONF
fi

if [[ "$VERIFY" == "1" ]]; then
  ./scripts/verify_upstream_release.sh "$TAG"
  ./scripts/enforce_patch_scope.sh ./patch/immutable.patch
fi

./scripts/build_from_tag.sh "$TAG"
./scripts/make_update_manifest.sh "$TAG"
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest-$TAG.json

if [[ "$RUN_NODE" == "1" ]]; then
  ./scripts/run_node.sh --datadir "$DATADIR" --network "$NETWORK"
  echo "Node running. Config: $CONF"
fi

if [[ "$START_MINER" == "1" ]]; then
  ./scripts/start_cpu_miner.sh --datadir "$DATADIR" --network "$NETWORK"
fi
