#!/usr/bin/env bash
set -euo pipefail

required=(
  "./skill/SKILL.md"
  "./skill/clawhub.json"
  "./scripts/agent_install.sh"
  "./scripts/agent_verify.sh"
  "./scripts/ensure_cpu_miner.sh"
  "./scripts/enforce_patch_scope.sh"
  "./scripts/verify_upstream_release.sh"
  "./scripts/build_from_tag.sh"
  "./scripts/make_update_manifest.sh"
  "./scripts/verify_local_binary.sh"
  "./scripts/updater.sh"
  "./scripts/mine_solo.sh"
  "./references/TRUST_MODEL.md"
  "./references/VERIFICATION_GUIDE.md"
)

for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "FAIL: missing required skill file: $f"
    exit 1
  fi
done

echo "PASS: skill bundle contains required files"
