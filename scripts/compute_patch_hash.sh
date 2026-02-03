#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE="${1:-./patch/immutable.patch}"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "FAIL: patch file not found: $PATCH_FILE"
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$PATCH_FILE" | awk '{print $1}'
else
  shasum -a 256 "$PATCH_FILE" | awk '{print $1}'
fi
