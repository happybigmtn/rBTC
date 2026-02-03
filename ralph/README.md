# Ralph Development Guide

One context window. One task. Fresh each iteration.

> "Deliberate allocation in an undeterministic world."

---

## Core Philosophy

Ralph maximizes LLM effectiveness through:

- **Context discipline** — Stay in the "smart zone" (40-60% of ~176K usable tokens)
- **Single-task focus** — One goal per iteration, then context reset
- **Subagent memory extension** — Fan out to avoid polluting main context
- **Backpressure-driven quality** — Tests reject invalid work, forcing correction
- **Human ON the loop, not IN it** — Engineer the environment, not the execution
- **Let Ralph Ralph** — Trust self-identification, self-correction, self-improvement

---

## Three Phases, Two Prompts, One Loop

### Phase 1: Define Requirements (Human + LLM Conversation)

Create specifications that define **WHAT**, not HOW:

```
specs/
├── scaling_100x_plan.md    # Scalability requirements
├── scaling_500x_plan.md    # Higher-scale requirements
├── devnet_100x.md          # Test results and findings
└── settlement_drain_*.md   # Settlement behavior specs
```

**Topic Scope Test**: Describe it in one sentence without "and"
- ✓ "The settlement system drains queued bets after RNG reveal"
- ✗ "The system handles betting, settlement, and RNG" → 3 topics

**Acceptance Criteria** define observable, verifiable outcomes:
- ✓ "Settlement drain processes 4+ groups per transaction"
- ✓ "Zero invalidPhaseErrors at 100 concurrent bots"
- ✗ "Uses efficient algorithms" (that's implementation, not outcome)

### Phase 2: Planning Mode

```bash
./loopclaude.sh plan              # Full planning
./loopclaude.sh plan-work "scope" # Scoped planning
```

**What happens:**
1. Subagents study `specs/*` (requirements)
2. Subagents study `game/src/*`, `scripts/*`, `web/*` (current state)
3. Gap analysis: compare specs vs code
4. **Derive test requirements from acceptance criteria**
5. Create prioritized `IMPLEMENTATION_PLAN.md`
6. **No implementation** — planning only

### Phase 3: Building Mode

```bash
./loopclaude.sh        # Build until done
./loopclaude.sh 20     # Max 20 iterations
```

**Each iteration:**
1. **Orient** — Study specs with subagents
2. **Read plan** — Pick most important unchecked task
3. **Investigate** — Search codebase (don't assume not implemented!)
4. **Implement** — Code + required tests (TDD approach)
5. **Validate** — Run tests (backpressure)
6. **Update plan** — Mark done, note discoveries
7. **Commit** — Only when tests pass
8. **Loop ends** — Context cleared, next iteration fresh

---

## ⚠️ CRITICAL: Backpressure & Test Requirements

**This is what makes Ralph work.** Without proper backpressure, Ralph produces untested, unreliable code.

### The Backpressure Principle

```
Specs (WHAT success looks like)
    ↓ derive
Test Requirements (WHAT to verify)
    ↓ implement
Tests (binary pass/fail)
    ↓ enforce
Implementation (HOW to achieve it)
```

**Key insight:** Tests verify **WHAT** works, not **HOW** it's implemented. Implementation approach is up to Ralph; verification criteria are not.

### Acceptance-Driven Test Derivation

During **planning**, each task must include derived test requirements:

```markdown
## Task: LUT-Enabled Settlement Drains

- [ ] Create Address Lookup Table for settlement drain accounts
- [ ] Update drainSettlementQueue to use LUT indices

**Required Tests (from acceptance criteria):**
- Test: Settlement drain with 8 groups succeeds (tx size < 1232 bytes)
- Test: Drain throughput increases ≥2x vs baseline
- Test: Zero InvalidRngPhase errors with LUT-enabled drains
```

### No Cheating Rule

**A task is NOT complete until:**
1. All required tests exist
2. All required tests pass
3. Changes are committed

You cannot claim done without tests passing. Tests are **part of implementation scope**, not optional.

### Test Categories

| Category | Validates | Example |
|----------|-----------|---------|
| **Unit** | Single function behavior | `evaluate_bet(PASS, 7, 0) == Win` |
| **Integration** | Component interaction | Settlement worker drains queue after RNG reveal |
| **E2E** | Full flow | 50 bots place bets, RNG commits, settlement drains |
| **Scale** | Concurrency limits | 100 bots with <1% invalidPhaseErrors |

### Implementation Plan Format

Each task MUST include:

```markdown
### 1.2 Address Lookup Tables for Drains
- [ ] Create `scripts/admin/create-drain-lut.mts`
- [ ] Update `drainSettlementQueue` in `devnet_e2e.mts`

**Required Tests:**
```typescript
// Integration test: LUT drain succeeds
test('drain with 8 groups using LUT', async () => {
  const result = await drainSettlementQueue({ limit: 8, useLUT: true });
  expect(result.txSize).toBeLessThan(1232);
  expect(result.groupsProcessed).toBe(8);
});

// Scale test: Throughput improvement
test('LUT drains increase throughput', async () => {
  const baseline = await measureDrainThroughput({ useLUT: false });
  const withLUT = await measureDrainThroughput({ useLUT: true });
  expect(withLUT.drainsPerMin).toBeGreaterThan(baseline.drainsPerMin * 1.8);
});
```

**Acceptance Criteria (from spec):**
- 8+ groups per drain transaction
- Transaction size under 1232 bytes
- ≥2x throughput improvement
```

---

## Steering Ralph

### Upstream Steering (Inputs)

- **Specs with acceptance criteria** — Clear success conditions
- **Existing code patterns** — Ralph discovers and follows them
- **`AGENTS.md`** — Operational commands, build/test instructions

### Downstream Steering (Backpressure)

- **Tests** — Derived from acceptance criteria, binary pass/fail
- **Build** — Must compile (Rust: `cargo build-sbf`, TS: `pnpm build`)
- **Type checks** — Rust compiler, TypeScript
- **E2E** — Scale tests via `devnet_e2e.mts` and `devnet_scale_ramp.mts`

**`AGENTS.md` specifies the actual commands:**

```markdown
## Validation Commands

- Build program: `cargo build-sbf -p rsociety`
- Run E2E tests: `npx tsx scripts/devnet_e2e.mts --smoke`
- Scale test: `npx tsx scripts/devnet_scale_ramp.mts --stages 50,100`
- Start keeper: `npx tsx scripts/keeper.mts --interval 2`
- Start settlement worker: `npx tsx scripts/settlement_worker.mts`
```

### When Things Go Wrong

| Symptom | Solution |
|---------|----------|
| Ralph goes in circles | Regenerate plan |
| Tests not running | Update `AGENTS.md` with correct commands |
| Wrong patterns | Add utilities/patterns for Ralph to discover |
| Missing tests | Add to plan with explicit test requirements |
| Task claimed done but broken | Add failing test, mark task incomplete |

---

## Files

```
rBitcoin/
├── ralph/                   # Ralph loop + prompts
│   ├── loopcodex.sh
│   ├── PROMPT_plan.md
│   ├── PROMPT_build.md
│   └── logs/
├── AGENTS.md                # Operational guide (~60 lines max)
├── specs/                   # Requirement specs
├── scripts/                 # Build/verify/update/mine tools
├── patch/                   # Immutable patch + hash
├── manifests/               # Update manifests
├── schemas/                 # JSON schemas
├── references/              # Trust + verification docs
├── skill/                   # Agent skill bundle
└── .github/workflows/        # CI
```

### `AGENTS.md`

Operational only. Contains:
- Build commands
- Test commands
- Validation commands
- Codebase patterns

**NOT** a changelog. Status belongs in `IMPLEMENTATION_PLAN.md`.

### `IMPLEMENTATION_PLAN.md`

Prioritized task list with test requirements. Ralph manages this file.

```markdown
## P1 — Immutable Patch + Scope Enforcement

### P1-T1 Add immutable patch scaffolding
- [ ] Add `patch/immutable.patch` placeholder and `patch/allowlist.txt`
- [ ] Add `scripts/enforce_patch_scope.sh` to reject changes outside allowlist

**Required Tests:**
- `./scripts/tests/test_patch_scope_allowlist.sh`
```

**Plan is disposable** — If wrong, regenerate. One planning loop is cheap.

---

## Acceptance Criteria → Test Requirements Flow

### In Specs (Phase 1)

```markdown
# specs/scaling_500x_plan.md

## Acceptance Criteria

1. Settlement drain with 8 groups succeeds
2. Transaction size stays under 1232 bytes
3. Drain throughput ≥2x baseline
4. Zero InvalidRngPhase errors from LUT changes
```

### In Plan (Phase 2)

```markdown
### Task: LUT-Enabled Settlement Drains

- [ ] Create drain LUT with static addresses
- [ ] Update drainSettlementQueue to use LUT

**Required Tests (derived from acceptance criteria):**

```typescript
test('8-group drain with LUT under size limit', async () => {
  const tx = await buildDrainTx({ groups: 8, useLUT: true });
  expect(tx.serialize().length).toBeLessThan(1232);
});

test('drain throughput doubles with LUT', async () => {
  const baseline = await runDrainBenchmark({ useLUT: false });
  const withLUT = await runDrainBenchmark({ useLUT: true });
  expect(withLUT.throughput).toBeGreaterThanOrEqual(baseline.throughput * 2);
});

test('no InvalidRngPhase with LUT drains', async () => {
  const result = await runScaleTest({ bots: 100, useLUT: true });
  expect(result.invalidRngPhaseErrors).toBe(0);
});
```
```

### In Code (Phase 3)

Ralph implements both the code change AND the tests. Task not done until tests pass.

---

## Summary: The Ralph Contract

1. **Specs define WHAT** — Behavioral outcomes, acceptance criteria
2. **Plan derives TESTS** — From acceptance criteria, before implementation
3. **Build implements ALL** — Code + tests, together
4. **Tests enforce DONE** — Can't commit without passing
5. **Loop provides ITERATION** — Eventual consistency through repetition

**No tests = No done. Tests verify WHAT, not HOW.**

---

*Based on [The Ralph Playbook](https://github.com/ClaytonFarr/ralph-playbook) by Clayton Farr and [original Ralph methodology](https://ghuntley.com/ralph/) by Geoffrey Huntley.*
