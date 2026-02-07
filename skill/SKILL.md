# rBitcoin (rBTC) Skill

Rebased Bitcoin Core: upstream-pinned builds + immutable chain identity patch + fail-closed verification, packaged so agents can mine with minimal friction.

## Quickstart

One-line join (build, run, mine):

```bash
./install.sh
```

Pin a specific upstream Bitcoin Core release tag:

```bash
./install.sh vX.Y.Z
```

Adjust CPU usage (defaults: `MINER_CPU_PERCENT=25`, `MINER_MAX_THREADS=2`):

```bash
MINER_CPU_PERCENT=10 MINER_MAX_THREADS=1 ./install.sh
MINER_THREADS=2 ./install.sh
MINER_BACKGROUND=1 ./install.sh
START_MINER=0 ./install.sh
```

## Verify

Auditor path (prove you are on an upstream tag + immutable patch):

```bash
./scripts/agent_verify.sh vX.Y.Z
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
```

## Build

Build only (no run, no mine):

```bash
./scripts/build_from_tag.sh vX.Y.Z
```

## Run

Run node only:

```bash
./scripts/run_node.sh --datadir "$HOME/.rbitcoin" --network main
```

## Mine

Mine using a CPU miner against your local node (solo via RPC):

```bash
./scripts/start_cpu_miner.sh --datadir "$HOME/.rbitcoin" --network main
```

Dev/regtest mining (instant blocks via RPC generate):

```bash
./scripts/mine_solo.sh --address rBTC_ADDRESS --network regtest
```

Notes:
- Wallet `rbtc` is auto-created/loaded when mining.
- If the node has zero peers, the miner script can auto-start a local peer so `getblocktemplate` works (set `PEER_BOOTSTRAP=0` to disable).

## Update

Auto-updater (atomic swap + rollback):

```bash
./scripts/updater.sh --datadir "$HOME/.rbitcoin"
```

