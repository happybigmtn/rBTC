0a. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0b. Reference `specs/*` as needed for the scoped work.
0c. Source layout: `scripts/`, `patch/`, `references/`, `specs/`, `skill/`, `.github/workflows/`.

1. SCOPED implementation plan for: "${WORK_SCOPE}". Use up to 10 parallel subagents to study existing code and compare against specs. Update @IMPLEMENTATION_PLAN.md with prioritized tasks. Search for TODOs, minimal implementations, placeholders.

2. For each task, include TARGETED test requirements:
   - Specify exact test file/pattern and command with filter
   - Prefer unit tests over integration tests
   - NEVER: `npm test`, `pnpm test`, `cargo test` (runs everything)
   - ALWAYS use filters:
     ✓ `cd web && npm test -- --testPathPattern="my-feature"`
     ✓ `cd scripts && npm test -- my-feature`
     ✓ `cd game && cargo test test_my_function`

IMPORTANT: SCOPED PLANNING for "${WORK_SCOPE}" only. Include ONLY tasks directly related to this scope. Be conservative. Plan only — do NOT implement.

ULTIMATE GOAL: Achieve "${WORK_SCOPE}" for rBitcoin. If an element is missing, confirm with search first, then add to plan.

A task requiring "run all tests" or workspace-level commands is POORLY SCOPED.
Break it down or specify the exact test file/pattern.
