#!/bin/bash
#
# General-Purpose Evolution Agent Runner
#
# This script invokes an AI agent to analyze and evolve a project based on
# a configurable prompt. Designed to be run via cron for autonomous improvement.
#
# Usage: ./run.sh <project-path> [--dry-run]
#
# Project path can be:
#   - A relative path (e.g., "../my-project", "./project")
#   - An absolute path (e.g., "/home/user/my-project")
#
# The project directory must contain a project-config.json file with:
#   - name: Project name
#   - prompt: The instructions for the agent
#   - Any other project-specific configuration
#

set -e

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$AGENT_DIR/state"
LOG_DIR="$AGENT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure directories exist
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Parse arguments
PROJECT_PATH=""
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            if [[ -z "$PROJECT_PATH" ]]; then
                PROJECT_PATH="$arg"
            fi
            ;;
    esac
done

# Validate project path
if [[ -z "$PROJECT_PATH" ]]; then
    echo "Usage: $0 <project-path> [--dry-run]"
    echo ""
    echo "Project path can be:"
    echo "  - A relative path (e.g., '../my-project', './project')"
    echo "  - An absolute path (e.g., '/home/user/my-project')"
    echo ""
    echo "The project directory must contain a project-config.json file."
    echo ""
    echo "Example:"
    echo "  $0 ../productivity-suite"
    echo "  $0 /home/user/my-app --dry-run"
    exit 1
fi

# Resolve project path to absolute
if [[ "$PROJECT_PATH" == /* ]]; then
    # Already absolute - use as-is
    :
elif [[ -d "$PROJECT_PATH" ]]; then
    # Relative path from current working directory
    PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
else
    echo "ERROR: Project directory not found: $PROJECT_PATH"
    echo ""
    echo "Looked for: $(pwd)/$PROJECT_PATH"
    exit 1
fi

# Verify path exists (for absolute paths)
if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "ERROR: Project directory does not exist: $PROJECT_PATH"
    exit 1
fi

# Validate project config exists
PROJECT_CONFIG="$PROJECT_PATH/project-config.json"
if [[ ! -f "$PROJECT_CONFIG" ]]; then
    echo "ERROR: No project-config.json found in $PROJECT_PATH"
    echo ""
    echo "Create a project-config.json with at minimum:"
    echo '{'
    echo '  "name": "my-project",'
    echo '  "prompt": "Instructions for the agent..."'
    echo '}'
    exit 1
fi

# Extract project name for logging
PROJECT_NAME=$(jq -r '.name // "unnamed"' "$PROJECT_CONFIG")
LOG_FILE="$LOG_DIR/run_${PROJECT_NAME}_${TIMESTAMP}.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting evolution run for project: $PROJECT_NAME"
log "Project path: $PROJECT_PATH"

if [[ "$DRY_RUN" == "true" ]]; then
    log "Running in dry-run mode - no changes will be committed"
fi

# Check for auth expired marker
AUTH_EXPIRED_FILE="$STATE_DIR/auth_expired"
if [[ -f "$AUTH_EXPIRED_FILE" ]]; then
    log "SKIPPED: Authentication token has expired."
    log "Please run 'claude /login' to refresh your token, then remove $AUTH_EXPIRED_FILE"
    exit 0
fi

# Check for rate limit marker
RATE_LIMITED_FILE="$STATE_DIR/rate_limited"
if [[ -f "$RATE_LIMITED_FILE" ]]; then
    RATE_LIMIT_TIME=$(head -1 "$RATE_LIMITED_FILE")
    CURRENT_TIME=$(date +%s)
    RATE_LIMIT_COOLDOWN=3600  # 1 hour

    if [[ $((CURRENT_TIME - RATE_LIMIT_TIME)) -lt $RATE_LIMIT_COOLDOWN ]]; then
        REMAINING=$((RATE_LIMIT_COOLDOWN - (CURRENT_TIME - RATE_LIMIT_TIME)))
        log "SKIPPED: Rate limited. Cooldown remaining: $((REMAINING / 60)) minutes"
        exit 0
    else
        log "Rate limit cooldown expired, removing marker..."
        rm -f "$RATE_LIMITED_FILE"
    fi
fi

# Check minimum time between runs (per-project)
LAST_RUN_FILE="$STATE_DIR/last_run_${PROJECT_NAME}"
if [[ -f "$LAST_RUN_FILE" ]]; then
    LAST_RUN=$(cat "$LAST_RUN_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_RUN))
    MIN_INTERVAL=$(jq -r '.min_interval_seconds // 60' "$PROJECT_CONFIG")

    if [[ $TIME_DIFF -lt $MIN_INTERVAL ]] && [[ "$DRY_RUN" == "false" ]]; then
        log "Skipping run - last run was $TIME_DIFF seconds ago (minimum: $MIN_INTERVAL)"
        exit 0
    fi
fi

# Check for claude command
if ! command -v claude &> /dev/null; then
    log "ERROR: 'claude' command not found. Please install Claude Code CLI."
    exit 1
fi

# Read the prompt from project config
AGENT_PROMPT=$(jq -r '.prompt' "$PROJECT_CONFIG")

if [[ "$AGENT_PROMPT" == "null" ]] || [[ -z "$AGENT_PROMPT" ]]; then
    log "ERROR: No 'prompt' field in project-config.json"
    exit 1
fi

# Check if there's an agent-config.json to include
AGENT_CONFIG="$AGENT_DIR/config/agent-config.json"
if [[ -f "$AGENT_CONFIG" ]]; then
    AGENT_GUIDELINES=$(cat "$AGENT_CONFIG")
    AGENT_PROMPT="$AGENT_PROMPT

AGENT GUIDELINES:
$AGENT_GUIDELINES"
fi

log "Invoking Claude agent..."

# Change to project directory
cd "$PROJECT_PATH"

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN: Would execute claude with project prompt"
    log "Prompt preview (first 500 chars): ${AGENT_PROMPT:0:500}..."
else
    # Save prompt for reference
    echo "$AGENT_PROMPT" > "$STATE_DIR/last_prompt_${PROJECT_NAME}.txt"

    # Run the agent
    AGENT_OUTPUT_FILE=$(mktemp)
    claude --print --dangerously-skip-permissions "$AGENT_PROMPT" 2>&1 | tee -a "$LOG_FILE" "$AGENT_OUTPUT_FILE"

    AGENT_EXIT_CODE=${PIPESTATUS[0]}

    # Check for authentication errors
    if grep -q "authentication_error\|OAuth token has expired\|401.*error" "$AGENT_OUTPUT_FILE"; then
        log "ERROR: Authentication failed - token has expired"
        date > "$AUTH_EXPIRED_FILE"
        echo "Token expired at $(date). Run 'claude /login' to refresh." >> "$AUTH_EXPIRED_FILE"
        rm -f "$AGENT_OUTPUT_FILE"
        exit 1
    fi

    # Check for rate limit errors
    if grep -qi "rate.limit\|usage.limit\|quota\|too many requests\|429\|exceeded.*limit" "$AGENT_OUTPUT_FILE"; then
        log "ERROR: Rate/usage limit reached"
        date +%s > "$RATE_LIMITED_FILE"
        rm -f "$AGENT_OUTPUT_FILE"
        exit 1
    fi
    rm -f "$AGENT_OUTPUT_FILE"

    if [[ $AGENT_EXIT_CODE -ne 0 ]]; then
        log "WARNING: Agent exited with code $AGENT_EXIT_CODE"
    fi

    # Check for changes to commit
    AUTO_COMMIT=$(jq -r '.auto_commit // true' "$PROJECT_CONFIG")
    AUTO_PUSH=$(jq -r '.auto_push // false' "$PROJECT_CONFIG")

    if [[ "$AUTO_COMMIT" == "true" ]] && [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        log "Changes detected, committing..."

        git add -A

        CHANGED_FILES=$(git diff --cached --name-only | head -10)
        COMMIT_MSG="Auto-evolution [$PROJECT_NAME]: $(date '+%Y-%m-%d %H:%M')

Changes:
$CHANGED_FILES

Generated by evolution agent."

        git commit -m "$COMMIT_MSG"
        log "Changes committed successfully"

        if [[ "$AUTO_PUSH" == "true" ]]; then
            git push
            log "Changes pushed to remote"
        fi
    else
        log "No changes detected or auto-commit disabled"
    fi

    # Update last run timestamp
    date +%s > "$LAST_RUN_FILE"
fi

log "Evolution run completed"

# Cleanup old logs (keep last 50 per project)
cd "$LOG_DIR"
ls -t run_${PROJECT_NAME}_*.log 2>/dev/null | tail -n +51 | xargs -r rm --

log "Done"
