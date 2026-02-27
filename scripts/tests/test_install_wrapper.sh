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

# Avoid miner dependency in tests
export START_MINER=0

./install.sh v0.0.0-test >/tmp/rbtc_install_wrapper.txt

if [[ ! -f "$DATADIR/bitcoin.conf" ]]; then
  echo "FAIL: bitcoin.conf not created by install.sh"
  exit 1
fi

echo "PASS: install.sh wrapper"
