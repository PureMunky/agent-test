#!/bin/bash
#
# Context Switcher - Manage and switch between project contexts
#
# Usage:
#   context.sh create "project" [directory]  - Create a new context
#   context.sh switch "project"              - Switch to a context
#   context.sh current                       - Show current context
#   context.sh list                          - List all contexts
#   context.sh note "text"                   - Add note to current context
#   context.sh notes                         - Show notes for current context
#   context.sh env "KEY=value"               - Add env var to current context
#   context.sh status                        - Show context summary with recent activity
#   context.sh archive "project"             - Archive a context
#   context.sh remove "project"              - Remove a context
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CONTEXTS_FILE="$DATA_DIR/contexts.json"
CURRENT_FILE="$DATA_DIR/current.txt"
HISTORY_FILE="$DATA_DIR/history.log"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize contexts file if it doesn't exist
if [[ ! -f "$CONTEXTS_FILE" ]]; then
    echo '{"contexts":{}}' > "$CONTEXTS_FILE"
fi

touch "$HISTORY_FILE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

get_current() {
    if [[ -f "$CURRENT_FILE" ]]; then
        cat "$CURRENT_FILE"
    else
        echo ""
    fi
}

log_activity() {
    local action="$1"
    local context="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$action|$context" >> "$HISTORY_FILE"
}

create_context() {
    local name="$1"
    local directory="${2:-$(pwd)}"

    if [[ -z "$name" ]]; then
        echo "Usage: context.sh create \"project-name\" [directory]"
        exit 1
    fi

    # Normalize name (lowercase, replace spaces with dashes)
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Check if context already exists
    local exists=$(jq -r --arg name "$name" '.contexts | has($name)' "$CONTEXTS_FILE")

    if [[ "$exists" == "true" ]]; then
        echo -e "${YELLOW}Context '$name' already exists.${NC}"
        echo "Use 'context.sh switch $name' to switch to it."
        exit 1
    fi

    # Resolve directory to absolute path
    if [[ ! "$directory" = /* ]]; then
        directory="$(cd "$directory" 2>/dev/null && pwd)" || directory="$(pwd)"
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --arg name "$name" --arg dir "$directory" --arg ts "$timestamp" '
        .contexts[$name] = {
            "name": $name,
            "directory": $dir,
            "created": $ts,
            "last_accessed": $ts,
            "notes": [],
            "env_vars": {},
            "archived": false,
            "total_time_minutes": 0
        }
    ' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    echo -e "${GREEN}Created context:${NC} $name"
    echo -e "${CYAN}Directory:${NC} $directory"

    log_activity "create" "$name"

    # Ask to switch to it
    read -p "Switch to this context now? (Y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        switch_context "$name"
    fi
}

switch_context() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: context.sh switch \"project-name\""
        exit 1
    fi

    # Normalize name
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Check if context exists
    local exists=$(jq -r --arg name "$name" '.contexts | has($name)' "$CONTEXTS_FILE")

    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Context '$name' not found.${NC}"
        echo ""
        echo "Available contexts:"
        list_contexts
        exit 1
    fi

    # Check if archived
    local archived=$(jq -r --arg name "$name" '.contexts[$name].archived' "$CONTEXTS_FILE")
    if [[ "$archived" == "true" ]]; then
        echo -e "${YELLOW}Context '$name' is archived.${NC}"
        read -p "Unarchive and switch to it? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            jq --arg name "$name" '.contexts[$name].archived = false' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"
        else
            exit 0
        fi
    fi

    # Save current context's session time if switching from another
    local current=$(get_current)
    if [[ -n "$current" ]] && [[ "$current" != "$name" ]]; then
        # Could track time here if we had session start time
        true
    fi

    # Update last_accessed
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    jq --arg name "$name" --arg ts "$timestamp" '
        .contexts[$name].last_accessed = $ts
    ' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    # Save current context
    echo "$name" > "$CURRENT_FILE"

    log_activity "switch" "$name"

    # Get context info
    local directory=$(jq -r --arg name "$name" '.contexts[$name].directory' "$CONTEXTS_FILE")
    local note_count=$(jq -r --arg name "$name" '.contexts[$name].notes | length' "$CONTEXTS_FILE")

    echo -e "${GREEN}Switched to:${NC} $name"
    echo -e "${CYAN}Directory:${NC} $directory"

    if [[ $note_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Recent notes:${NC}"
        jq -r --arg name "$name" '.contexts[$name].notes[-3:][] | "  - \(.text)"' "$CONTEXTS_FILE" 2>/dev/null
    fi

    # Show any env vars
    local env_count=$(jq -r --arg name "$name" '.contexts[$name].env_vars | length' "$CONTEXTS_FILE")
    if [[ $env_count -gt 0 ]]; then
        echo ""
        echo -e "${MAGENTA}Environment variables:${NC}"
        jq -r --arg name "$name" '.contexts[$name].env_vars | to_entries[] | "  export \(.key)=\"\(.value)\""' "$CONTEXTS_FILE"
        echo ""
        echo -e "${GRAY}(Copy and run the above to set environment)${NC}"
    fi

    echo ""
    echo -e "${GRAY}To change directory: cd $directory${NC}"
}

show_current() {
    local current=$(get_current)

    if [[ -z "$current" ]]; then
        echo -e "${GRAY}No active context.${NC}"
        echo "Switch to one with: context.sh switch \"project\""
        exit 0
    fi

    local info=$(jq -r --arg name "$current" '.contexts[$name]' "$CONTEXTS_FILE")

    echo -e "${BLUE}=== Current Context ===${NC}"
    echo ""
    echo -e "${GREEN}Name:${NC} $current"
    echo -e "${CYAN}Directory:${NC} $(echo "$info" | jq -r '.directory')"
    echo -e "${CYAN}Created:${NC} $(echo "$info" | jq -r '.created')"
    echo -e "${CYAN}Last accessed:${NC} $(echo "$info" | jq -r '.last_accessed')"

    local note_count=$(echo "$info" | jq -r '.notes | length')
    if [[ $note_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Notes ($note_count):${NC}"
        echo "$info" | jq -r '.notes[-5:][] | "  [\(.timestamp | split(" ")[1])] \(.text)"'
    fi

    local env_count=$(echo "$info" | jq -r '.env_vars | length')
    if [[ $env_count -gt 0 ]]; then
        echo ""
        echo -e "${MAGENTA}Environment ($env_count vars):${NC}"
        echo "$info" | jq -r '.env_vars | keys[] | "  \(.)"'
    fi
}

list_contexts() {
    local contexts=$(jq -r '.contexts | keys[]' "$CONTEXTS_FILE" 2>/dev/null)

    if [[ -z "$contexts" ]]; then
        echo "No contexts created yet."
        echo "Create one with: context.sh create \"project-name\" [directory]"
        exit 0
    fi

    local current=$(get_current)

    echo -e "${BLUE}=== Contexts ===${NC}"
    echo ""

    local active_count=0
    local archived_count=0

    # Show active contexts
    while IFS= read -r name; do
        local archived=$(jq -r --arg name "$name" '.contexts[$name].archived' "$CONTEXTS_FILE")

        if [[ "$archived" == "true" ]]; then
            archived_count=$((archived_count + 1))
            continue
        fi

        active_count=$((active_count + 1))
        local directory=$(jq -r --arg name "$name" '.contexts[$name].directory' "$CONTEXTS_FILE")
        local last=$(jq -r --arg name "$name" '.contexts[$name].last_accessed' "$CONTEXTS_FILE")
        local last_date="${last%% *}"

        if [[ "$name" == "$current" ]]; then
            echo -e "  ${GREEN}* $name${NC} ${GRAY}($directory)${NC}"
        else
            echo -e "  ${NC}  $name${NC} ${GRAY}($directory)${NC}"
        fi
    done <<< "$contexts"

    echo ""
    echo -e "${CYAN}Active:${NC} $active_count"

    if [[ $archived_count -gt 0 ]]; then
        echo -e "${GRAY}Archived:${NC} $archived_count (use 'context.sh list --all' to see)"
    fi
}

list_all_contexts() {
    local contexts=$(jq -r '.contexts | keys[]' "$CONTEXTS_FILE" 2>/dev/null)
    local current=$(get_current)

    echo -e "${BLUE}=== All Contexts ===${NC}"
    echo ""

    while IFS= read -r name; do
        local archived=$(jq -r --arg name "$name" '.contexts[$name].archived' "$CONTEXTS_FILE")
        local directory=$(jq -r --arg name "$name" '.contexts[$name].directory' "$CONTEXTS_FILE")

        if [[ "$name" == "$current" ]]; then
            echo -e "  ${GREEN}* $name${NC} ${GRAY}($directory)${NC}"
        elif [[ "$archived" == "true" ]]; then
            echo -e "  ${GRAY}  $name (archived)${NC}"
        else
            echo -e "  ${NC}  $name${NC} ${GRAY}($directory)${NC}"
        fi
    done <<< "$contexts"
}

add_note() {
    local text="$*"
    local current=$(get_current)

    if [[ -z "$current" ]]; then
        echo -e "${YELLOW}No active context. Switch to one first.${NC}"
        exit 1
    fi

    if [[ -z "$text" ]]; then
        echo "Usage: context.sh note \"your note here\""
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --arg name "$current" --arg text "$text" --arg ts "$timestamp" '
        .contexts[$name].notes += [{
            "text": $text,
            "timestamp": $ts
        }]
    ' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    echo -e "${GREEN}Note added to $current:${NC} $text"
}

show_notes() {
    local context="${1:-$(get_current)}"

    if [[ -z "$context" ]]; then
        echo -e "${YELLOW}No active context. Specify one or switch first.${NC}"
        exit 1
    fi

    local exists=$(jq -r --arg name "$context" '.contexts | has($name)' "$CONTEXTS_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Context '$context' not found.${NC}"
        exit 1
    fi

    local notes=$(jq -r --arg name "$context" '.contexts[$name].notes' "$CONTEXTS_FILE")
    local count=$(echo "$notes" | jq 'length')

    echo -e "${BLUE}=== Notes: $context ===${NC}"
    echo ""

    if [[ $count -eq 0 ]]; then
        echo "No notes yet. Add one with: context.sh note \"your note\""
        exit 0
    fi

    echo "$notes" | jq -r '.[] | "[\(.timestamp)] \(.text)"' | while IFS= read -r line; do
        echo -e "  ${CYAN}${line%%]*}]${NC}${line#*]}"
    done
}

add_env() {
    local pair="$1"
    local current=$(get_current)

    if [[ -z "$current" ]]; then
        echo -e "${YELLOW}No active context. Switch to one first.${NC}"
        exit 1
    fi

    if [[ -z "$pair" ]] || [[ ! "$pair" =~ = ]]; then
        echo "Usage: context.sh env \"KEY=value\""
        exit 1
    fi

    local key="${pair%%=*}"
    local value="${pair#*=}"

    jq --arg name "$current" --arg key "$key" --arg val "$value" '
        .contexts[$name].env_vars[$key] = $val
    ' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    echo -e "${GREEN}Added to $current:${NC} $key=$value"
    echo -e "${GRAY}Run: export $key=\"$value\"${NC}"
}

show_status() {
    local current=$(get_current)

    echo -e "${BLUE}=== Context Status ===${NC}"
    echo ""

    if [[ -z "$current" ]]; then
        echo -e "${GRAY}Current:${NC} (none)"
    else
        echo -e "${GREEN}Current:${NC} $current"
    fi

    echo ""

    # Recent switches
    echo -e "${YELLOW}Recent Activity:${NC}"
    if [[ -s "$HISTORY_FILE" ]]; then
        tail -5 "$HISTORY_FILE" | while IFS='|' read -r ts action ctx; do
            local time="${ts#* }"
            echo -e "  ${GRAY}[$time]${NC} $action → $ctx"
        done
    else
        echo "  No activity yet"
    fi

    echo ""

    # Context stats
    local total=$(jq -r '.contexts | length' "$CONTEXTS_FILE")
    local active=$(jq -r '[.contexts[] | select(.archived == false)] | length' "$CONTEXTS_FILE")

    echo -e "${CYAN}Total contexts:${NC} $total ($active active)"

    # Most used today
    local today_switches=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | grep "|switch|" | wc -l)
    echo -e "${CYAN}Switches today:${NC} $today_switches"
}

archive_context() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: context.sh archive \"project-name\""
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    local exists=$(jq -r --arg name "$name" '.contexts | has($name)' "$CONTEXTS_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Context '$name' not found.${NC}"
        exit 1
    fi

    jq --arg name "$name" '.contexts[$name].archived = true' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    # If this was the current context, clear it
    local current=$(get_current)
    if [[ "$current" == "$name" ]]; then
        rm -f "$CURRENT_FILE"
    fi

    echo -e "${YELLOW}Archived:${NC} $name"
    log_activity "archive" "$name"
}

remove_context() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: context.sh remove \"project-name\""
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    local exists=$(jq -r --arg name "$name" '.contexts | has($name)' "$CONTEXTS_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Context '$name' not found.${NC}"
        exit 1
    fi

    # Confirm deletion
    local note_count=$(jq -r --arg name "$name" '.contexts[$name].notes | length' "$CONTEXTS_FILE")
    echo -e "${YELLOW}This will permanently delete context '$name' with $note_count notes.${NC}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    jq --arg name "$name" 'del(.contexts[$name])' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"

    # If this was the current context, clear it
    local current=$(get_current)
    if [[ "$current" == "$name" ]]; then
        rm -f "$CURRENT_FILE"
    fi

    echo -e "${RED}Removed:${NC} $name"
    log_activity "remove" "$name"
}

show_help() {
    echo "Context Switcher - Manage and switch between project contexts"
    echo ""
    echo "Usage:"
    echo "  context.sh create \"name\" [dir]  Create a new context"
    echo "  context.sh switch \"name\"        Switch to a context"
    echo "  context.sh current               Show current context"
    echo "  context.sh list                  List all active contexts"
    echo "  context.sh list --all            List all contexts including archived"
    echo "  context.sh note \"text\"           Add note to current context"
    echo "  context.sh notes [name]          Show notes for a context"
    echo "  context.sh env \"KEY=value\"       Add env var to current context"
    echo "  context.sh status                Show activity summary"
    echo "  context.sh archive \"name\"        Archive a context"
    echo "  context.sh remove \"name\"         Permanently remove a context"
    echo "  context.sh help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  context.sh create \"webapp\" ~/projects/webapp"
    echo "  context.sh switch webapp"
    echo "  context.sh note \"Need to fix the auth bug\""
    echo "  context.sh env \"API_KEY=abc123\""
    echo ""
    echo "Tips:"
    echo "  - Use notes to remember where you left off"
    echo "  - Store project-specific env vars for quick setup"
    echo "  - Archive old projects instead of deleting them"
}

case "$1" in
    create|new|add)
        shift
        create_context "$@"
        ;;
    switch|sw|use)
        switch_context "$2"
        ;;
    current|now)
        show_current
        ;;
    list|ls)
        if [[ "$2" == "--all" ]] || [[ "$2" == "-a" ]]; then
            list_all_contexts
        else
            list_contexts
        fi
        ;;
    note|n)
        shift
        add_note "$@"
        ;;
    notes)
        show_notes "$2"
        ;;
    env|var)
        add_env "$2"
        ;;
    status|stat)
        show_status
        ;;
    archive)
        archive_context "$2"
        ;;
    remove|rm|delete)
        remove_context "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_current
        ;;
    *)
        # Try to interpret as a context name to switch to
        local exists=$(jq -r --arg name "$1" '.contexts | has($name)' "$CONTEXTS_FILE" 2>/dev/null)
        if [[ "$exists" == "true" ]]; then
            switch_context "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'context.sh help' for usage"
            exit 1
        fi
        ;;
esac
