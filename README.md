# rBitcoin

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official release tags. The only allowed delta is a scope-limited immutable patch for chain identity. Nodes auto-update to verified releases and refuse to run if provenance checks fail.

## Quickstart

```bash
./scripts/fetch_upstream_release.sh
./scripts/verify_upstream_release.sh vX.Y.Z
./scripts/build_from_tag.sh vX.Y.Z
./scripts/make_update_manifest.sh vX.Y.Z
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
./scripts/run_node.sh --datadir ./data
./scripts/mine_solo.sh --address rBTC_ADDRESS
```

## Docs
- `specs/` — requirements and acceptance criteria
- `references/` — trust model, verification guide, update protocol
- `skill/` — Agent Skill packaging
- `ralph/` — planning/build loop
