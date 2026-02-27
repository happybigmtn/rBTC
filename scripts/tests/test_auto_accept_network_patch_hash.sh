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

trap 'restore_build_binaries; rm -rf "$TMPDIR" "$BACKUP_DIR"; printf "%s\n" "$ORIG_HASH" > ./references/NETWORK_PATCH_HASH' EXIT

ORIG_HASH="$(tr -d ' \n' < ./references/NETWORK_PATCH_HASH)"
LOCAL_HASH="$(tr -d ' \n' < ./patch/immutable.patch.sha256)"

printf '%s\n' "0000000000000000000000000000000000000000000000000000000000000000" \
  > ./references/NETWORK_PATCH_HASH

export MOCK_BUILD=1
export VERIFY=0
export RUN_NODE=0
export START_MINER=0
export INSTALL_WRAPPERS=0
export DATADIR="$TMPDIR/rbitcoin"
export ENFORCE_NETWORK_PATCH_PIN=1
export AUTO_ACCEPT_NETWORK_PATCH_HASH=1

./install.sh v0.0.0-test >/tmp/rbtc_auto_accept_install.txt

UPDATED_HASH="$(tr -d ' \n' < ./references/NETWORK_PATCH_HASH)"
if [[ "$UPDATED_HASH" != "$LOCAL_HASH" ]]; then
  echo "FAIL: required network hash was not auto-updated"
  echo "expected: $LOCAL_HASH"
  echo "actual:   $UPDATED_HASH"
  exit 1
fi

if ! rg -q '^WARN: network patch pin mismatch; auto-updated required network patch hash to ' /tmp/rbtc_auto_accept_install.txt; then
  echo "FAIL: expected auto-update warning output"
  exit 1
fi

echo "PASS: auto-accept network patch hash"
