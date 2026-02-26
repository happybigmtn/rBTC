# rBitcoin

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official release tags. The only allowed delta is a scope-limited immutable patch for chain identity. Nodes auto-update to verified releases and refuse to run if provenance checks fail.

## Network Launch (February 26, 2026)

Mining started today on the new rBTC genesis chain.

Current seed nodes:
- `95.111.227.14`
- `95.111.229.108`
- `95.111.239.142`
- `161.97.83.147`
- `161.97.97.83`
- `161.97.114.192`
- `161.97.117.0`
- `194.163.144.177`
- `185.218.126.23`
- `185.239.209.227`

## One-Click Install (CPU Miners)

```bash
./install.sh v30.2
```

This will verify, build, run the node, and attempt to start CPU mining.

## CPU Usage Caps (Defaults)

Default mining limits: **25% CPU** and **max 2 threads**.

Override:

```bash
MINER_CPU_PERCENT=25 ./install.sh v30.2
MINER_MAX_THREADS=2 ./install.sh v30.2
MINER_THREADS=2 ./install.sh v30.2
MINER_BACKGROUND=1 ./install.sh v30.2
```

Notes:
- Wallet `rbtc` is auto-created/loaded for mining.
- If the node has zero peers, the miner script will auto-start a local peer node to satisfy `getblocktemplate`.

## Does install download Bitcoin Core source?
Yes. The install flow builds a patched Bitcoin Core from source to preserve verifiable provenance. This clones the upstream repo for the selected tag.

If you want a no-source download path, we can add a prebuilt‑binary option (signed manifest) later.

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
