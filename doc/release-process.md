# Release Process

rBTC releases are anchored to an upstream Bitcoin Core tag plus the pinned immutable network patch in this repo.

## Local release build

```bash
./scripts/build-release.sh --tag v30.2
```

That flow:

1. Verifies the upstream Bitcoin Core release signatures and optional artifact checksums.
2. Enforces the immutable patch scope and patch hash pin.
3. Builds the patched binaries.
4. Generates the local update manifest and verifies the built daemon against it.
5. Packages a release tarball with public-node helpers and `SHA256SUMS`.

## Release bundle contents

- `bitcoind`
- `bitcoin-cli`
- `rbtc-doctor`
- `rbtc-start-cpu-miner`
- `rbtc-install-public-node`
- `rbtc-install-public-miner`
- `rbtc-bitcoind.service`
- `rbitcoin.conf.example`
- `PUBLIC-NODE.md`
- `manifest-<tag>.json`
- `verification-<tag>.json`

Cut tags only after the release tarball, manifest, and verification report all agree on the same upstream tag and patch hash.
