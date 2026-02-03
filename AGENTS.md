# AGENTS.md - rBitcoin Build Guide

## Overview

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official release tags.
The only allowed delta is a **scope-limited immutable patch** for chain identity. All upgrades are verified before use.

## Prerequisites (macOS)

```bash
brew install git gpg jq automake libtool pkg-config boost berkeley-db@4 openssl@3
```

## Build & Run

```bash
# Discover latest upstream release tag
./scripts/fetch_upstream_release.sh

# Verify upstream release authenticity
./scripts/verify_upstream_release.sh vX.Y

# Build from upstream tag + immutable patch
./scripts/build_from_tag.sh vX.Y

# Generate update manifest
./scripts/make_update_manifest.sh vX.Y

# Verify local binary provenance
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json

# Run node (refuse-to-run checks happen before launch)
./scripts/run_node.sh --datadir ./data --network main
```

## Mining Quickstart (Dev)

```bash
# Mine a block on the dev chain
./scripts/mine_solo.sh --address rBTC_ADDRESS --network regtest
```

## Validation Commands

Run these after implementing changes:

```bash
./scripts/tests/test_skill_skeleton.sh
./scripts/tests/test_references_exist.sh
./scripts/tests/test_patch_scope_allowlist.sh
./scripts/tests/test_patch_hash_pinning.sh
./scripts/tests/test_fetch_upstream_release.sh
./scripts/tests/test_verify_upstream_release.sh
./scripts/tests/test_build_from_tag.sh
./scripts/tests/test_manifest_generation.sh
./scripts/tests/test_verify_local_binary.sh
./scripts/tests/test_updater_atomic_swap.sh
./scripts/tests/test_mine_solo.sh
./scripts/tests/test_skill_bundle.sh
```

## Project Structure

```
rBTC/
├── ralph/                   # Ralph loop + prompts
├── specs/                   # Requirement specs
├── scripts/                 # Build/verify/update/mine tools
├── patch/                   # Immutable patch + hash
├── manifests/               # Update manifests
├── schemas/                 # JSON schemas
├── references/              # Trust + verification docs
├── skill/                   # Agent skill bundle
└── .github/workflows/        # CI
```
