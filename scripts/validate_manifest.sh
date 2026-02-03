#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="${1:-./manifests/manifest.json}"
SCHEMA_FILE="${SCHEMA_FILE:-./schemas/manifest.schema.json}"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "FAIL: manifest not found: $MANIFEST_FILE" >&2
  exit 1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "FAIL: schema not found: $SCHEMA_FILE" >&2
  exit 1
fi

python3 - "$MANIFEST_FILE" "$SCHEMA_FILE" <<'PY'
import json, sys
manifest_file = sys.argv[1]
schema_file = sys.argv[2]

with open(schema_file, 'r') as f:
    schema = json.load(f)
with open(manifest_file, 'r') as f:
    data = json.load(f)

required = schema.get('required', [])
for key in required:
    if key not in data:
        print(f"FAIL: missing required key: {key}")
        sys.exit(1)

if not isinstance(data.get('artifacts'), list) or len(data['artifacts']) == 0:
    print("FAIL: artifacts must be a non-empty array")
    sys.exit(1)

for item in data['artifacts']:
    if 'path' not in item or 'sha256' not in item:
        print("FAIL: artifact missing path or sha256")
        sys.exit(1)

print("PASS: manifest validation ok")
PY
