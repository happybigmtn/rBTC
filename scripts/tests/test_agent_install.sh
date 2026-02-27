#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
BACKUP_DIR=$(mktemp -d)

restore_binary() {
  local src="$1"
  local dst="$2"
  local tmp

  if [[ -f "$src" ]]; then
    tmp="$(mktemp "${dst}.tmp.XXXXXX")"
    cp -f "$src" "$tmp"
    chmod +x "$tmp" || true
    mv -f "$tmp" "$dst"
  else
    rm -f "$dst"
  fi
}

restore_build_binaries() {
  mkdir -p ./build

  restore_binary "$BACKUP_DIR/bitcoind" ./build/bitcoind
  restore_binary "$BACKUP_DIR/bitcoin-cli" ./build/bitcoin-cli
}

if [[ -f ./build/bitcoind ]]; then
  cp -f ./build/bitcoind "$BACKUP_DIR/bitcoind"
fi
if [[ -f ./build/bitcoin-cli ]]; then
  cp -f ./build/bitcoin-cli "$BACKUP_DIR/bitcoin-cli"
fi

trap 'restore_build_binaries; rm -rf "$TMPDIR" "$BACKUP_DIR"' EXIT

export MOCK_BUILD=1
export VERIFY=0
export RUN_NODE=0
export DATADIR="$TMPDIR/rbitcoin"
export INSTALL_WRAPPERS=0
export NETWORK_PATCH_HASH="$(tr -d ' \n' < ./patch/immutable.patch.sha256)"

./scripts/agent_install.sh v0.0.0-test >/tmp/rbtc_agent_install.txt

if [[ ! -f "$DATADIR/bitcoin.conf" ]]; then
  echo "FAIL: bitcoin.conf not created"
  exit 1
fi

if ! rg -q '^dnsseed=0$' "$DATADIR/bitcoin.conf"; then
  echo "FAIL: dnsseed bootstrap config missing"
  exit 1
fi

if ! rg -q '^addnode=95\.111\.227\.14:19333$' "$DATADIR/bitcoin.conf"; then
  echo "FAIL: expected seed node missing from config"
  exit 1
fi

echo "PASS: agent_install.sh"
