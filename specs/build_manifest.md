# Deterministic Build + Manifest

## Summary
Build artifacts are reproducible and bound to upstream tag, patch hash, and verification evidence.

## Acceptance Criteria
1. `scripts/build_from_tag.sh` produces runnable `bitcoind` and `bitcoin-cli` equivalents.
2. Build logs include the upstream tag and immutable patch hash.
3. `scripts/make_update_manifest.sh` generates a manifest with tag, patch hash, artifact hashes, and evidence reference.
4. `schemas/manifest.schema.json` validates generated manifests.

## Out of Scope
- Multi-platform builds beyond the declared target platforms.
