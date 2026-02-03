# AGENTS.md - rBitcoin Build Guide

## Overview

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official Bitcoin Core release tags.
The only allowed delta is a **scope-limited immutable patch** for chain identity. All upgrades are verified before use.

## Prerequisites

```bash
# Core tooling
brew install git gpg jq xz

# Optional (for reproducible builds / attestations)
# Install guix if you plan to verify Guix attestations
```

## Build & Run

```bash
# Discover latest upstream release tag
./scripts/fetch_upstream_release.sh

# Verify upstream release authenticity
./scripts/verify_upstream_release.sh vX.Y.Z

# Build from upstream tag + immutable patch
./scripts/build_from_tag.sh vX.Y.Z

# Generate update manifest
./scripts/make_update_manifest.sh vX.Y.Z

# Verify local binary provenance
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json

# Run node (refuse-to-run checks happen before launch)
./scripts/run_node.sh --datadir ./data
```

## Mining Quickstart

```bash
# Mine a block on the dev chain
./scripts/mine_solo.sh --address rBTC_ADDRESS
```

## Validation Commands

Run these after implementing changes:

```bash
# Patch scope enforcement
./scripts/enforce_patch_scope.sh ./patch/immutable.patch

# Patch hash pinning
./scripts/compute_patch_hash.sh ./patch/immutable.patch

# Local binary verifier (fail closed)
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
```

## Project Structure

```
rBitcoin/
├── ralph/                  # Ralph loop + prompts
├── specs/                  # Requirements with acceptance criteria
├── scripts/                # Build/verify/update/mine tools
├── patch/                  # Immutable patch + hash
├── manifests/              # Update manifests
├── schemas/                # JSON schemas
├── references/             # Trust model, verification guides
├── skill/                  # Agent skill bundle
└── .github/workflows/       # CI
```
