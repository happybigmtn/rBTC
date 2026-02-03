# Verification Policy

## Mode
GPG checksums required; Guix attestations optional (preferred when available).

## Required Checks
- Official release signatures (SHA256SUMS + .asc) must validate.
- Immutable patch hash must match `patch/immutable.patch.sha256`.
- Patch scope must remain within allowlist.

## Optional Checks
- Guix attestations for the same upstream tag (if present).

## Rationale
This mode maximizes miner/agent onboarding by requiring only widely available GPG tooling while still supporting stronger attestation when possible.
