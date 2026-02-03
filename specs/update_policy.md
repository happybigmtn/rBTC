# Verified Auto-Updates

## Summary
Auto-update nodes only to verified upstream release tags with atomic swap and rollback.

## Acceptance Criteria
1. `scripts/fetch_upstream_release.sh` returns the latest upstream release tag deterministically.
2. `scripts/updater.sh` updates to the latest verified release without human intervention.
3. Update is atomic and supports rollback if a smoke test fails.
4. Update decisions are logged with accept/reject reasons.

## Out of Scope
- Canary or staged rollouts beyond a single-node policy.
