#!/usr/bin/env bash
# Ralph loop runner - iteratively implement tasks from IMPLEMENTATION_PLAN.md
# Usage: ./loopclaude.sh [mode] [max_iterations]
# Examples:
#   ./loopclaude.sh                        # Build mode, unlimited iterations
#   ./loopclaude.sh 20                     # Build mode, max 20 iterations
#   ./loopclaude.sh plan                   # Plan mode, unlimited iterations
#   ./loopclaude.sh plan 5                 # Plan mode, max 5 iterations
#   ./loopclaude.sh plan-work "scope"      # Scoped planning for work branch
#   ./loopclaude.sh plan-work "scope" 3    # Scoped planning, max 3 iterations

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

# Find IMPLEMENTATION_PLAN.md - check repo root first, then ralph/
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

# Filter function to extract readable output from stream-json
filter_output() {
    local current_tool=""
    local text_buffer=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Validate JSON before parsing
        if ! echo "$line" | jq -e . >/dev/null 2>&1; then
            continue
        fi

        type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
        subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)

        case "$type" in
            "system")
                case "$subtype" in
                    "init")
                        echo -e "${DIM}🔧 Session initialized${NC}"
                        ;;
                esac
                ;;
            "user")
                # User messages (usually tool results or prompts)
                ;;
            "assistant")
                # Show tool uses with details
                tool_name=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .name // empty' 2>/dev/null | head -1)
                if [[ -n "$tool_name" ]]; then
                    case "$tool_name" in
                        "Read")
                            file=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.file_path // empty' 2>/dev/null | head -1)
                            # Show full path for context, truncate if too long
                            display_path="${file}"
                            [[ ${#display_path} -gt 60 ]] && display_path="...${file: -57}"
                            echo -e "${DIM}📖 Read${NC} ${display_path}"
                            ;;
                        "Write")
                            file=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.file_path // empty' 2>/dev/null | head -1)
                            display_path="${file}"
                            [[ ${#display_path} -gt 60 ]] && display_path="...${file: -57}"
                            echo -e "${GREEN}📝 Write${NC} ${display_path}"
                            ;;
                        "Edit"|"MultiEdit")
                            file=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.file_path // empty' 2>/dev/null | head -1)
                            old_str=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.old_string // empty' 2>/dev/null | head -c 40 | tr '\n' ' ')
                            display_path="${file}"
                            [[ ${#display_path} -gt 50 ]] && display_path="...${file: -47}"
                            if [[ -n "$old_str" ]]; then
                                echo -e "${GREEN}✏️  Edit${NC} ${display_path} ${DIM}\"${old_str}...\"${NC}"
                            else
                                echo -e "${GREEN}✏️  Edit${NC} ${display_path}"
                            fi
                            ;;
                        "Bash")
                            desc=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.description // empty' 2>/dev/null | head -c 80)
                            cmd=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.command // empty' 2>/dev/null | head -c 80)
                            if [[ -n "$desc" ]]; then
                                echo -e "${YELLOW}⚡ Bash${NC} ${desc}"
                            else
                                echo -e "${YELLOW}⚡ Bash${NC} ${DIM}${cmd}${NC}"
                            fi
                            ;;
                        "Grep")
                            pattern=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.pattern // empty' 2>/dev/null | head -c 40)
                            path=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.path // empty' 2>/dev/null | head -c 30)
                            echo -e "${DIM}🔍 Grep${NC} \"${pattern}\" ${DIM}${path}${NC}"
                            ;;
                        "Glob")
                            pattern=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.pattern // empty' 2>/dev/null | head -c 50)
                            echo -e "${DIM}🔍 Glob${NC} ${pattern}"
                            ;;
                        "TodoWrite")
                            # Show todo items being written
                            todos=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.todos[]?.content // empty' 2>/dev/null | head -3 | tr '\n' ', ' | head -c 60)
                            if [[ -n "$todos" ]]; then
                                echo -e "${CYAN}📋 Todos${NC} ${DIM}${todos}...${NC}"
                            else
                                echo -e "${CYAN}📋 Todos${NC} updating..."
                            fi
                            ;;
                        "Task")
                            task_desc=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.description // empty' 2>/dev/null | head -c 60)
                            agent_type=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.subagent_type // empty' 2>/dev/null)
                            if [[ -n "$agent_type" ]]; then
                                echo -e "${CYAN}🤖 Agent${NC} [${agent_type}] ${DIM}${task_desc}${NC}"
                            else
                                echo -e "${CYAN}🤖 Agent${NC} ${DIM}${task_desc}${NC}"
                            fi
                            ;;
                        "LSP")
                            op=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.operation // empty' 2>/dev/null)
                            file=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.filePath // empty' 2>/dev/null | xargs basename 2>/dev/null)
                            echo -e "${DIM}🔗 LSP${NC} ${op} ${file}"
                            ;;
                        "WebFetch"|"WebSearch")
                            url=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input.url // .input.query // empty' 2>/dev/null | head -c 60)
                            echo -e "${DIM}🌐 Web${NC} ${url}"
                            ;;
                        *)
                            echo -e "${DIM}🔧 ${tool_name}${NC}"
                            ;;
                    esac
                else
                    # Show assistant text - extract first meaningful line
                    text=$(echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text // empty' 2>/dev/null)
                    if [[ -n "$text" ]]; then
                        # Get first non-empty line, clean it up
                        first_line=$(echo "$text" | grep -v '^$' | head -1 | tr -s ' ' | head -c 100)
                        if [[ -n "$first_line" ]]; then
                            # Color based on content
                            if [[ "$first_line" == *"✓"* ]] || [[ "$first_line" == *"complete"* ]] || [[ "$first_line" == *"Complete"* ]]; then
                                echo -e "${GREEN}▸${NC} ${first_line}"
                            elif [[ "$first_line" == *"Error"* ]] || [[ "$first_line" == *"error"* ]] || [[ "$first_line" == *"fail"* ]]; then
                                echo -e "${RED}▸${NC} ${first_line}"
                            elif [[ "$first_line" == *"TODO"* ]] || [[ "$first_line" == *"FIXME"* ]] || [[ "$first_line" == *"Warning"* ]]; then
                                echo -e "${YELLOW}▸${NC} ${first_line}"
                            else
                                echo -e "${CYAN}▸${NC} ${first_line}"
                            fi
                        fi
                    fi
                fi
                ;;
            "content_block_start")
                # Track when a new content block starts
                block_type=$(echo "$line" | jq -r '.content_block.type // empty' 2>/dev/null)
                if [[ "$block_type" == "tool_use" ]]; then
                    current_tool=$(echo "$line" | jq -r '.content_block.name // empty' 2>/dev/null)
                fi
                ;;
            "content_block_delta")
                # Streaming text/tool input - show progress dots for long operations
                delta_type=$(echo "$line" | jq -r '.delta.type // empty' 2>/dev/null)
                if [[ "$delta_type" == "text_delta" ]]; then
                    # Accumulate text and show periodically
                    delta_text=$(echo "$line" | jq -r '.delta.text // empty' 2>/dev/null)
                    text_buffer+="$delta_text"
                    # Show a dot every ~200 chars to indicate progress
                    if [[ ${#text_buffer} -gt 200 ]]; then
                        echo -n -e "${DIM}.${NC}"
                        text_buffer=""
                    fi
                fi
                ;;
            "content_block_stop")
                # Reset state when block ends
                if [[ -n "$text_buffer" ]]; then
                    echo ""  # Newline after progress dots
                    text_buffer=""
                fi
                current_tool=""
                ;;
            "result")
                if [[ "$subtype" == "success" ]]; then
                    cost=$(echo "$line" | jq -r '.total_cost_usd // empty' 2>/dev/null)
                    turns=$(echo "$line" | jq -r '.num_turns // empty' 2>/dev/null)
                    duration=$(echo "$line" | jq -r '.duration_ms // empty' 2>/dev/null)
                    if [[ -n "$cost" ]]; then
                        if [[ -n "$duration" ]]; then
                            dur_sec=$((duration / 1000))
                            echo -e "${GREEN}✓ Done${NC} ${DIM}(${turns} turns, ${dur_sec}s, \$${cost})${NC}"
                        else
                            echo -e "${GREEN}✓ Done${NC} ${DIM}(${turns} turns, \$${cost})${NC}"
                        fi
                    fi
                elif [[ "$subtype" == "error" ]]; then
                    msg=$(echo "$line" | jq -r '.error // empty' 2>/dev/null | head -c 100)
                    [[ -n "$msg" ]] && echo -e "${RED}✗ Error: ${msg}${NC}"
                fi
                ;;
            "error")
                msg=$(echo "$line" | jq -r '.error.message // .message // empty' 2>/dev/null | head -c 200)
                [[ -n "$msg" ]] && echo -e "${RED}✗ Error: ${msg}${NC}"
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
        echo -e "${DIM}Usage: ./loopclaude.sh plan-work \"description of work scope\"${NC}"
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

if [[ ! -f "$PLAN_FILE" ]]; then
    echo -e "${RED}✗ Error: $PLAN_FILE not found${NC}"
    exit 1
fi

# Header
CURRENT_BRANCH=$(git branch --show-current)
echo ""
echo -e "${BOLD}🚀 Ralph Loop${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Mode:   ${CYAN}$MODE${NC}"
echo -e "Branch: ${GREEN}$CURRENT_BRANCH${NC}"
echo -e "Prompt: ${DIM}$(basename "$PROMPT_FILE")${NC}"
echo -e "Plan:   ${DIM}$(basename "$PLAN_FILE")${NC}"
[[ -n "$WORK_SCOPE" ]] && echo -e "Scope:  ${YELLOW}$WORK_SCOPE${NC}"
[[ "$MAX_ITERATIONS" -gt 0 ]] && echo -e "Max:    ${YELLOW}$MAX_ITERATIONS iterations${NC}"
[[ "$MAX_ITERATIONS" -eq 0 ]] && echo -e "Max:    ${DIM}unlimited${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

iteration=0
while true; do
    iteration=$((iteration + 1))
    remaining=$(count_remaining)
    completed=$(count_completed)
    timestamp=$(date +%Y%m%d-%H%M%S)
    log_file="$LOG_DIR/run-${iteration}-${timestamp}.log"

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

    # Run Claude Code from repo root with stream-json output
    echo -e "${DIM}Running Claude Code from $REPO_ROOT...${NC}"
    pushd "$REPO_ROOT" > /dev/null

    # Stream JSON output, filter for readable display, and save raw to log
    # Note: --verbose is required with --output-format=stream-json in -p mode
    if claude --dangerously-skip-permissions --output-format=stream-json --verbose -p "$prompt_content" 2>&1 | tee "$log_file" | filter_output; then
        echo ""
        echo -e "${GREEN}✓ Claude Code completed${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ Claude Code exited with error, checking if progress was made...${NC}"
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
            msg="loop: iteration $iteration @ $ts"
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
