# rBitcoin

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official release tags. The only allowed delta is a scope-limited immutable patch for chain identity. Nodes auto-update to verified releases and refuse to run if provenance checks fail.

## One-Click Install (CPU Miners)

```bash
./install.sh v30.2
```

This will verify, build, run the node, and attempt to start CPU mining.

## CPU Usage Caps

By default, the miner uses **~50%** of CPU cores. You can override:

```bash
# Use 25% of CPU
MINER_CPU_PERCENT=25 ./install.sh v30.2

# Or specify exact threads
MINER_THREADS=2 ./install.sh v30.2
```

## Quickstart (Manual)

```bash
./scripts/fetch_upstream_release.sh
./scripts/verify_upstream_release.sh vX.Y
./scripts/build_from_tag.sh vX.Y
./scripts/make_update_manifest.sh vX.Y
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
./scripts/run_node.sh --datadir ./data --network main
./scripts/mine_solo.sh --address rBTC_ADDRESS --network regtest
```

## Docs
- `specs/` — requirements and acceptance criteria
- `references/` — trust model, verification guide, update protocol
- `skill/` — Agent Skill packaging
- `ralph/` — planning/build loop
