#!/usr/bin/env bash
set -euo pipefail

ROOT="${UPDATER_ROOT:-./runtime}"
VERSIONS_DIR="$ROOT/versions"
CURRENT_LINK="$ROOT/current"

VERIFY_CMD="${VERIFY_CMD:-./scripts/verify_upstream_release.sh}"

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

mkdir -p "$VERSIONS_DIR"

TARGET_DIR="$VERSIONS_DIR/$TAG"
PREV_TARGET=""

if [[ -L "$CURRENT_LINK" ]]; then
  PREV_TARGET=$(readlink "$CURRENT_LINK")
fi

# Build + verify
BUILD_DIR="$TARGET_DIR/build"
REPORTS_DIR="$TARGET_DIR/reports"
MANIFESTS_DIR="$TARGET_DIR/manifests"

mkdir -p "$BUILD_DIR" "$REPORTS_DIR" "$MANIFESTS_DIR"

# Verify upstream release
export REPORTS_DIR
$VERIFY_CMD "$TAG"

# Build from tag
BUILD_DIR="$BUILD_DIR" ./scripts/build_from_tag.sh "$TAG"

# Generate manifest
BUILD_DIR="$BUILD_DIR" REPORTS_DIR="$REPORTS_DIR" MANIFESTS_DIR="$MANIFESTS_DIR" ./scripts/make_update_manifest.sh "$TAG" >/dev/null

# Verify local binary
PATCH_HASH_FILE="./patch/immutable.patch.sha256" \
  ./scripts/verify_local_binary.sh "$BUILD_DIR/bitcoind" "$MANIFESTS_DIR/manifest-$TAG.json" >/dev/null

# Atomic swap
ln -sfn "$TARGET_DIR" "$CURRENT_LINK"

# Smoke test
SMOKE_TEST_CMD="${SMOKE_TEST_CMD:-$BUILD_DIR/bitcoind --version}"
if ! bash -c "$SMOKE_TEST_CMD" >/dev/null 2>&1; then
  echo "FAIL: smoke test failed, rolling back" >&2
  if [[ -n "$PREV_TARGET" ]]; then
    ln -sfn "$PREV_TARGET" "$CURRENT_LINK"
    exit 1
  fi
fi

echo "PASS: update complete ($TAG)"
