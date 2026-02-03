#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE="./patch/immutable.patch"
HASH_FILE="./patch/immutable.patch.sha256"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "FAIL: missing patch file"
  exit 1
fi

if [[ ! -f "$HASH_FILE" ]]; then
  echo "FAIL: missing hash file"
  exit 1
fi

expected=$(cat "$HASH_FILE" | tr -d ' \n')
actual=$(./scripts/compute_patch_hash.sh "$PATCH_FILE" | tr -d ' \n')

if [[ -z "$expected" ]]; then
  echo "FAIL: hash file is empty"
  exit 1
fi

if [[ "$expected" != "$actual" ]]; then
  echo "FAIL: patch hash mismatch"
  echo "expected: $expected"
  echo "actual:   $actual"
  exit 1
fi

# Negative check with a temp patch
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cat <<'PATCH' > "$TMPDIR/other.patch"
--- a/src/chainparams.cpp
+++ b/src/chainparams.cpp
@@ -1,1 +1,1 @@
-foo
+bar
PATCH

tmp_hash=$(./scripts/compute_patch_hash.sh "$TMPDIR/other.patch")
if [[ "$tmp_hash" == "$expected" ]]; then
  echo "FAIL: temp patch hash unexpectedly matches pinned hash"
  exit 1
fi

echo "PASS: patch hash pinning verified"
