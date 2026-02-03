#!/usr/bin/env bash
set -euo pipefail

BINARY_PATH="${1:-}"
MANIFEST_FILE="${2:-./manifests/manifest.json}"
PATCH_HASH_FILE="${PATCH_HASH_FILE:-./patch/immutable.patch.sha256}"

if [[ -z "$BINARY_PATH" ]]; then
  echo "Usage: $0 <binary> [manifest]" >&2
  exit 1
fi

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "FAIL: binary not found: $BINARY_PATH" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "FAIL: manifest not found: $MANIFEST_FILE" >&2
  exit 1
fi

if [[ ! -f "$PATCH_HASH_FILE" ]]; then
  echo "FAIL: patch hash file not found" >&2
  exit 1
fi

expected_patch=$(cat "$PATCH_HASH_FILE" | tr -d ' \n')

python3 - "$BINARY_PATH" "$MANIFEST_FILE" "$expected_patch" <<'PY'
import json, sys, hashlib
binary_path = sys.argv[1]
manifest_file = sys.argv[2]
expected_patch = sys.argv[3]

with open(manifest_file, 'r') as f:
    manifest = json.load(f)

if manifest.get('patch_hash') != expected_patch:
    print('FAIL: patch hash mismatch in manifest')
    sys.exit(1)

# compute binary hash
h = hashlib.sha256()
with open(binary_path, 'rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        h.update(chunk)
actual = h.hexdigest()

# find matching artifact
artifacts = manifest.get('artifacts', [])
match = None
for item in artifacts:
    if item.get('path') == binary_path or item.get('path', '').endswith('/' + binary_path.split('/')[-1]):
        match = item
        break

if not match:
    print('FAIL: binary not listed in manifest artifacts')
    sys.exit(1)

if match.get('sha256') != actual:
    print('FAIL: binary hash mismatch')
    sys.exit(1)

print('PASS: local binary verified')
PY
