#!/usr/bin/env bash
set -euo pipefail

required=(
  "./references/TRUST_MODEL.md"
  "./references/VERIFICATION_GUIDE.md"
)

for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "FAIL: missing reference file: $f"
    exit 1
  fi
done

echo "PASS: required references exist"
