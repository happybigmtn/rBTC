#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

BUILD_DIR="$TMPDIR/build"
REPORTS_DIR="$TMPDIR/reports"
MANIFESTS_DIR="$TMPDIR/manifests"

mkdir -p "$BUILD_DIR" "$REPORTS_DIR" "$MANIFESTS_DIR"

echo "binary" > "$BUILD_DIR/bitcoind"
echo "binary" > "$BUILD_DIR/bitcoin-cli"

cat <<JSON > "$REPORTS_DIR/verification-v0.0.0-test.json"
{ "tag": "v0.0.0-test", "status": "PASS" }
JSON

PATCH_HASH_FILE="$TMPDIR/immutable.patch.sha256"
echo "deadbeef" > "$PATCH_HASH_FILE"

BUILD_DIR="$BUILD_DIR" REPORTS_DIR="$REPORTS_DIR" MANIFESTS_DIR="$MANIFESTS_DIR" PATCH_HASH_FILE="$PATCH_HASH_FILE" \
  ./scripts/make_update_manifest.sh v0.0.0-test >/dev/null

MANIFEST_FILE="$MANIFESTS_DIR/manifest-v0.0.0-test.json"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "FAIL: manifest not created"
  exit 1
fi

SCHEMA_FILE="/Users/gk/coding/rBTC/schemas/manifest.schema.json" \
  ./scripts/validate_manifest.sh "$MANIFEST_FILE" >/dev/null

echo "PASS: manifest generation + validation"
