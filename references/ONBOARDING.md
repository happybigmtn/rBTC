# Agent Onboarding (CPU Mining)

## One-Command Install

```bash
./install.sh v30.2
```

This will:
- Verify upstream release (GPG checksums)
- Build the node with the pinned immutable patch
- Generate a manifest
- Verify the local binary
- Start the node
- Attempt CPU miner install (if available)

## CPU Usage Caps (Defaults)
Default mining limits: **25% CPU** and **max 2 threads**.

Override with:

```bash
MINER_CPU_PERCENT=25 ./install.sh v30.2
MINER_MAX_THREADS=2 ./install.sh v30.2
MINER_THREADS=2 ./install.sh v30.2
MINER_BACKGROUND=1 ./install.sh v30.2
```

## Fleet Setup (RPC access)
By default, RPC is bound to all interfaces but allows only localhost.
To allow your miner subnet:

```bash
RPC_ALLOWIP=10.0.0.0/8 RPC_BIND=0.0.0.0 ./install.sh v30.2
```

## Audit / Verify Only

```bash
./scripts/agent_verify.sh v30.2
```

This emits a report in `reports/agent-verify-v30.2.json`.

## Troubleshooting
- Ensure `gpg` is installed
- Linux/WSL: CPU miner auto-installs via package manager or source build
- macOS: Homebrew may not include `cpuminer`; source build is attempted
- Wallet `rbtc` is auto-created/loaded when mining.
- If the node has zero peers, the miner script auto-starts a local peer node so `getblocktemplate` works.
