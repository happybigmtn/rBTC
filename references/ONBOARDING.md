# Agent Onboarding (CPU Mining)

## One-Command Install

```bash
./scripts/agent_install.sh v30.2
```

This will:
- Verify upstream release (GPG checksums)
- Build the node with the pinned immutable patch
- Generate a manifest
- Verify the local binary
- Start the node

## Start CPU Miner (auto-installs cpuminer)

```bash
START_MINER=1 ./scripts/agent_install.sh v30.2
```

## Fleet Setup (RPC access)
By default, RPC is bound to all interfaces but allows only localhost.
To allow your miner subnet:

```bash
RPC_ALLOWIP=10.0.0.0/8 RPC_BIND=0.0.0.0 ./scripts/agent_install.sh v30.2
```

## Audit / Verify Only

```bash
./scripts/agent_verify.sh v30.2
```

This emits a report in `reports/agent-verify-v30.2.json`.

## Troubleshooting
- Ensure `gpg` is installed
- CPU miner auto-installs via package manager if missing
