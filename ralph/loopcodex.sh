#!/usr/bin/env bash
# Ralph loop runner using Codex CLI (gpt-5.2-codex)
# Usage: ./loopcodex.sh [mode] [max_iterations]
# Examples:
#   ./loopcodex.sh                        # Build mode, unlimited iterations
#   ./loopcodex.sh 20                     # Build mode, max 20 iterations
#   ./loopcodex.sh plan                   # Plan mode, unlimited iterations
#   ./loopcodex.sh plan 5                 # Plan mode, max 5 iterations
#   ./loopcodex.sh plan-work "scope"      # Scoped planning for work branch
#   ./loopcodex.sh plan-work "scope" 3    # Scoped planning, max 3 iterations

set -euo pipefail

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Resolve script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
LOG_DIR="$SCRIPT_DIR/logs"

# Codex configuration
CODEX_MODEL="${CODEX_MODEL:-gpt-5.2-codex}"
CODEX_REASONING="${CODEX_REASONING:-high}"

# Find IMPLEMENTATION_PLAN.md - check repo root first, then ralph/ (matches loopclaude.sh)
if [[ -f "$REPO_ROOT/IMPLEMENTATION_PLAN.md" ]]; then
    PLAN_FILE="$REPO_ROOT/IMPLEMENTATION_PLAN.md"
elif [[ -f "$SCRIPT_DIR/IMPLEMENTATION_PLAN.md" ]]; then
    PLAN_FILE="$SCRIPT_DIR/IMPLEMENTATION_PLAN.md"
else
    echo -e "${RED}✗ Error: IMPLEMENTATION_PLAN.md not found${NC}"
    echo -e "${DIM}  Checked: $REPO_ROOT/IMPLEMENTATION_PLAN.md${NC}"
    echo -e "${DIM}  Checked: $SCRIPT_DIR/IMPLEMENTATION_PLAN.md${NC}"
    exit 1
fi

# Filter function to colorize and format Codex output
filter_output() {
    local line_count=0
    local in_code_block=0
    local last_was_empty=0

    while IFS= read -r line; do
        line_count=$((line_count + 1))

        # Skip excessive empty lines
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            if [[ "$last_was_empty" -eq 1 ]]; then
                continue
            fi
            last_was_empty=1
            echo ""
            continue
        fi
        last_was_empty=0

        # Track code blocks
        if [[ "$line" == '```'* ]]; then
            if [[ "$in_code_block" -eq 0 ]]; then
                in_code_block=1
                echo -e "${DIM}$line${NC}"
            else
                in_code_block=0
                echo -e "${DIM}$line${NC}"
            fi
            continue
        fi

        # Inside code block - show dimmed
        if [[ "$in_code_block" -eq 1 ]]; then
            echo -e "${DIM}  $line${NC}"
            continue
        fi

        # Colorize based on content patterns
        case "$line" in
            # Tool/action indicators
            *"Reading"*|*"reading"*)
                echo -e "${DIM}📖 $line${NC}"
                ;;
            *"Writing"*|*"writing"*|*"Creating"*|*"creating"*)
                echo -e "${GREEN}📝 $line${NC}"
                ;;
            *"Editing"*|*"editing"*|*"Updating"*|*"updating"*|*"Modified"*|*"modified"*)
                echo -e "${GREEN}✏️  $line${NC}"
                ;;
            *"Running"*|*"running"*|*"Executing"*|*"executing"*)
                echo -e "${YELLOW}⚡ $line${NC}"
                ;;
            *"Searching"*|*"searching"*|*"Looking"*|*"looking"*|*"Finding"*|*"finding"*)
                echo -e "${DIM}🔍 $line${NC}"
                ;;
            *"Testing"*|*"testing"*|*"Test"*|*"test "*|*"tests"*)
                echo -e "${CYAN}🧪 $line${NC}"
                ;;
            *"Commit"*|*"commit"*|*"Git"*|*"git "*)
                echo -e "${CYAN}📦 $line${NC}"
                ;;

            # Status indicators
            *"✓"*|*"Success"*|*"success"*|*"Complete"*|*"complete"*|*"Done"*|*"done"*|*"Pass"*|*"PASS"*)
                echo -e "${GREEN}$line${NC}"
                ;;
            *"✗"*|*"Error"*|*"error"*|*"Fail"*|*"fail"*|*"FAIL"*)
                echo -e "${RED}$line${NC}"
                ;;
            *"Warning"*|*"warning"*|*"TODO"*|*"FIXME"*|*"Skip"*|*"skip"*)
                echo -e "${YELLOW}$line${NC}"
                ;;
            *"Note:"*|*"INFO"*|*"Hint:"*)
                echo -e "${DIM}$line${NC}"
                ;;

            # Task/file references
            *"P1-"*|*"P2-"*|*"P3-"*|*"P4-"*|*"P5-"*)
                echo -e "${CYAN}▸ $line${NC}"
                ;;
            *".ts"*|*".tsx"*|*".rs"*|*".md"*|*".json"*)
                echo -e "${DIM}  $line${NC}"
                ;;

            # Headers and sections
            \#\#*)
                echo -e "${BOLD}${CYAN}$line${NC}"
                ;;
            \#*)
                echo -e "${BOLD}$line${NC}"
                ;;
            "---"*|"==="*|"━"*)
                echo -e "${DIM}$line${NC}"
                ;;

            # Bullet points
            "- ["*"]"*)
                if [[ "$line" == *"[x]"* ]]; then
                    echo -e "${GREEN}$line${NC}"
                else
                    echo -e "${YELLOW}$line${NC}"
                fi
                ;;
            "- "*|"* "*)
                echo -e "  $line"
                ;;

            # Default
            *)
                echo "  $line"
                ;;
        esac
    done
}

# Determine prompt file based on mode
MODE="build"
WORK_SCOPE=""
PROMPT_FILE="$SCRIPT_DIR/PROMPT_build.md"
MAX_ITERATIONS=0  # 0 = unlimited

if [[ "${1:-}" == "plan" ]]; then
    MODE="plan"
    PROMPT_FILE="$SCRIPT_DIR/PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "${1:-}" == "plan-work" ]]; then
    MODE="plan-work"
    PROMPT_FILE="$SCRIPT_DIR/PROMPT_plan_work.md"
    WORK_SCOPE="${2:-}"
    MAX_ITERATIONS=${3:-0}
    if [[ -z "$WORK_SCOPE" ]]; then
        echo -e "${RED}✗ Error: plan-work requires a scope description${NC}"
        echo -e "${DIM}Usage: ./loopcodex.sh plan-work \"description of work scope\"${NC}"
        exit 1
    fi
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
fi

mkdir -p "$LOG_DIR"

count_remaining() {
    grep -c '^- \[ \]' "$PLAN_FILE" 2>/dev/null || echo "0"
}

count_completed() {
    grep -c '^- \[x\]' "$PLAN_FILE" 2>/dev/null || echo "0"
}

count_blocked() {
    grep -c 'Blocked:' "$PLAN_FILE" 2>/dev/null || echo "0"
}

# Verify files exist
if [[ ! -f "$PROMPT_FILE" ]]; then
    echo -e "${RED}✗ Error: $PROMPT_FILE not found${NC}"
    exit 1
fi

# Header
CURRENT_BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")
echo ""
echo -e "${BOLD}🚀 Ralph Loop (Codex)${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Mode:      ${CYAN}$MODE${NC}"
echo -e "Model:     ${GREEN}$CODEX_MODEL${NC} ${DIM}(reasoning=$CODEX_REASONING)${NC}"
echo -e "Branch:    ${GREEN}$CURRENT_BRANCH${NC}"
echo -e "Prompt:    ${DIM}$(basename "$PROMPT_FILE")${NC}"
echo -e "Plan:      ${DIM}$PLAN_FILE${NC}"
[[ -n "$WORK_SCOPE" ]] && echo -e "Scope:     ${YELLOW}$WORK_SCOPE${NC}"
[[ "$MAX_ITERATIONS" -gt 0 ]] && echo -e "Max:       ${YELLOW}$MAX_ITERATIONS iterations${NC}"
[[ "$MAX_ITERATIONS" -eq 0 ]] && echo -e "Max:       ${DIM}unlimited${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

iteration=0
while true; do
    iteration=$((iteration + 1))
    remaining=$(count_remaining)
    completed=$(count_completed)
    timestamp=$(date +%Y%m%d-%H%M%S)
    log_file="$LOG_DIR/codex-${iteration}-${timestamp}.log"

    echo -e "${BOLD}${CYAN}═══════════════════════ LOOP $iteration ═══════════════════════${NC}"
    echo -e "  Remaining: ${YELLOW}$remaining${NC} | Completed: ${GREEN}$completed${NC}"
    echo ""

    if [[ "$remaining" -eq 0 ]]; then
        echo -e "${GREEN}✓ All tasks complete!${NC}"
        break
    fi

    if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$iteration" -gt "$MAX_ITERATIONS" ]]; then
        echo -e "${YELLOW}⚠ Max iterations ($MAX_ITERATIONS) reached. $remaining tasks remaining.${NC}"
        exit 1
    fi

    # Build prompt with scope substitution for plan-work mode
    if [[ "$MODE" == "plan-work" ]]; then
        export WORK_SCOPE
        prompt_content=$(envsubst < "$PROMPT_FILE")
    else
        prompt_content=$(cat "$PROMPT_FILE")
    fi

    # Capture plan hash before run (for plan mode progress detection)
    plan_hash_before=$(md5sum "$PLAN_FILE" | cut -d' ' -f1)

    # Run Codex CLI from repo root
    echo -e "${DIM}Running Codex from $REPO_ROOT...${NC}"
    start_time=$(date +%s)

    pushd "$REPO_ROOT" > /dev/null

    # Run Codex with reasoning level, pipe through filter, save to log
    if codex exec \
        --dangerously-bypass-approvals-and-sandbox \
        -m "$CODEX_MODEL" \
        -c "reasoning=$CODEX_REASONING" \
        "$prompt_content" 2>&1 | tee "$log_file" | filter_output; then
        echo ""
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo -e "${GREEN}✓ Codex completed${NC} ${DIM}(${duration}s)${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ Codex exited with error, checking if progress was made...${NC}"
    fi
    popd > /dev/null

    # Check progress - different logic for plan vs build mode
    if [[ "$MODE" == "plan" ]] || [[ "$MODE" == "plan-work" ]]; then
        # Plan mode: progress = file was modified
        plan_hash_after=$(md5sum "$PLAN_FILE" | cut -d' ' -f1)
        if [[ "$plan_hash_after" == "$plan_hash_before" ]]; then
            echo -e "${RED}✗ No progress made this iteration (plan unchanged)${NC}"
            echo -e "${DIM}  Check log: $log_file${NC}"
            echo -e "${DIM}  Waiting 10s before retry...${NC}"
            sleep 10
        else
            new_remaining=$(count_remaining)
            echo -e "${GREEN}✓ Plan updated: $remaining -> $new_remaining tasks${NC}"
        fi
    else
        # Build mode: progress = tasks completed
        new_remaining=$(count_remaining)
        if [[ "$new_remaining" -eq "$remaining" ]]; then
            echo -e "${RED}✗ No progress made this iteration${NC}"
            echo -e "${DIM}  Check log: $log_file${NC}"
            echo -e "${DIM}  Waiting 10s before retry...${NC}"
            sleep 10
        else
            tasks_done=$((remaining - new_remaining))
            echo -e "${GREEN}✓ Progress: $tasks_done task(s) completed ($remaining -> $new_remaining)${NC}"
        fi
    fi

    # Auto-commit if enabled (from repo root)
    if [[ "${RALPH_AUTOCOMMIT:-0}" == "1" ]] && [[ "$MODE" == "build" ]]; then
        if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
            ts=$(date +"%Y-%m-%d %H:%M:%S")
            msg="loop: iteration $iteration @ $ts (codex)"
            echo -e "${DIM}📦 Committing: $msg${NC}"
            git -C "$REPO_ROOT" add -A && git -C "$REPO_ROOT" commit -m "$msg" || echo -e "${YELLOW}⚠ Commit failed${NC}"
        fi
    fi

    echo ""
    sleep 2
done

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════ COMPLETE ═══════════════════════${NC}"
echo -e "  Total iterations: ${CYAN}$iteration${NC}"
echo -e "  Tasks completed:  ${GREEN}$(count_completed)${NC}"
echo -e "  Tasks remaining:  ${YELLOW}$(count_remaining)${NC}"
echo -e "  Tasks blocked:    ${RED}$(count_blocked)${NC}"
echo -e "  Logs:             ${DIM}$LOG_DIR/${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
