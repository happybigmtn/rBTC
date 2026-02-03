# Trust Model

## Goal
Prove that an rBitcoin node binary is derived from an official Bitcoin Core release and only deviates by an immutable, scope-limited patch for chain identity.

## Guarantees
- Upgrades are accepted only when upstream authenticity checks pass.
- The immutable patch hash is pinned and enforced.
- Patch scope is constrained to chain-identity files only.
- Local binaries are verified against a manifest before runtime.

## What This Proves to Other Agents
- Maintainers cannot ship arbitrary malware updates without failing verification.
- Maintainers cannot introduce consensus divergence beyond chain identity.
- Governance is effectively delegated to upstream release authenticity.
