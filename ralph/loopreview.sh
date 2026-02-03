#!/usr/bin/env bash
# Ralph review loop - review completed tasks, apply fixes, archive, commit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_FILE="$SCRIPT_DIR/ARCHIVE2.md"

# Find IMPLEMENTATION_PLAN.md - check repo root first, then ralph/ (matches loopclaude.sh)
if [[ -f "$REPO_ROOT/IMPLEMENTATION_PLAN.md" ]]; then
    PLAN_FILE="$REPO_ROOT/IMPLEMENTATION_PLAN.md"
elif [[ -f "$SCRIPT_DIR/IMPLEMENTATION_PLAN.md" ]]; then
    PLAN_FILE="$SCRIPT_DIR/IMPLEMENTATION_PLAN.md"
else
    echo "Error: IMPLEMENTATION_PLAN.md not found"
    echo "  Checked: $REPO_ROOT/IMPLEMENTATION_PLAN.md"
    echo "  Checked: $SCRIPT_DIR/IMPLEMENTATION_PLAN.md"
    exit 1
fi
LOG_DIR="$SCRIPT_DIR/logs"

# Codex configuration (model name based on codex CLI docs/help in this environment)
CODEX_MODEL="${CODEX_MODEL:-gpt-5.2-codex}"
CODEX_REASONING="${CODEX_REASONING:-xhigh}"

mkdir -p "$LOG_DIR"

# Capture associated specs from the current plan before modifications
mapfile -t ASSOCIATED_SPECS < <(grep -oE 'specs/[^` )]+' "$PLAN_FILE" | sort -u || true)

echo "Using plan file: $PLAN_FILE"

if [[ ! -f "$ARCHIVE_FILE" ]]; then
	cat <<'EOF' >"$ARCHIVE_FILE"
# Implementation Plan Archive
EOF
fi

mapfile -t COMPLETED_ITEMS < <(grep '^- \[x\]' "$PLAN_FILE" || true)

if [[ "${#COMPLETED_ITEMS[@]}" -eq 0 ]]; then
	echo "No completed tasks found in $PLAN_FILE"
	exit 0
fi

ARCHIVE_HEADER_ADDED=0
ARCHIVE_SECTION="## Review Signoff ($(date +%Y-%m-%d)) - SIGNED OFF"

archive_item() {
	local block="$1"
	if [[ "$ARCHIVE_HEADER_ADDED" -eq 0 ]]; then
		printf "\n%s\n\n" "$ARCHIVE_SECTION" >>"$ARCHIVE_FILE"
		ARCHIVE_HEADER_ADDED=1
	fi
	printf "%s\n\n" "$block" >>"$ARCHIVE_FILE"
}

get_item_block() {
	local item="$1"
	awk -v target="$item" '
    BEGIN { found=0 }
    {
      if (!found && $0 == target) {
        found=1;
        print $0;
        next;
      }
      if (found) {
        if ($0 ~ /^- \[/ || $0 ~ /^## / || $0 ~ /^# /) {
          exit;
        }
        print $0;
      }
    }
  ' "$PLAN_FILE"
}

remove_item_from_plan() {
	local item="$1"
	awk -v target="$item" '
    BEGIN { in_block=0 }
    {
      if (!in_block && $0 == target) {
        in_block=1;
        next;
      }
      if (in_block) {
        if ($0 ~ /^- \[/ || $0 ~ /^## / || $0 ~ /^# /) {
          in_block=0;
          print $0;
        }
        next;
      }
      print $0;
    }
  ' "$PLAN_FILE" >"${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"
}

for item in "${COMPLETED_ITEMS[@]}"; do
	timestamp=$(date +%Y%m%d-%H%M%S)
	log_file="$LOG_DIR/review-${timestamp}.log"

	# Get the full task block for context (includes acceptance criteria, tests, etc.)
	task_block="$(get_item_block "$item")"

	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "Reviewing item: $item"
	echo "Plan file: $PLAN_FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	cat <<EOF_PROMPT | codex exec \
		--dangerously-bypass-approvals-and-sandbox \
		-m "$CODEX_MODEL" \
		-c "reasoning=$CODEX_REASONING" \
		-C "$REPO_ROOT" \
		- 2>&1 | tee "$log_file"
You are reviewing a completed task from IMPLEMENTATION_PLAN.md.

Task line:
$item

Full task context (includes acceptance criteria, required tests, etc.):
$task_block

CRITICAL - Large File Handling:
- NEVER read entire files over 1000 lines. Use Grep to search for specific patterns.
- For verification, use Grep to find function names, test names, or key identifiers.
- If you must read a large file, use offset and limit parameters (e.g., offset=100, limit=200).
- Prefer: Grep for "fn test_" or "struct BatchMessage" over reading the whole file.
- Use Glob to find files, then Grep to verify content exists.

CRITICAL - Targeted Testing (violating this wastes hours):
- Run ONLY tests relevant to THIS specific task — nothing else
- NEVER run workspace-level commands:
  ✗ npm test (runs all 2000+ web tests)
  ✗ pnpm test (runs all workspace tests)
  ✗ cargo test (runs all Rust tests)
  ✗ cargo test-sbf (runs all on-chain tests)
- ALWAYS use filters to scope to task-relevant files:
  ✓ cd web && npm test -- --testPathPattern="lp-withdrawal"
  ✓ cd mobile && npm test -- useRebate
  ✓ cd game && cargo test test_queue_activation
  ✓ cd scripts && npm test -- exposure-utils
- If the task mentions specific test files/names, run ONLY those
- IGNORE unrelated test failures — they are not your concern

Instructions:
1) Review code, tests, and docs relevant to the task using Grep searches, not full file reads.
2) Verify tests exist by grepping for test function names, not by reading entire test files.
3) Run ONLY the task-specific tests (use filters, never workspace-level commands).
4) Make necessary changes and ensure the task is truly complete.
5) Update IMPLEMENTATION_PLAN.md if you find issues or need follow-ups.
6) If the task is fully correct, mark it as signed off. Do NOT leave stubs.
7) Do NOT add new tasks unless strictly necessary.
8) Do not archive the task yourself; the outer loop will archive after your review.
9) Commit changes with a clear message ONLY when the task is signed off.

Output only "SIGNED_OFF" when complete, otherwise output "NEEDS_WORK".
EOF_PROMPT

	if grep -q "SIGNED_OFF" "$log_file"; then
		if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
			echo "Changes detected; committing review update."
			git -C "$REPO_ROOT" add -A
			git -C "$REPO_ROOT" commit -m "review: ${item#- [x] }" || true
		fi

		if grep -Fqx -- "$item" "$PLAN_FILE"; then
			block="$(get_item_block "$item")"
			remove_item_from_plan "$item"
			if [[ -n "$block" ]]; then
				archive_item "$block"
			else
				archive_item "$item"
			fi
		else
			archive_item "$item"
		fi

		git -C "$REPO_ROOT" add "$PLAN_FILE" "$ARCHIVE_FILE"
		git -C "$REPO_ROOT" commit -m "archive: ${item#- [x] }" || true
	else
		echo "Item not signed off; leaving in plan: $item"
	fi
done

# If no remaining tasks, archive associated specs captured at start
remaining=$(grep '^- \[ \]' "$PLAN_FILE" | wc -l || true)
completed_left=$(grep '^- \[x\]' "$PLAN_FILE" | wc -l || true)

if [[ "$remaining" -eq 0 && "$completed_left" -eq 0 ]]; then
	for spec in "${ASSOCIATED_SPECS[@]}"; do
		if [[ -f "$REPO_ROOT/$spec" ]]; then
			mkdir -p "$REPO_ROOT/specs/archive"
			mv "$REPO_ROOT/$spec" "$REPO_ROOT/specs/archive/"
		fi
	done
	if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
		git -C "$REPO_ROOT" add -A
		git -C "$REPO_ROOT" commit -m "archive: specs" || true
	fi
fi

echo "Review loop complete."
