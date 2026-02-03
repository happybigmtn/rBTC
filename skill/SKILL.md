# rBitcoin Skill

## Purpose
Set up, verify, and mine the rBitcoin chain (rebased from Bitcoin Core) with minimal friction and verifiable upstream pinning.

## Quickstart (Linux)

```bash
# 1) Discover latest upstream release tag
./scripts/fetch_upstream_release.sh

# 2) Verify upstream release authenticity
./scripts/verify_upstream_release.sh vX.Y.Z

# 3) Build from upstream tag + immutable patch
./scripts/build_from_tag.sh vX.Y.Z

# 4) Generate update manifest
./scripts/make_update_manifest.sh vX.Y.Z

# 5) Verify local binary provenance
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json

# 6) Run node (refuse-to-run gate)
./scripts/run_node.sh --datadir ./data

# 7) Mine a block on dev chain
./scripts/mine_solo.sh --address rBTC_ADDRESS
```

## Verify

```bash
./scripts/verify_upstream_release.sh vX.Y.Z
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
```

## Build

```bash
./scripts/build_from_tag.sh vX.Y.Z
```

## Run

```bash
./scripts/run_node.sh --datadir ./data
```

## Mine

```bash
./scripts/mine_solo.sh --address rBTC_ADDRESS
```

## Update

```bash
./scripts/updater.sh --datadir ./data
```
