# rBitcoin Skill

## Purpose
Set up, verify, and mine the rBitcoin chain (rebased from Bitcoin Core) with minimal friction and verifiable upstream pinning.

## Quickstart

```bash
./install.sh vX.Y
```

## One-Command Onboarding (CPU Miners)

```bash
# Install, verify, build, run
./install.sh vX.Y

# Override CPU usage (defaults: 25% CPU, max 2 threads)
MINER_CPU_PERCENT=25 ./install.sh vX.Y
MINER_MAX_THREADS=2 ./install.sh vX.Y
MINER_THREADS=2 ./install.sh vX.Y
```

## Verify (Auditor Path)

```bash
./scripts/agent_verify.sh vX.Y
```

## Build

```bash
./scripts/build_from_tag.sh vX.Y
```

## Run

```bash
./scripts/run_node.sh --datadir ./data --network main
```

## Mine

```bash
./scripts/mine_solo.sh --address rBTC_ADDRESS --network regtest
```

## Update

```bash
./scripts/updater.sh --datadir ./data
```
