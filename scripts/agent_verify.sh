#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

REPORT="${REPORT:-./reports/agent-verify-$TAG.json}"
VERIFY_CMD="${VERIFY_CMD:-./scripts/verify_upstream_release.sh}"
SKIP_BINARY_VERIFY="${SKIP_BINARY_VERIFY:-0}"

mkdir -p ./reports

status="PASS"

if ! ./scripts/enforce_patch_scope.sh ./patch/immutable.patch >/dev/null; then
  status="FAIL"
fi

if ! $VERIFY_CMD "$TAG" >/dev/null; then
  status="FAIL"
fi

if [[ -f "./manifests/manifest-$TAG.json" ]]; then
  if ! ./scripts/validate_manifest.sh "./manifests/manifest-$TAG.json" >/dev/null; then
    status="FAIL"
  fi
fi

if [[ "$SKIP_BINARY_VERIFY" != "1" ]]; then
  if [[ -x ./build/bitcoind && -f "./manifests/manifest-$TAG.json" ]]; then
    if ! ./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest-$TAG.json >/dev/null; then
      status="FAIL"
    fi
  fi
fi

cat <<JSON > "$REPORT"
{
  "tag": "$TAG",
  "patch_hash": "$(cat ./patch/immutable.patch.sha256 | tr -d ' \n')",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reports": {
    "upstream": "./reports/verification-$TAG.json",
    "manifest": "./manifests/manifest-$TAG.json"
  }
}
JSON

echo "$status: $REPORT"
if [[ "$status" != "PASS" ]]; then
  exit 1
fi
