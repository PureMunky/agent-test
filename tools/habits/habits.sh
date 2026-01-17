#!/bin/bash
#
# Habits - Simple daily habit tracker
#
# Usage:
#   habits.sh add "habit name"          - Add a new habit to track
#   habits.sh check "habit" [date]      - Mark habit done (default: today)
#   habits.sh uncheck "habit" [date]    - Unmark habit for a date
#   habits.sh list                      - Show all habits with today's status
#   habits.sh status [days]             - Show habit grid (default: 7 days)
#   habits.sh streak "habit"            - Show current streak for a habit
#   habits.sh remove "habit"            - Remove a habit
#   habits.sh rename "old" "new"        - Rename a habit
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
HABITS_FILE="$DATA_DIR/habits.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize habits file if it doesn't exist
if [[ ! -f "$HABITS_FILE" ]]; then
    echo '{"habits":[],"completions":{}}' > "$HABITS_FILE"
fi

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

add_habit() {
    local name="$*"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh add \"habit name\""
        exit 1
    fi

    # Check if habit already exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Habit '$name' already exists.${NC}"
        exit 1
    fi

    jq --arg name "$name" '.habits += [$name]' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}Added habit:${NC} $name"
}

check_habit() {
    local name="$1"
    local date="${2:-$TODAY}"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh check \"habit\" [date]"
        exit 1
    fi

    # Validate date format
    if ! date -d "$date" &>/dev/null; then
        echo -e "${RED}Invalid date format: $date${NC}"
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        echo "Add it first with: habits.sh add \"$name\""
        exit 1
    fi

    # Add completion
    jq --arg name "$name" --arg date "$date" '
        if .completions[$name] == null then
            .completions[$name] = []
        end |
        if (.completions[$name] | index($date)) == null then
            .completions[$name] += [$date]
        end |
        .completions[$name] |= sort
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}✓${NC} Marked '$name' done for $date"
}

uncheck_habit() {
    local name="$1"
    local date="${2:-$TODAY}"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh uncheck \"habit\" [date]"
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    # Remove completion
    jq --arg name "$name" --arg date "$date" '
        if .completions[$name] != null then
            .completions[$name] -= [$date]
        end
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${YELLOW}✗${NC} Unmarked '$name' for $date"
}

list_habits() {
    local habits=$(jq -r '.habits[]' "$HABITS_FILE" 2>/dev/null)

    if [[ -z "$habits" ]]; then
        echo "No habits tracked yet."
        echo "Add one with: habits.sh add \"exercise\""
        exit 0
    fi

    echo -e "${BLUE}=== Today's Habits ($TODAY) ===${NC}"
    echo ""

    local done_count=0
    local total_count=0

    while IFS= read -r habit; do
        total_count=$((total_count + 1))
        local completed=$(jq -r --arg name "$habit" --arg date "$TODAY" '
            if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                "yes"
            else
                "no"
            end
        ' "$HABITS_FILE")

        local streak=$(calculate_streak "$habit")

        if [[ "$completed" == "yes" ]]; then
            echo -e "  ${GREEN}[✓]${NC} $habit ${GRAY}(${streak} day streak)${NC}"
            done_count=$((done_count + 1))
        else
            echo -e "  ${GRAY}[ ]${NC} $habit ${GRAY}(${streak} day streak)${NC}"
        fi
    done <<< "$habits"

    echo ""
    echo -e "${CYAN}Progress:${NC} $done_count/$total_count completed"
}

calculate_streak() {
    local name="$1"
    local streak=0
    local check_date="$TODAY"

    while true; do
        local completed=$(jq -r --arg name "$name" --arg date "$check_date" '
            if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                "yes"
            else
                "no"
            end
        ' "$HABITS_FILE")

        if [[ "$completed" == "yes" ]]; then
            streak=$((streak + 1))
            check_date=$(date -d "$check_date - 1 day" +%Y-%m-%d 2>/dev/null || date -v-1d -jf "%Y-%m-%d" "$check_date" +%Y-%m-%d 2>/dev/null)
        else
            break
        fi
    done

    echo $streak
}

show_streak() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh streak \"habit\""
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    local streak=$(calculate_streak "$name")
    local total=$(jq -r --arg name "$name" '.completions[$name] // [] | length' "$HABITS_FILE")

    echo -e "${BLUE}=== Streak: $name ===${NC}"
    echo ""
    echo -e "${GREEN}Current streak:${NC} $streak days"
    echo -e "${CYAN}Total completions:${NC} $total"

    # Show longest streak
    local completions=$(jq -r --arg name "$name" '.completions[$name] // [] | .[]' "$HABITS_FILE" | sort)

    if [[ -n "$completions" ]]; then
        local longest=0
        local current=0
        local prev_date=""

        while IFS= read -r date; do
            if [[ -z "$prev_date" ]]; then
                current=1
            else
                local expected=$(date -d "$prev_date + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -jf "%Y-%m-%d" "$prev_date" +%Y-%m-%d 2>/dev/null)
                if [[ "$date" == "$expected" ]]; then
                    current=$((current + 1))
                else
                    current=1
                fi
            fi

            if [[ $current -gt $longest ]]; then
                longest=$current
            fi

            prev_date="$date"
        done <<< "$completions"

        echo -e "${MAGENTA}Longest streak:${NC} $longest days"
    fi
}

show_status() {
    local days=${1:-7}

    local habits=$(jq -r '.habits[]' "$HABITS_FILE" 2>/dev/null)

    if [[ -z "$habits" ]]; then
        echo "No habits tracked yet."
        echo "Add one with: habits.sh add \"exercise\""
        exit 0
    fi

    echo -e "${BLUE}=== Habit Tracker (Last $days days) ===${NC}"
    echo ""

    # Print header with dates
    printf "%-20s" ""
    for ((i = days - 1; i >= 0; i--)); do
        local date=$(date -d "$TODAY - $i days" +%d 2>/dev/null || date -v-${i}d +%d 2>/dev/null)
        printf "%3s" "$date"
    done
    echo ""

    # Print day names
    printf "%-20s" ""
    for ((i = days - 1; i >= 0; i--)); do
        local day=$(date -d "$TODAY - $i days" +%a 2>/dev/null || date -v-${i}d +%a 2>/dev/null)
        printf "%3s" "${day:0:2}"
    done
    echo ""
    echo ""

    # Print each habit
    while IFS= read -r habit; do
        local display_name="$habit"
        if [[ ${#display_name} -gt 18 ]]; then
            display_name="${display_name:0:17}…"
        fi
        printf "%-20s" "$display_name"

        for ((i = days - 1; i >= 0; i--)); do
            local check_date=$(date -d "$TODAY - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
            local completed=$(jq -r --arg name "$habit" --arg date "$check_date" '
                if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                    "yes"
                else
                    "no"
                end
            ' "$HABITS_FILE")

            if [[ "$completed" == "yes" ]]; then
                printf " ${GREEN}●${NC} "
            else
                printf " ${GRAY}○${NC} "
            fi
        done

        # Show streak
        local streak=$(calculate_streak "$habit")
        if [[ $streak -gt 0 ]]; then
            printf " ${YELLOW}%d${NC}" $streak
        fi

        echo ""
    done <<< "$habits"

    echo ""
    echo -e "${GRAY}● = done, ○ = missed, number = current streak${NC}"
}

remove_habit() {
    local name="$*"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh remove \"habit\""
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    jq --arg name "$name" '
        .habits -= [$name] |
        del(.completions[$name])
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${RED}Removed habit:${NC} $name"
}

rename_habit() {
    local old_name="$1"
    local new_name="$2"

    if [[ -z "$old_name" ]] || [[ -z "$new_name" ]]; then
        echo "Usage: habits.sh rename \"old name\" \"new name\""
        exit 1
    fi

    # Check if old habit exists
    local exists=$(jq -r --arg name "$old_name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$old_name' not found.${NC}"
        exit 1
    fi

    # Check if new name already exists
    local new_exists=$(jq -r --arg name "$new_name" '.habits | map(select(. == $name)) | length' "$HABITS_FILE")

    if [[ "$new_exists" -gt 0 ]]; then
        echo -e "${YELLOW}Habit '$new_name' already exists.${NC}"
        exit 1
    fi

    jq --arg old "$old_name" --arg new "$new_name" '
        .habits = [.habits[] | if . == $old then $new else . end] |
        if .completions[$old] != null then
            .completions[$new] = .completions[$old] |
            del(.completions[$old])
        end
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}Renamed:${NC} '$old_name' → '$new_name'"
}

show_help() {
    echo "Habits - Simple daily habit tracker"
    echo ""
    echo "Usage:"
    echo "  habits.sh add \"habit\"          Add a new habit"
    echo "  habits.sh check \"habit\" [date] Mark habit done (default: today)"
    echo "  habits.sh uncheck \"habit\" [date] Unmark habit for a date"
    echo "  habits.sh list                  Show today's habits"
    echo "  habits.sh status [days]         Show habit grid (default: 7)"
    echo "  habits.sh streak \"habit\"        Show streak for a habit"
    echo "  habits.sh remove \"habit\"        Remove a habit"
    echo "  habits.sh rename \"old\" \"new\"    Rename a habit"
    echo "  habits.sh help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  habits.sh add \"exercise\""
    echo "  habits.sh check \"exercise\""
    echo "  habits.sh check \"reading\" 2026-01-15"
    echo "  habits.sh status 14"
}

case "$1" in
    add)
        shift
        add_habit "$@"
        ;;
    check|done|mark)
        shift
        check_habit "$@"
        ;;
    uncheck|undo|unmark)
        shift
        uncheck_habit "$@"
        ;;
    list|ls)
        list_habits
        ;;
    status|grid|show)
        show_status "$2"
        ;;
    streak)
        shift
        show_streak "$@"
        ;;
    remove|rm|delete)
        shift
        remove_habit "$@"
        ;;
    rename|mv)
        rename_habit "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_habits
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'habits.sh help' for usage"
        exit 1
        ;;
esac
