# Verification Guide

## Upstream Release Authenticity
1. Download official Bitcoin Core release artifacts for a tag `vX.Y.Z`.
2. Verify checksums and signatures from the official release process.
3. (Optional) Verify Guix attestations if policy requires.

## Immutable Patch Enforcement
1. Check `patch/immutable.patch.sha256` matches the computed hash.
2. Confirm patch only touches allowlisted files.

## Local Binary Verification
1. Validate manifest schema.
2. Match local binary hash to manifest.
3. Confirm upstream tag + patch hash + evidence reference.

## Expected Output
- `reports/verification-<tag>.json` with PASS/FAIL and evidence.
