#!/bin/bash
#
# Productivity Suite Evolution Runner
#
# This script invokes an AI agent to analyze and evolve the productivity suite.
# Designed to be run via cron for autonomous improvement.
#
# Usage: ./run.sh [--dry-run]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/run_$TIMESTAMP.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check for dry-run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    log "Running in dry-run mode - no changes will be committed"
fi

# Check for auth expired marker - prevents spamming API when token has expired
AUTH_EXPIRED_FILE="$SCRIPT_DIR/.agent/auth_expired"
if [[ -f "$AUTH_EXPIRED_FILE" ]]; then
    log "SKIPPED: Authentication token has expired."
    log "Please run 'claude /login' to refresh your token, then remove $AUTH_EXPIRED_FILE"
    exit 0
fi

# Check for rate limit marker - prevents spamming API when usage limit reached
RATE_LIMITED_FILE="$SCRIPT_DIR/.agent/rate_limited"
if [[ -f "$RATE_LIMITED_FILE" ]]; then
    # Check if enough time has passed (default: 1 hour)
    RATE_LIMIT_TIME=$(cat "$RATE_LIMITED_FILE" | head -1)
    CURRENT_TIME=$(date +%s)
    RATE_LIMIT_COOLDOWN=3600  # 1 hour in seconds

    if [[ $((CURRENT_TIME - RATE_LIMIT_TIME)) -lt $RATE_LIMIT_COOLDOWN ]]; then
        REMAINING=$((RATE_LIMIT_COOLDOWN - (CURRENT_TIME - RATE_LIMIT_TIME)))
        log "SKIPPED: Rate limited. Cooldown remaining: $((REMAINING / 60)) minutes"
        log "To retry immediately, remove $RATE_LIMITED_FILE"
        exit 0
    else
        log "Rate limit cooldown expired, removing marker and retrying..."
        rm -f "$RATE_LIMITED_FILE"
    fi
fi

log "Starting productivity suite evolution run"
log "Working directory: $SCRIPT_DIR"

# Check if claude command is available
if ! command -v claude &> /dev/null; then
    log "ERROR: 'claude' command not found. Please install Claude Code CLI."
    log "Visit: https://claude.ai/claude-code for installation instructions"
    exit 1
fi

# Read the last run timestamp to enforce minimum time between runs
LAST_RUN_FILE="$SCRIPT_DIR/.agent/last_run"
if [[ -f "$LAST_RUN_FILE" ]]; then
    LAST_RUN=$(cat "$LAST_RUN_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_RUN))
    MIN_INTERVAL=60  # 1 minute in seconds

    if [[ $TIME_DIFF -lt $MIN_INTERVAL ]] && [[ "$DRY_RUN" == "false" ]]; then
        log "Skipping run - last run was $(($TIME_DIFF / 60)) minutes ago (minimum: 9 minutes)"
        exit 0
    fi
fi

# Create the agent prompt
AGENT_PROMPT=$(cat <<'PROMPT_END'
You are managing an autonomous productivity suite that evolves over time. Your task is to analyze the current state and make meaningful improvements.

INSTRUCTIONS:
1. First, read the manifest.json to understand what tools exist
2. Read the config/agent-config.json for guidelines
3. Explore any existing tools in the tools/ directory
4. Decide on ONE of these actions:
   a) Create a new productivity tool if the suite is lacking
   b) Improve an existing tool if you find issues or missing features
   c) Fix bugs if any tools have problems

REQUIREMENTS:
- Make only ONE meaningful change per run (create one tool OR improve one tool)
- Each tool should be in its own subdirectory under tools/
- Include a README.md in each tool directory
- Tools should be practical and solve real productivity problems
- Update manifest.json to reflect any changes
- Write clean, well-documented code

TOOL IDEAS (if creating new):
- Pomodoro timer for focus sessions
- Quick note capture system
- Daily task tracker
- File organization helper
- Clipboard history manager
- Meeting notes template generator
- Time logging utility
- Habit tracker
- Bookmark manager
- Project scaffolder

After making changes, provide a brief summary of what you did.

DO NOT push to git. Changes will be committed automatically after your run.
PROMPT_END
)

log "Invoking Claude agent for analysis and improvements..."

# Run claude with the prompt
# Using --print to get output, running non-interactively
cd "$SCRIPT_DIR"

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN: Would execute claude with evolution prompt"
    log "Prompt summary: Analyze suite and make one improvement"
else
    # Save prompt to temp file for reference
    echo "$AGENT_PROMPT" > "$SCRIPT_DIR/.agent/last_prompt.txt"

    # Run the agent
    # The --print flag outputs to stdout, --dangerously-skip-permissions allows autonomous operation
    # Capture output to check for auth errors
    AGENT_OUTPUT_FILE=$(mktemp)
    claude --print --dangerously-skip-permissions "$AGENT_PROMPT" 2>&1 | tee -a "$LOG_FILE" "$AGENT_OUTPUT_FILE"

    AGENT_EXIT_CODE=${PIPESTATUS[0]}

    # Check for authentication errors to prevent future API spam
    if grep -q "authentication_error\|OAuth token has expired\|401.*error" "$AGENT_OUTPUT_FILE"; then
        log "ERROR: Authentication failed - token has expired"
        log "Creating auth_expired marker to prevent further API calls"
        date > "$AUTH_EXPIRED_FILE"
        echo "Token expired at $(date). Run 'claude /login' to refresh." >> "$AUTH_EXPIRED_FILE"
        rm -f "$AGENT_OUTPUT_FILE"
        exit 1
    fi

    # Check for rate limit / usage quota errors
    if grep -qi "rate.limit\|usage.limit\|quota\|too many requests\|429\|exceeded.*limit\|out of.*tokens\|capacity" "$AGENT_OUTPUT_FILE"; then
        log "ERROR: Rate/usage limit reached"
        log "Creating rate_limited marker - will auto-retry in 1 hour"
        date +%s > "$RATE_LIMITED_FILE"
        echo "Rate limited at $(date). Will auto-retry after cooldown." >> "$RATE_LIMITED_FILE"
        rm -f "$AGENT_OUTPUT_FILE"
        exit 1
    fi
    rm -f "$AGENT_OUTPUT_FILE"

    if [[ $AGENT_EXIT_CODE -ne 0 ]]; then
        log "WARNING: Agent exited with code $AGENT_EXIT_CODE"
    fi

    # Check if there are changes to commit
    if [[ -n $(git status --porcelain) ]]; then
        log "Changes detected, committing..."

        git add -A

        # Generate commit message based on changes
        CHANGED_FILES=$(git diff --cached --name-only | head -10)
        COMMIT_MSG="Auto-evolution: $(date '+%Y-%m-%d %H:%M')

Changes:
$CHANGED_FILES

Generated by productivity suite runner."

        git commit -m "$COMMIT_MSG"
        log "Changes committed successfully"

        git push
        log "Changes pushed to remote"
    else
        log "No changes detected in this run"
    fi

    # Update last run timestamp
    date +%s > "$LAST_RUN_FILE"
fi

log "Evolution run completed"

# Cleanup old logs (keep last 50)
cd "$LOG_DIR"
ls -t run_*.log 2>/dev/null | tail -n +51 | xargs -r rm --

log "Done"
