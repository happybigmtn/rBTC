#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

BIN="$TMPDIR/bitcoind"
echo "binary" > "$BIN"

if command -v sha256sum >/dev/null 2>&1; then
  HASH=$(sha256sum "$BIN" | awk '{print $1}')
else
  HASH=$(shasum -a 256 "$BIN" | awk '{print $1}')
fi

PATCH_HASH_FILE="$TMPDIR/immutable.patch.sha256"
echo "deadbeef" > "$PATCH_HASH_FILE"

MANIFEST="$TMPDIR/manifest.json"
cat <<JSON > "$MANIFEST"
{
  "upstream_tag": "v0.0.0-test",
  "patch_hash": "deadbeef",
  "verification_report": "reports/verification-v0.0.0-test.json",
  "timestamp": "2026-01-01T00:00:00Z",
  "artifacts": [
    { "path": "$BIN", "sha256": "$HASH" }
  ]
}
JSON

PATCH_HASH_FILE="$PATCH_HASH_FILE" ./scripts/verify_local_binary.sh "$BIN" "$MANIFEST" >/dev/null

# Tamper

echo "tamper" >> "$BIN"
if PATCH_HASH_FILE="$PATCH_HASH_FILE" ./scripts/verify_local_binary.sh "$BIN" "$MANIFEST" >/dev/null 2>&1; then
  echo "FAIL: verification should fail on tampered binary"
  exit 1
fi

echo "PASS: verify_local_binary.sh"
