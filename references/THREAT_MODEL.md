# Threat Model (Summary)

## Assets
- Verified upstream tag and release artifacts
- Immutable patch hash
- Build artifacts and update manifest

## Threats
- Malicious binary substitution
- Patch scope expansion
- Forged verification evidence

## Mitigations
- Signature/attestation verification
- Patch scope allowlist + hash pinning
- Manifest validation and local binary verification
