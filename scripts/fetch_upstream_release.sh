#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-bitcoin/bitcoin}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"

# Test override
if [[ -n "${MOCK_LATEST_TAG:-}" ]]; then
  echo "$MOCK_LATEST_TAG"
  exit 0
fi

url="$GITHUB_API/repos/$UPSTREAM_REPO/releases/latest"

if ! command -v curl >/dev/null 2>&1; then
  echo "FAIL: curl is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required" >&2
  exit 1
fi

response=$(curl -fsSL "$url") || { echo "FAIL: unable to fetch release info" >&2; exit 1; }

tag=$(echo "$response" | jq -r '.tag_name')

if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "FAIL: tag_name not found" >&2
  exit 1
fi

# Basic sanity: must look like vX.Y.Z
if ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "FAIL: unexpected tag format: $tag" >&2
  exit 1
fi

echo "$tag"
