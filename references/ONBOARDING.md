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

## Start CPU Miner

By default, `install.sh` attempts to start CPU mining. If the miner cannot be installed (e.g. missing package), it will continue without mining.

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
- Linux/WSL: CPU miner auto-installs via package manager
- macOS: Homebrew may not include `cpuminer`; install manually if needed
