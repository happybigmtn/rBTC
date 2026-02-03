# Update Protocol

## Policy
- Track upstream release tags only.
- Reject updates unless authenticity verification passes.

## Steps
1. Discover latest upstream tag.
2. Verify release artifacts and signatures.
3. Build from tag + immutable patch.
4. Generate manifest and verify local binary.
5. Atomically swap binaries.
6. Run smoke test; rollback on failure.

## Rollback
- Keep previous binary version available.
- If smoke test fails, revert to previous binary and emit a failure report.
