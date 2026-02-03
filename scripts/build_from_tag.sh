#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>" >&2
  exit 1
fi

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/bitcoin/bitcoin.git}"
WORKDIR="${WORKDIR:-./.cache/build}"
PATCH_FILE="${PATCH_FILE:-./patch/immutable.patch}"
PATCH_HASH_FILE="${PATCH_HASH_FILE:-./patch/immutable.patch.sha256}"
BUILD_DIR="${BUILD_DIR:-./build}"
LOG_FILE="${LOG_FILE:-$BUILD_DIR/build.log}"
UPSTREAM_CLONE_DEPTH="${UPSTREAM_CLONE_DEPTH:-1}"

MOCK_BUILD="${MOCK_BUILD:-0}"

mkdir -p "$WORKDIR" "$BUILD_DIR"

# Ensure patch hash matches pinned file
if [[ -f "$PATCH_HASH_FILE" ]]; then
  expected=$(cat "$PATCH_HASH_FILE" | tr -d ' \n')
  if [[ -z "$expected" ]]; then
    echo "FAIL: empty patch hash file" >&2
    exit 1
  fi
  actual=$(./scripts/compute_patch_hash.sh "$PATCH_FILE" | tr -d ' \n')
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: patch hash mismatch" >&2
    exit 1
  fi
fi

if [[ "$MOCK_BUILD" == "1" ]]; then
  echo "MOCK BUILD for $TAG" > "$LOG_FILE"
  echo "patch_hash=$(cat "$PATCH_HASH_FILE" 2>/dev/null || echo none)" >> "$LOG_FILE"
  echo "binary" > "$BUILD_DIR/bitcoind"
  echo "binary" > "$BUILD_DIR/bitcoin-cli"
  chmod +x "$BUILD_DIR/bitcoind" "$BUILD_DIR/bitcoin-cli"
  echo "PASS: mock build complete"
  exit 0
fi

# Clone or update upstream (shallow clone by default)
UPSTREAM_DIR="$WORKDIR/bitcoin"
if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  git clone --depth "$UPSTREAM_CLONE_DEPTH" --branch "$TAG" "$UPSTREAM_REPO" "$UPSTREAM_DIR"
else
  git -C "$UPSTREAM_DIR" fetch --depth "$UPSTREAM_CLONE_DEPTH" origin "$TAG"
fi

pushd "$UPSTREAM_DIR" >/dev/null

git checkout "$TAG"

# Apply patch if non-empty
if [[ -s "$PATCH_FILE" ]]; then
  git apply "$PATCH_FILE"
fi

# Build (best effort)
./autogen.sh
./configure
make -j"${BUILD_JOBS:-2}"

# Copy binaries
cp -f src/bitcoind "$BUILD_DIR/bitcoind"
cp -f src/bitcoin-cli "$BUILD_DIR/bitcoin-cli"

popd >/dev/null

{
  echo "tag=$TAG"
  echo "patch_hash=$(cat "$PATCH_HASH_FILE" 2>/dev/null || echo none)"
  date -u
} > "$LOG_FILE"

echo "PASS: build complete"
