#!/bin/bash
#
# Tasks - Simple command-line task tracker
#
# Usage:
#   tasks.sh add "Task description"
#   tasks.sh list                    - Show all pending tasks
#   tasks.sh done <id>               - Mark task as complete
#   tasks.sh remove <id>             - Remove a task
#   tasks.sh clear                   - Remove all completed tasks
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TASKS_FILE="$DATA_DIR/tasks.json"

mkdir -p "$DATA_DIR"

# Initialize tasks file if it doesn't exist
if [[ ! -f "$TASKS_FILE" ]]; then
    echo '{"tasks":[],"next_id":1}' > "$TASKS_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

add_task() {
    local description="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    if [[ -z "$description" ]]; then
        echo "Usage: tasks.sh add \"Task description\""
        exit 1
    fi

    local next_id=$(jq -r '.next_id' "$TASKS_FILE")

    jq --arg desc "$description" --arg ts "$timestamp" --argjson id "$next_id" '
        .tasks += [{
            "id": $id,
            "description": $desc,
            "created": $ts,
            "completed": false,
            "completed_at": null
        }] |
        .next_id = ($id + 1)
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    echo -e "${GREEN}Task #$next_id added:${NC} $description"
}

list_tasks() {
    local show_all=${1:-false}

    echo -e "${BLUE}=== Tasks ===${NC}"
    echo ""

    local pending=$(jq -r '.tasks | map(select(.completed == false)) | length' "$TASKS_FILE")
    local completed=$(jq -r '.tasks | map(select(.completed == true)) | length' "$TASKS_FILE")

    if [[ "$pending" -eq 0 ]] && [[ "$completed" -eq 0 ]]; then
        echo "No tasks. Add one with: tasks.sh add \"Your task\""
        exit 0
    fi

    # Show pending tasks
    if [[ "$pending" -gt 0 ]]; then
        echo -e "${YELLOW}Pending ($pending):${NC}"
        jq -r '.tasks | map(select(.completed == false)) | .[] | "  [\(.id)] \(.description)"' "$TASKS_FILE" | while read line; do
            echo -e "  ${NC}$line"
        done
        echo ""
    fi

    # Show completed tasks
    if [[ "$completed" -gt 0 ]]; then
        echo -e "${GREEN}Completed ($completed):${NC}"
        jq -r '.tasks | map(select(.completed == true)) | .[] | "  [\(.id)] \(.description)"' "$TASKS_FILE" | while read line; do
            echo -e "  ${GRAY}$line${NC}"
        done
    fi
}

complete_task() {
    local id=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    if [[ -z "$id" ]]; then
        echo "Usage: tasks.sh done <id>"
        exit 1
    fi

    # Check if task exists
    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    local already_done=$(jq --argjson id "$id" '.tasks | map(select(.id == $id and .completed == true)) | length' "$TASKS_FILE")

    if [[ "$already_done" -gt 0 ]]; then
        echo -e "${YELLOW}Task #$id is already completed${NC}"
        exit 0
    fi

    jq --argjson id "$id" --arg ts "$timestamp" '
        .tasks = [.tasks[] | if .id == $id then .completed = true | .completed_at = $ts else . end]
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")
    echo -e "${GREEN}Completed:${NC} $desc"
}

remove_task() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: tasks.sh remove <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")

    jq --argjson id "$id" '.tasks = [.tasks[] | select(.id != $id)]' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    echo -e "${RED}Removed:${NC} $desc"
}

clear_completed() {
    local count=$(jq '.tasks | map(select(.completed == true)) | length' "$TASKS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No completed tasks to clear."
        exit 0
    fi

    jq '.tasks = [.tasks[] | select(.completed == false)]' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    echo -e "${GREEN}Cleared $count completed task(s)${NC}"
}

show_help() {
    echo "Tasks - Simple command-line task tracker"
    echo ""
    echo "Usage:"
    echo "  tasks.sh add \"description\"  Add a new task"
    echo "  tasks.sh list               Show all tasks"
    echo "  tasks.sh done <id>          Mark task as complete"
    echo "  tasks.sh remove <id>        Remove a task"
    echo "  tasks.sh clear              Remove completed tasks"
    echo "  tasks.sh help               Show this help"
}

case "$1" in
    add)
        shift
        add_task "$@"
        ;;
    list|ls)
        list_tasks
        ;;
    done|complete)
        complete_task "$2"
        ;;
    remove|rm|delete)
        remove_task "$2"
        ;;
    clear)
        clear_completed
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_tasks
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'tasks.sh help' for usage"
        exit 1
        ;;
esac
