#!/usr/bin/env bash
set -euo pipefail

# One-click wrapper for agent onboarding
TAG="${1:-}"
START_MINER="${START_MINER:-1}"

if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

# Try to ensure CPU miner is available; if not, continue without mining
if [[ "$START_MINER" == "1" ]]; then
  if ! ./scripts/ensure_cpu_miner.sh; then
    echo "WARN: CPU miner not available; continuing without mining" >&2
    START_MINER=0
  fi
fi

START_MINER="$START_MINER" ./scripts/agent_install.sh "$TAG"
