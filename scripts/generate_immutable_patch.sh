#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/bitcoin/bitcoin.git}"
PATCH_FILE="${PATCH_FILE:-./patch/immutable.patch}"
GENESIS_JSON="${GENESIS_JSON:-./references/GENESIS.json}"
UPSTREAM_CLONE_DEPTH="${UPSTREAM_CLONE_DEPTH:-1}"

WORKTREE=$(mktemp -d /tmp/rbtc-upstream-XXXX)

# shallow clone at tag
 git clone --depth "$UPSTREAM_CLONE_DEPTH" --branch "$TAG" "$UPSTREAM_REPO" "$WORKTREE" >/dev/null

# apply chainparams modifications
./scripts/apply_chainparams_patch.py "$WORKTREE" "$GENESIS_JSON"

# generate patch
 git -C "$WORKTREE" diff > "$PATCH_FILE"

# cleanup
 rm -rf "$WORKTREE" || true

# update patch hash
./scripts/compute_patch_hash.sh "$PATCH_FILE" > ./patch/immutable.patch.sha256

echo "Generated patch for $TAG -> $PATCH_FILE"
