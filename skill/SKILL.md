# rBitcoin Agent Skill

Bitcoin Core fork from genesis, upstream-pinned to official release tags.
The only delta is a scope-limited immutable patch for chain identity.

## Quickstart

```bash
./install.sh v30.2
```

This verifies the upstream release (GPG + checksums), builds with the immutable patch, starts the node, and optionally starts a CPU miner.

Override defaults:

```bash
MINER_CPU_PERCENT=25 MINER_MAX_THREADS=2 ./install.sh v30.2
```

## Verify

Audit the upstream release and local binary without running a node:

```bash
./scripts/agent_verify.sh v30.2
```

Outputs a machine-readable report to `reports/agent-verify-v30.2.json`.

Verify patch scope stays within the allowed file set:

```bash
./scripts/enforce_patch_scope.sh ./patch/immutable.patch
```

Verify binary provenance against a manifest:

```bash
./scripts/verify_local_binary.sh ./build/bitcoind ./manifests/manifest.json
```

## Build

```bash
./scripts/build_from_tag.sh v30.2
```

Fetches the upstream tag, applies the immutable patch, and compiles. The binary lands in `./build/bitcoind`.

Generate the update manifest after building:

```bash
./scripts/make_update_manifest.sh v30.2
```

## Run

```bash
./scripts/run_node.sh --datadir ~/.rbitcoin --network main
```

The node connects to the Contabo seed fleet automatically via `addnode` entries in `bitcoin.conf`. RPC defaults to port `19332`, P2P to `19333`.

## Mine

Solo CPU mining with `cpuminer` (sha256d):

```bash
./scripts/start_cpu_miner.sh --datadir ~/.rbitcoin --network main
```

For single-block mining (regtest/dev):

```bash
./scripts/mine_solo.sh --address <ADDRESS> --network regtest
```

Fleet deployment (10-node Contabo):

```bash
./scripts/deploy_contabo_fleet.sh v30.2
```

## Update

Atomic update to a new upstream tag:

```bash
./scripts/updater.sh v30.3
```

This builds and verifies the new version, then atomically swaps the `runtime/current` symlink. The previous version is preserved for rollback.

Check for the latest upstream release:

```bash
./scripts/fetch_upstream_release.sh
```
