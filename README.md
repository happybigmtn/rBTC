# rBitcoin

rBitcoin is a Bitcoin Core fork from genesis that is **upstream-pinned** to official release tags. The only allowed delta is a scope-limited immutable patch for chain identity. Nodes auto-update to verified releases and refuse to run if provenance checks fail.

## Network Launch (February 26, 2026)

Mining started on February 26, 2026 on the new rBTC genesis chain.

Current public seed nodes:
- `95.111.227.14`
- `95.111.239.142`
- `161.97.114.192`
- `161.97.117.0`
- `194.163.144.177`
- `185.218.126.23`
- `185.239.209.227`

Current production checkpoint as of March 19, 2026:
- height `23469`
- best block `50c40787ce75479c6d4cbd1b6aaea68f6796d004aaeaa3c22b428f4f64bd7aef`
- chainwork `00000000000000000000000000000000000000000000000000051db33243601b`

## One-Click Install (CPU Miners)

```bash
./install.sh v30.2
```

This will verify, build, run the node, and attempt to install and start
`cpuminer-opt` for SHA256d CPU mining.
Installer now:
- installs or reuses pinned `cpuminer-opt` by default
- stops any running local `rBTC` daemon before replacing binaries
- waits for RPC readiness before miner startup
- fails fast if peers are reachable but local height remains `0` (consensus mismatch guard)

Install enforces network patch pinning before build:
- required hash source: `references/NETWORK_PATCH_HASH`
- local patch hash source: `patch/immutable.patch.sha256`

If hashes differ, install auto-updates `references/NETWORK_PATCH_HASH` by default.
Set `AUTO_ACCEPT_NETWORK_PATCH_HASH=0` for strict fail-fast pinning.

By default, install also writes:
- `~/.local/bin/rbtc-cli`
- `~/.local/bin/rbtc-bitcoind`
- `~/.local/bin/rbtc-doctor`
- `~/.local/bin/rbtc-start-cpu-miner`

These wrappers point to the repo-built binaries and `~/.rbitcoin`, so machines
with an existing Bitcoin Core mainnet install don't conflict with rBTC commands.

## CPU Usage Caps (Defaults)

Default mining limits: **25% CPU** and **max 20 threads**.

Override:

```bash
MINER_CPU_PERCENT=25 ./install.sh v30.2
MINER_MAX_THREADS=20 ./install.sh v30.2
MINER_THREADS=2 ./install.sh v30.2
MINER_BACKGROUND=1 ./install.sh v30.2
```

Notes:
- Wallet `rbtc` is auto-created/loaded for mining.
- If the node has zero peers, the miner script will auto-start a local peer node to satisfy `getblocktemplate`.
- `rbtc-doctor` verifies genesis hash, peer connectivity, and public-node visibility.

## Does install download Bitcoin Core source?
Yes. The install flow builds a patched Bitcoin Core from source to preserve verifiable provenance. This clones the upstream repo for the selected tag.

For operators who want a release bundle instead of a repo checkout, use `./scripts/build-release.sh` and distribute the generated tarball plus `SHA256SUMS`.

## Public VPS Nodes

If you want to strengthen the live network, run a public node on a VPS and open `19333/TCP`:

```bash
sudo ./scripts/public-apply.sh --address YOUR_RBTC_ADDRESS --enable-now
sudo ufw allow 19333/tcp
```

Use `rbtc-doctor --json --strict --expect-public --expect-miner` to confirm the node is on the live chain, reachable, and actively mining.

## Quickstart (Manual)

```bash
./scripts/fetch_upstream_release.sh
./scripts/verify_upstream_release.sh vX.Y
./scripts/build_from_tag.sh vX.Y
./scripts/make_update_manifest.sh vX.Y
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
./scripts/build-release.sh --tag vX.Y
./scripts/run_node.sh --datadir ./data --network main
./scripts/start_cpu_miner.sh --datadir ./data --network main
```

## Docs
- `doc/public-node.md` — public-node and public-miner operator guide
- `doc/release-process.md` — tag-first build and packaging flow
- `specs/` — requirements and acceptance criteria
- `references/` — trust model, verification guide, update protocol
- `skill/` — Agent Skill packaging
- `ralph/` — planning/build loop
- `CHANGELOG.md` — version history
