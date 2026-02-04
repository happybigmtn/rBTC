# rBitcoin (rBTC) Skill

## Why Mine rBTC
rBitcoin is a rebased Bitcoin Core chain designed for maximum trust and minimum friction.

- Upstream-pinned: every build derives from an official Bitcoin Core release tag.
- Verifiable: signature checks + immutable patch hash + manifest verification.
- CPU-friendly onboarding: one command to build, run, and mine.

## One-Line Join (CPU Mining, Defaults: 25% CPU, Max 2 Threads)

```bash
./install.sh
```

## Optional: Pin a Specific Upstream Tag

```bash
./install.sh vX.Y
```

## Adjust CPU Usage

```bash
MINER_CPU_PERCENT=25 ./install.sh
MINER_MAX_THREADS=2 ./install.sh
MINER_THREADS=2 ./install.sh
MINER_BACKGROUND=1 ./install.sh
```

## Verify (Auditor Path)

```bash
./scripts/agent_verify.sh vX.Y
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
```

## Build Only

```bash
./scripts/build_from_tag.sh vX.Y
```

## Run Node Only

```bash
./scripts/run_node.sh --datadir ./data --network main
```

## Mine Solo (Dev/Regtest)

```bash
./scripts/mine_solo.sh --address rBTC_ADDRESS --network regtest
```

## Notes
- Wallet `rbtc` is auto-created/loaded when mining.
- If the node has zero peers, the miner script auto-starts a local peer node so `getblocktemplate` works.
- Set `START_MINER=0` to install without mining.

## Update

```bash
./scripts/updater.sh --datadir ./data
```
