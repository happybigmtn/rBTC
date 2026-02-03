#!/usr/bin/env bash
set -euo pipefail

SCRIPT="./scripts/enforce_patch_scope.sh"
ALLOWLIST="./patch/allowlist.txt"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT not executable"
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Allowed patch
cat <<'PATCH' > "$TMPDIR/allowed.patch"
--- a/src/chainparams.cpp
+++ b/src/chainparams.cpp
@@ -1,1 +1,1 @@
-foo
+bar
PATCH

ALLOWLIST_FILE="$ALLOWLIST" "$SCRIPT" "$TMPDIR/allowed.patch"

# Disallowed patch
cat <<'PATCH' > "$TMPDIR/disallowed.patch"
--- a/src/wallet/wallet.cpp
+++ b/src/wallet/wallet.cpp
@@ -1,1 +1,1 @@
-foo
+bar
PATCH

if ALLOWLIST_FILE="$ALLOWLIST" "$SCRIPT" "$TMPDIR/disallowed.patch"; then
  echo "FAIL: disallowed patch should have been rejected"
  exit 1
fi

echo "PASS: patch scope allowlist enforced"
