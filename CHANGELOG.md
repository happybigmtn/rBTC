# Changelog

## 2026-02-26
- Reset rBTC to a new genesis chain.
- Updated genesis timestamp message to mark prior chain versions invalid.
- Started mining on the new chain.
- Set the 10-node Contabo fleet as bootstrap seed nodes.

## 2026-02-26 (Repo Hygiene)
- Moved internal implementation/planning docs out of version control via `.gitignore`.
- Kept only `references/GENESIS.json` tracked as required build configuration.

## 2026-02-26 (Install UX)
- Updated install flow to write managed seed bootstrap config into `bitcoin.conf`.
- Added `rbtc-cli` and `rbtc-bitcoind` wrappers in `~/.local/bin`.
- Preserved coexistence with system Bitcoin Core mainnet by avoiding global overrides.
- Added install-time network patch pin enforcement using `references/NETWORK_PATCH_HASH`.
- Enabled install-time auto-accept of patch pin mismatch (override with `AUTO_ACCEPT_NETWORK_PATCH_HASH=0`).
- Added installer pre-build daemon shutdown to avoid `Text file busy` binary replacement failures.
- Added installer RPC-readiness and seed-sync guard to fail fast on consensus mismatch.
