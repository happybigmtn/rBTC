#!/usr/bin/env bash
set -euo pipefail

# One-click wrapper for agent onboarding
TAG="${1:-}"
START_MINER="${START_MINER:-1}"

if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

START_MINER="$START_MINER" ./scripts/agent_install.sh "$TAG"
