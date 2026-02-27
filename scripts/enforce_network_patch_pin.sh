#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="${PATCH_FILE:-$ROOT_DIR/patch/immutable.patch}"
PATCH_HASH_FILE="${PATCH_HASH_FILE:-$ROOT_DIR/patch/immutable.patch.sha256}"
NETWORK_PATCH_HASH_FILE="${NETWORK_PATCH_HASH_FILE:-$ROOT_DIR/references/NETWORK_PATCH_HASH}"
NETWORK_PATCH_HASH="${NETWORK_PATCH_HASH:-}"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "FAIL: patch file not found: $PATCH_FILE" >&2
  exit 1
fi

if [[ ! -f "$PATCH_HASH_FILE" ]]; then
  echo "FAIL: patch hash file not found: $PATCH_HASH_FILE" >&2
  exit 1
fi

if [[ -z "$NETWORK_PATCH_HASH" ]]; then
  if [[ ! -f "$NETWORK_PATCH_HASH_FILE" ]]; then
    echo "FAIL: network patch hash file not found: $NETWORK_PATCH_HASH_FILE" >&2
    exit 1
  fi
  NETWORK_PATCH_HASH="$(tr -d ' \n' < "$NETWORK_PATCH_HASH_FILE")"
fi

if [[ -z "$NETWORK_PATCH_HASH" ]]; then
  echo "FAIL: required network patch hash is empty" >&2
  exit 1
fi

if [[ ! "$NETWORK_PATCH_HASH" =~ ^[0-9a-f]{64}$ ]]; then
  echo "FAIL: required network patch hash is not a 64-char lowercase hex string" >&2
  exit 1
fi

local_pinned="$(tr -d ' \n' < "$PATCH_HASH_FILE")"
local_actual="$(./scripts/compute_patch_hash.sh "$PATCH_FILE" | tr -d ' \n')"

if [[ -z "$local_pinned" ]]; then
  echo "FAIL: local patch hash file is empty" >&2
  exit 1
fi

if [[ "$local_pinned" != "$local_actual" ]]; then
  echo "FAIL: local patch hash file does not match patch contents" >&2
  echo "pinned: $local_pinned" >&2
  echo "actual: $local_actual" >&2
  exit 1
fi

if [[ "$local_pinned" != "$NETWORK_PATCH_HASH" ]]; then
  echo "FAIL: local patch hash does not match required network hash" >&2
  echo "required: $NETWORK_PATCH_HASH" >&2
  echo "local:    $local_pinned" >&2
  exit 1
fi

echo "PASS: network patch pin verified ($NETWORK_PATCH_HASH)"
