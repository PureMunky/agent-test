#!/bin/bash
#
# Tasks - Simple command-line task tracker with priority and due dates
#
# Usage:
#   tasks.sh add "Task description" [-p high|med|low] [-d YYYY-MM-DD]
#   tasks.sh list [--all|--overdue|--today|--priority]
#   tasks.sh done <id>               - Mark task as complete
#   tasks.sh edit <id> "new desc"    - Edit task description
#   tasks.sh priority <id> <level>   - Set priority (high/med/low)
#   tasks.sh due <id> <date>         - Set due date
#   tasks.sh remove <id>             - Remove a task
#   tasks.sh clear                   - Remove all completed tasks
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TASKS_FILE="$DATA_DIR/tasks.json"
TODAY=$(date +%Y-%m-%d)

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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Priority display helpers
priority_color() {
    case "$1" in
        high) echo -e "${RED}!!${NC}" ;;
        med)  echo -e "${YELLOW}!${NC} " ;;
        low)  echo -e "${GRAY}-${NC} " ;;
        *)    echo "  " ;;
    esac
}

priority_sort_value() {
    case "$1" in
        high) echo 1 ;;
        med)  echo 2 ;;
        low)  echo 3 ;;
        *)    echo 4 ;;
    esac
}

format_due_date() {
    local due="$1"
    if [[ -z "$due" ]] || [[ "$due" == "null" ]]; then
        echo ""
        return
    fi

    local due_epoch=$(date -d "$due" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$due" +%s 2>/dev/null)
    local today_epoch=$(date -d "$TODAY" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null)
    local diff=$(( (due_epoch - today_epoch) / 86400 ))

    if [[ $diff -lt 0 ]]; then
        echo -e "${RED}[OVERDUE: $due]${NC}"
    elif [[ $diff -eq 0 ]]; then
        echo -e "${YELLOW}[TODAY]${NC}"
    elif [[ $diff -eq 1 ]]; then
        echo -e "${CYAN}[Tomorrow]${NC}"
    elif [[ $diff -le 7 ]]; then
        local day_name=$(date -d "$due" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$due" +%a 2>/dev/null)
        echo -e "${CYAN}[$day_name]${NC}"
    else
        echo -e "${GRAY}[$due]${NC}"
    fi
}

add_task() {
    local description=""
    local priority=""
    local due_date=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--priority)
                priority="$2"
                shift 2
                ;;
            -d|--due)
                due_date="$2"
                shift 2
                ;;
            *)
                if [[ -z "$description" ]]; then
                    description="$1"
                else
                    description="$description $1"
                fi
                shift
                ;;
        esac
    done

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    if [[ -z "$description" ]]; then
        echo "Usage: tasks.sh add \"Task description\" [-p high|med|low] [-d YYYY-MM-DD]"
        exit 1
    fi

    # Validate priority if provided
    if [[ -n "$priority" ]] && [[ ! "$priority" =~ ^(high|med|low)$ ]]; then
        echo -e "${RED}Invalid priority: $priority. Use high, med, or low.${NC}"
        exit 1
    fi

    # Validate due date if provided
    if [[ -n "$due_date" ]]; then
        if ! date -d "$due_date" &>/dev/null 2>&1 && ! date -j -f "%Y-%m-%d" "$due_date" &>/dev/null 2>&1; then
            echo -e "${RED}Invalid date format: $due_date. Use YYYY-MM-DD.${NC}"
            exit 1
        fi
    fi

    local next_id=$(jq -r '.next_id' "$TASKS_FILE")

    # Build JSON for new task
    local priority_json="null"
    local due_json="null"
    [[ -n "$priority" ]] && priority_json="\"$priority\""
    [[ -n "$due_date" ]] && due_json="\"$due_date\""

    jq --arg desc "$description" --arg ts "$timestamp" --argjson id "$next_id" \
       --argjson priority "$priority_json" --argjson due "$due_json" '
        .tasks += [{
            "id": $id,
            "description": $desc,
            "created": $ts,
            "completed": false,
            "completed_at": null,
            "priority": $priority,
            "due": $due
        }] |
        .next_id = ($id + 1)
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    echo -e "${GREEN}Task #$next_id added:${NC} $description"
    [[ -n "$priority" ]] && echo -e "  Priority: $(priority_color $priority)$priority"
    [[ -n "$due_date" ]] && echo -e "  Due: $(format_due_date $due_date)"
}

list_tasks() {
    local filter="${1:-}"
    local sort_by_priority=false

    # Parse filter options
    case "$filter" in
        --all|-a)
            filter="all"
            ;;
        --overdue|-o)
            filter="overdue"
            ;;
        --today|-t)
            filter="today"
            ;;
        --priority|-p)
            sort_by_priority=true
            filter=""
            ;;
        --high)
            filter="high"
            ;;
        --*)
            echo "Unknown filter: $filter"
            echo "Available: --all, --overdue, --today, --priority, --high"
            exit 1
            ;;
    esac

    echo -e "${BLUE}=== Tasks ===${NC}"
    echo ""

    local pending=$(jq -r '.tasks | map(select(.completed == false)) | length' "$TASKS_FILE")
    local completed=$(jq -r '.tasks | map(select(.completed == true)) | length' "$TASKS_FILE")

    if [[ "$pending" -eq 0 ]] && [[ "$completed" -eq 0 ]]; then
        echo "No tasks. Add one with: tasks.sh add \"Your task\""
        exit 0
    fi

    # Count overdue tasks
    local overdue_count=$(jq -r --arg today "$TODAY" '
        .tasks | map(select(.completed == false and .due != null and .due < $today)) | length
    ' "$TASKS_FILE")

    # Count today's tasks
    local today_count=$(jq -r --arg today "$TODAY" '
        .tasks | map(select(.completed == false and .due == $today)) | length
    ' "$TASKS_FILE")

    # Show warnings
    if [[ "$overdue_count" -gt 0 ]]; then
        echo -e "${RED}⚠ $overdue_count overdue task(s)${NC}"
    fi
    if [[ "$today_count" -gt 0 ]]; then
        echo -e "${YELLOW}📅 $today_count task(s) due today${NC}"
    fi
    [[ "$overdue_count" -gt 0 ]] || [[ "$today_count" -gt 0 ]] && echo ""

    # Show pending tasks
    if [[ "$pending" -gt 0 ]]; then
        echo -e "${YELLOW}Pending ($pending):${NC}"

        # Build jq filter based on options
        local jq_filter='.tasks | map(select(.completed == false))'

        case "$filter" in
            overdue)
                jq_filter=".tasks | map(select(.completed == false and .due != null and .due < \"$TODAY\"))"
                ;;
            today)
                jq_filter=".tasks | map(select(.completed == false and .due == \"$TODAY\"))"
                ;;
            high)
                jq_filter='.tasks | map(select(.completed == false and .priority == "high"))'
                ;;
        esac

        # Sort by priority if requested
        if [[ "$sort_by_priority" == "true" ]]; then
            jq_filter="$jq_filter | sort_by(if .priority == \"high\" then 0 elif .priority == \"med\" then 1 elif .priority == \"low\" then 2 else 3 end)"
        fi

        jq -r "$jq_filter"' | .[] | "\(.id)|\(.priority // "")|\(.due // "")|\(.description)"' "$TASKS_FILE" | while IFS='|' read -r id priority due desc; do
            local pri_display=$(priority_color "$priority")
            local due_display=$(format_due_date "$due")
            echo -e "  ${pri_display}[${id}] ${desc} ${due_display}"
        done
        echo ""
    fi

    # Show completed tasks (unless filtering)
    if [[ "$completed" -gt 0 ]] && [[ "$filter" != "overdue" ]] && [[ "$filter" != "today" ]] && [[ "$filter" != "high" ]]; then
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
    echo -e "${GREEN}✓ Completed:${NC} $desc"
}

edit_task() {
    local id=$1
    shift
    local new_desc="$*"

    if [[ -z "$id" ]] || [[ -z "$new_desc" ]]; then
        echo "Usage: tasks.sh edit <id> \"new description\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg desc "$new_desc" '
        .tasks = [.tasks[] | if .id == $id then .description = $desc else . end]
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    echo -e "${GREEN}Updated task #$id:${NC} $new_desc"
}

set_priority() {
    local id=$1
    local priority=$2

    if [[ -z "$id" ]] || [[ -z "$priority" ]]; then
        echo "Usage: tasks.sh priority <id> <high|med|low>"
        exit 1
    fi

    if [[ ! "$priority" =~ ^(high|med|low)$ ]]; then
        echo -e "${RED}Invalid priority: $priority. Use high, med, or low.${NC}"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg priority "$priority" '
        .tasks = [.tasks[] | if .id == $id then .priority = $priority else . end]
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")
    echo -e "${GREEN}Set priority for #$id:${NC} $desc"
    echo -e "  Priority: $(priority_color $priority)$priority"
}

set_due_date() {
    local id=$1
    local due_date=$2

    if [[ -z "$id" ]]; then
        echo "Usage: tasks.sh due <id> <YYYY-MM-DD|clear>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    if [[ "$due_date" == "clear" ]] || [[ -z "$due_date" ]]; then
        jq --argjson id "$id" '
            .tasks = [.tasks[] | if .id == $id then .due = null else . end]
        ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

        local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")
        echo -e "${GREEN}Cleared due date for #$id:${NC} $desc"
    else
        # Validate date
        if ! date -d "$due_date" &>/dev/null 2>&1 && ! date -j -f "%Y-%m-%d" "$due_date" &>/dev/null 2>&1; then
            echo -e "${RED}Invalid date format: $due_date. Use YYYY-MM-DD.${NC}"
            exit 1
        fi

        jq --argjson id "$id" --arg due "$due_date" '
            .tasks = [.tasks[] | if .id == $id then .due = $due else . end]
        ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

        local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")
        echo -e "${GREEN}Set due date for #$id:${NC} $desc"
        echo -e "  Due: $(format_due_date $due_date)"
    fi
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

undone_task() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: tasks.sh undone <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length' "$TASKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Task #$id not found${NC}"
        exit 1
    fi

    local is_done=$(jq --argjson id "$id" '.tasks | map(select(.id == $id and .completed == true)) | length' "$TASKS_FILE")

    if [[ "$is_done" -eq 0 ]]; then
        echo -e "${YELLOW}Task #$id is not completed${NC}"
        exit 0
    fi

    jq --argjson id "$id" '
        .tasks = [.tasks[] | if .id == $id then .completed = false | .completed_at = null else . end]
    ' "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    local desc=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id) | .description' "$TASKS_FILE")
    echo -e "${YELLOW}Reopened:${NC} $desc"
}

show_help() {
    echo "Tasks - Simple command-line task tracker"
    echo ""
    echo "Usage:"
    echo "  tasks.sh add \"description\" [-p high|med|low] [-d YYYY-MM-DD]"
    echo "  tasks.sh list [options]       Show tasks"
    echo "    --all, -a                   Show all including completed"
    echo "    --overdue, -o               Show overdue tasks only"
    echo "    --today, -t                 Show tasks due today"
    echo "    --priority, -p              Sort by priority"
    echo "    --high                      Show high priority only"
    echo ""
    echo "  tasks.sh done <id>            Mark task as complete"
    echo "  tasks.sh undone <id>          Reopen a completed task"
    echo "  tasks.sh edit <id> \"desc\"     Edit task description"
    echo "  tasks.sh priority <id> <lvl>  Set priority (high/med/low)"
    echo "  tasks.sh due <id> <date>      Set due date (or 'clear')"
    echo "  tasks.sh remove <id>          Remove a task"
    echo "  tasks.sh clear                Remove completed tasks"
    echo "  tasks.sh help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  tasks.sh add \"Review PR\" -p high -d 2026-01-20"
    echo "  tasks.sh add \"Update docs\" -p low"
    echo "  tasks.sh list --priority"
    echo "  tasks.sh due 5 2026-01-25"
}

case "$1" in
    add)
        shift
        add_task "$@"
        ;;
    list|ls)
        list_tasks "$2"
        ;;
    done|complete)
        complete_task "$2"
        ;;
    undone|reopen|undo)
        undone_task "$2"
        ;;
    edit)
        shift
        edit_task "$@"
        ;;
    priority|pri)
        set_priority "$2" "$3"
        ;;
    due|deadline)
        set_due_date "$2" "$3"
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
