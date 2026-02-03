#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  TAG=$(./scripts/fetch_upstream_release.sh)
fi

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/bitcoin/bitcoin.git}"
UPSTREAM_DIR="${UPSTREAM_DIR:-./.cache/upstream/bitcoin}"
PATCH_FILE="${PATCH_FILE:-./patch/immutable.patch}"
GENESIS_JSON="${GENESIS_JSON:-./references/GENESIS.json}"

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  mkdir -p "$(dirname "$UPSTREAM_DIR")"
  git clone "$UPSTREAM_REPO" "$UPSTREAM_DIR"
fi

# fetch tags
 git -C "$UPSTREAM_DIR" fetch --tags

WORKTREE=$(mktemp -d /tmp/rbtc-upstream-XXXX)

# add worktree at tag
 git -C "$UPSTREAM_DIR" worktree add "$WORKTREE" "$TAG" >/dev/null

# apply chainparams modifications
./scripts/apply_chainparams_patch.py "$WORKTREE" "$GENESIS_JSON"

# generate patch
 git -C "$WORKTREE" diff > "$PATCH_FILE"

# cleanup worktree (force remove if dirty)
 git -C "$UPSTREAM_DIR" worktree remove -f "$WORKTREE" >/dev/null || true
 rm -rf "$WORKTREE" || true

# update patch hash
./scripts/compute_patch_hash.sh "$PATCH_FILE" > ./patch/immutable.patch.sha256

echo "Generated patch for $TAG -> $PATCH_FILE"
