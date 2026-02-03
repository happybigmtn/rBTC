# Upstream Pinning Proof

## Summary
Prove a running node is derived from an official Bitcoin Core release with a scope-limited immutable patch.

## Acceptance Criteria
1. `scripts/verify_local_binary.sh` returns PASS and prints the upstream tag, patch hash, and verification evidence reference.
2. Verification FAILs if the local binary is modified or if the patch hash does not match `patch/immutable.patch.sha256`.
3. Patch scope enforcement rejects any change outside the allowlist of chain-identity files.
4. Verification outputs a machine-readable report in `reports/`.

## Out of Scope
- Any consensus rule changes beyond chain identity.
- Any PoW algorithm changes.
