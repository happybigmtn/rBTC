# rBitcoin Implementation Plan

> Plan derived from `specs/*`. Each task includes required tests with targeted commands.

## P0 — Repo Scaffold + Skill Skeleton

### P0-T1 Create skill skeleton + trust references
- [ ] Add `skill/SKILL.md` with quickstart verify/build/run/mine/update steps
- [ ] Add `references/TRUST_MODEL.md` + `references/VERIFICATION_GUIDE.md`

**Required Tests:**
- `./scripts/tests/test_skill_skeleton.sh`
  - Verifies `skill/SKILL.md` exists and contains verify/build/run/mine/update sections
- `./scripts/tests/test_references_exist.sh`
  - Verifies trust/verification docs exist

## P1 — Immutable Patch + Scope Enforcement

### P1-T1 Add immutable patch scaffolding
- [ ] Add `patch/immutable.patch` placeholder and `patch/allowlist.txt`
- [ ] Add `scripts/enforce_patch_scope.sh` to reject changes outside allowlist

**Required Tests:**
- `./scripts/tests/test_patch_scope_allowlist.sh`
  - PASS on allowed paths
  - FAIL on disallowed paths

### P1-T2 Patch hash pinning
- [ ] Add `scripts/compute_patch_hash.sh`
- [ ] Add `patch/immutable.patch.sha256`
- [ ] Add CI job to fail on mismatch

**Required Tests:**
- `./scripts/tests/test_patch_hash_pinning.sh`
  - PASS when hash matches
  - FAIL when patch changes without hash update

## P2 — Upstream Tag Discovery + Authenticity Verification

### P2-T1 Latest upstream release tag discovery
- [ ] Add `scripts/fetch_upstream_release.sh` to resolve latest release tag deterministically

**Required Tests:**
- `./scripts/tests/test_fetch_upstream_release.sh`
  - Outputs a single `vX.Y.Z` tag

### P2-T2 Upstream release verification
- [ ] Add `scripts/verify_upstream_release.sh` to verify checksums/signatures (and Guix if enabled)
- [ ] Write JSON report to `reports/verification-<tag>.json`

**Required Tests:**
- `./scripts/tests/test_verify_upstream_release.sh`
  - PASS on known-good release artifacts (cached test fixtures)
  - FAIL on tampered artifacts

## P3 — Build + Manifest

### P3-T1 Build from tag + patch
- [ ] Add `scripts/build_from_tag.sh` to apply patch and build binaries
- [ ] Emit build log with tag and patch hash

**Required Tests:**
- `./scripts/tests/test_build_from_tag.sh`
  - Builds produce `bitcoind` and `bitcoin-cli` in `./build/`

### P3-T2 Manifest generation + schema
- [ ] Add `schemas/manifest.schema.json`
- [ ] Add `scripts/make_update_manifest.sh`
- [ ] Add `scripts/validate_manifest.sh`

**Required Tests:**
- `./scripts/tests/test_manifest_generation.sh`
  - Generated manifest validates against schema

## P4 — Local Binary Verification (Fail Closed)

### P4-T1 Local binary verifier
- [ ] Add `scripts/verify_local_binary.sh` to enforce manifest + patch hash + evidence

**Required Tests:**
- `./scripts/tests/test_verify_local_binary.sh`
  - PASS on known-good binary
  - FAIL on tampered binary

## P5 — Auto Updater + Rollback

### P5-T1 Auto updater with atomic swap
- [ ] Add `scripts/updater.sh` to fetch, verify, build, and atomically swap versions
- [ ] Add `references/UPDATE_PROTOCOL.md`

**Required Tests:**
- `./scripts/tests/test_updater_atomic_swap.sh`
  - Swap occurs atomically
  - Rollback on failed smoke test

## P6 — Agent Mining Quickstart

### P6-T1 Solo mining script
- [ ] Add `scripts/mine_solo.sh` for dev chain mining
- [ ] Ensure logs show mined height and coinbase address

**Required Tests:**
- `./scripts/tests/test_mine_solo.sh`
  - Mines at least one block on dev config

## P7 — Skill Packaging + Clawhub

### P7-T1 Skill bundle packaging
- [ ] Ensure `skill/` contains SKILL + scripts + references
- [ ] Add Clawhub metadata file if required

**Required Tests:**
- `./scripts/tests/test_skill_bundle.sh`
  - Verifies required files present
