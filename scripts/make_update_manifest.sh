#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>" >&2
  exit 1
fi

BUILD_DIR="${BUILD_DIR:-./build}"
PATCH_HASH_FILE="${PATCH_HASH_FILE:-./patch/immutable.patch.sha256}"
REPORTS_DIR="${REPORTS_DIR:-./reports}"
MANIFESTS_DIR="${MANIFESTS_DIR:-./manifests}"
REPORT_FILE="$REPORTS_DIR/verification-$TAG.json"

mkdir -p "$MANIFESTS_DIR"

if [[ ! -f "$PATCH_HASH_FILE" ]]; then
  echo "FAIL: missing patch hash file" >&2
  exit 1
fi

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "FAIL: missing verification report $REPORT_FILE" >&2
  exit 1
fi

patch_hash=$(cat "$PATCH_HASH_FILE" | tr -d ' \n')

artifacts=()
for bin in "$BUILD_DIR/bitcoind" "$BUILD_DIR/bitcoin-cli"; do
  if [[ -f "$bin" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      hash=$(sha256sum "$bin" | awk '{print $1}')
    else
      hash=$(shasum -a 256 "$bin" | awk '{print $1}')
    fi
    artifacts+=("$bin::$hash")
  fi
done

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "FAIL: no artifacts found in $BUILD_DIR" >&2
  exit 1
fi

manifest="$MANIFESTS_DIR/manifest-$TAG.json"

{
  echo '{'
  echo "  \"upstream_tag\": \"$TAG\","
  echo "  \"patch_hash\": \"$patch_hash\","
  echo "  \"verification_report\": \"$REPORT_FILE\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"artifacts\": ["
  first=1
  for entry in "${artifacts[@]}"; do
    path="${entry%%::*}"
    hash="${entry##*::}"
    if [[ $first -eq 0 ]]; then
      echo ","
    fi
    first=0
    echo "    { \"path\": \"$path\", \"sha256\": \"$hash\" }"
  done
  echo "  ]"
  echo '}'
} > "$manifest"

# also write latest manifest pointer
cp -f "$manifest" "$MANIFESTS_DIR/manifest.json"

echo "$manifest"
