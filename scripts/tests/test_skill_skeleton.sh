#!/usr/bin/env bash
set -euo pipefail

SKILL_FILE="./skill/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "FAIL: $SKILL_FILE not found"
  exit 1
fi

required_sections=("Quickstart" "Verify" "Build" "Run" "Mine" "Update")
for section in "${required_sections[@]}"; do
  if ! grep -q "^## $section" "$SKILL_FILE"; then
    echo "FAIL: missing section: $section"
    exit 1
  fi
done

echo "PASS: skill skeleton contains required sections"
