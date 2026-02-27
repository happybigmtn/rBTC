#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE="${1:-./patch/immutable.patch}"
ALLOWLIST_FILE="${ALLOWLIST_FILE:-./patch/allowlist.txt}"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "FAIL: patch file not found: $PATCH_FILE"
  exit 1
fi

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: allowlist file not found: $ALLOWLIST_FILE"
  exit 1
fi

allowlist=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue
  line="${line#/}"
  allowlist+=("$line")
done < "$ALLOWLIST_FILE"

# Extract file paths from patch headers
patched_files=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  line=$(echo "$line" | sed -E 's@^(\+\+\+|---) [^/]+/@@')
  [[ "$line" == "/dev/null" ]] && continue
  patched_files+=("$line")
done < <(grep -E '^(\+\+\+|---) ' "$PATCH_FILE" | sort -u)

# Allow empty patch for bootstrap
if [[ ${#patched_files[@]} -eq 0 ]]; then
  echo "PASS: no file changes detected in patch"
  exit 0
fi

fail=0
for f in "${patched_files[@]}"; do
  allowed=0
  for a in "${allowlist[@]}"; do
    if [[ "$f" == "$a" ]]; then
      allowed=1
      break
    fi
  done
  if [[ "$allowed" -ne 1 ]]; then
    echo "FAIL: disallowed path in patch: $f"
    fail=1
  fi
done

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "PASS: patch scope within allowlist"
