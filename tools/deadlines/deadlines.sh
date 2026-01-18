#!/bin/bash
#
# Deadlines - Time-sensitive task and deadline tracker
#
# Usage:
#   deadlines.sh add "Task" YYYY-MM-DD [priority]   Add a deadline
#   deadlines.sh list                               Show all deadlines
#   deadlines.sh upcoming [days]                    Show upcoming (default: 7 days)
#   deadlines.sh overdue                            Show overdue items
#   deadlines.sh done <id>                          Mark as complete
#   deadlines.sh remove <id>                        Remove a deadline
#   deadlines.sh snooze <id> [days]                 Snooze deadline by days
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
DEADLINES_FILE="$DATA_DIR/deadlines.json"

mkdir -p "$DATA_DIR"

# Initialize file if it doesn't exist
if [[ ! -f "$DEADLINES_FILE" ]]; then
    echo '{"deadlines":[],"next_id":1}' > "$DEADLINES_FILE"
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

# Get today's date in epoch seconds for calculations
TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date -d "$TODAY" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null)

# Calculate days until deadline
days_until() {
    local due_date="$1"
    local due_epoch=$(date -d "$due_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$due_date" +%s 2>/dev/null)
    local diff=$(( (due_epoch - TODAY_EPOCH) / 86400 ))
    echo "$diff"
}

# Format days remaining with color
format_days() {
    local days=$1
    if [[ $days -lt 0 ]]; then
        echo -e "${RED}${BOLD}OVERDUE by $((-days)) day(s)${NC}"
    elif [[ $days -eq 0 ]]; then
        echo -e "${RED}${BOLD}DUE TODAY${NC}"
    elif [[ $days -eq 1 ]]; then
        echo -e "${YELLOW}${BOLD}DUE TOMORROW${NC}"
    elif [[ $days -le 3 ]]; then
        echo -e "${YELLOW}$days days left${NC}"
    elif [[ $days -le 7 ]]; then
        echo -e "${CYAN}$days days left${NC}"
    else
        echo -e "${GREEN}$days days left${NC}"
    fi
}

# Priority color
priority_color() {
    local priority="$1"
    case "$priority" in
        high)   echo -e "${RED}[HIGH]${NC}" ;;
        medium) echo -e "${YELLOW}[MED]${NC}" ;;
        low)    echo -e "${GREEN}[LOW]${NC}" ;;
        *)      echo -e "${GRAY}[---]${NC}" ;;
    esac
}

add_deadline() {
    local description="$1"
    local due_date="$2"
    local priority="${3:-medium}"
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    if [[ -z "$description" ]] || [[ -z "$due_date" ]]; then
        echo "Usage: deadlines.sh add \"Task description\" YYYY-MM-DD [high|medium|low]"
        echo ""
        echo "Examples:"
        echo "  deadlines.sh add \"Submit report\" 2026-01-25"
        echo "  deadlines.sh add \"Project deadline\" 2026-02-01 high"
        exit 1
    fi

    # Validate date format
    if ! date -d "$due_date" &>/dev/null 2>&1; then
        # Try BSD date
        if ! date -j -f "%Y-%m-%d" "$due_date" &>/dev/null 2>&1; then
            echo -e "${RED}Invalid date format. Use YYYY-MM-DD${NC}"
            exit 1
        fi
    fi

    # Validate priority
    if [[ ! "$priority" =~ ^(high|medium|low)$ ]]; then
        priority="medium"
    fi

    local next_id=$(jq -r '.next_id' "$DEADLINES_FILE")

    jq --arg desc "$description" \
       --arg due "$due_date" \
       --arg pri "$priority" \
       --arg ts "$timestamp" \
       --argjson id "$next_id" '
        .deadlines += [{
            "id": $id,
            "description": $desc,
            "due_date": $due,
            "priority": $pri,
            "created": $ts,
            "completed": false,
            "completed_at": null
        }] |
        .next_id = ($id + 1)
    ' "$DEADLINES_FILE" > "$DEADLINES_FILE.tmp" && mv "$DEADLINES_FILE.tmp" "$DEADLINES_FILE"

    local days=$(days_until "$due_date")
    echo -e "${GREEN}Deadline #$next_id added:${NC} $description"
    echo -e "  Due: $due_date ($(format_days $days))"
    echo -e "  Priority: $(priority_color $priority)"
}

list_deadlines() {
    local show_completed="${1:-false}"

    echo -e "${BLUE}${BOLD}=== Deadlines ===${NC}"
    echo ""

    local pending=$(jq -r '.deadlines | map(select(.completed == false)) | length' "$DEADLINES_FILE")
    local completed=$(jq -r '.deadlines | map(select(.completed == true)) | length' "$DEADLINES_FILE")

    if [[ "$pending" -eq 0 ]] && [[ "$completed" -eq 0 ]]; then
        echo "No deadlines tracked. Add one with:"
        echo "  deadlines.sh add \"Task\" YYYY-MM-DD [priority]"
        exit 0
    fi

    if [[ "$pending" -gt 0 ]]; then
        # Sort by due date and display
        jq -r '.deadlines | map(select(.completed == false)) | sort_by(.due_date) | .[] |
            "\(.id)|\(.description)|\(.due_date)|\(.priority)"' "$DEADLINES_FILE" | \
        while IFS='|' read -r id desc due_date priority; do
            local days=$(days_until "$due_date")
            local pri_display=$(priority_color "$priority")
            local days_display=$(format_days "$days")

            echo -e "  ${BOLD}#$id${NC} $pri_display $desc"
            echo -e "      Due: $due_date ($days_display)"
            echo ""
        done
    else
        echo -e "${GREEN}No pending deadlines!${NC}"
        echo ""
    fi

    if [[ "$completed" -gt 0 ]] && [[ "$show_completed" == "true" ]]; then
        echo -e "${GRAY}--- Completed ($completed) ---${NC}"
        jq -r '.deadlines | map(select(.completed == true)) | .[] |
            "  [#\(.id)] \(.description) (was due: \(.due_date))"' "$DEADLINES_FILE" | \
        while read line; do
            echo -e "${GRAY}$line${NC}"
        done
    fi
}

upcoming_deadlines() {
    local days_ahead=${1:-7}
    local future_epoch=$((TODAY_EPOCH + (days_ahead * 86400)))
    local future_date=$(date -d "@$future_epoch" +%Y-%m-%d 2>/dev/null || date -r "$future_epoch" +%Y-%m-%d 2>/dev/null)

    echo -e "${BLUE}${BOLD}=== Upcoming Deadlines (next $days_ahead days) ===${NC}"
    echo ""

    local count=0
    jq -r '.deadlines | map(select(.completed == false)) | sort_by(.due_date) | .[] |
        "\(.id)|\(.description)|\(.due_date)|\(.priority)"' "$DEADLINES_FILE" | \
    while IFS='|' read -r id desc due_date priority; do
        local days=$(days_until "$due_date")
        if [[ $days -le $days_ahead ]]; then
            local pri_display=$(priority_color "$priority")
            local days_display=$(format_days "$days")

            echo -e "  ${BOLD}#$id${NC} $pri_display $desc"
            echo -e "      $days_display - $due_date"
            echo ""
            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}No deadlines in the next $days_ahead days.${NC}"
    fi
}

show_overdue() {
    echo -e "${RED}${BOLD}=== Overdue Deadlines ===${NC}"
    echo ""

    local found=false
    jq -r '.deadlines | map(select(.completed == false)) | sort_by(.due_date) | .[] |
        "\(.id)|\(.description)|\(.due_date)|\(.priority)"' "$DEADLINES_FILE" | \
    while IFS='|' read -r id desc due_date priority; do
        local days=$(days_until "$due_date")
        if [[ $days -lt 0 ]]; then
            found=true
            local pri_display=$(priority_color "$priority")
            echo -e "  ${BOLD}#$id${NC} $pri_display $desc"
            echo -e "      ${RED}OVERDUE by $((-days)) day(s)${NC} - was due: $due_date"
            echo ""
        fi
    done

    if [[ "$found" == "false" ]]; then
        echo -e "${GREEN}No overdue deadlines!${NC}"
    fi
}

complete_deadline() {
    local id=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    if [[ -z "$id" ]]; then
        echo "Usage: deadlines.sh done <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.deadlines | map(select(.id == $id)) | length' "$DEADLINES_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Deadline #$id not found${NC}"
        exit 1
    fi

    local already_done=$(jq --argjson id "$id" '.deadlines | map(select(.id == $id and .completed == true)) | length' "$DEADLINES_FILE")

    if [[ "$already_done" -gt 0 ]]; then
        echo -e "${YELLOW}Deadline #$id is already completed${NC}"
        exit 0
    fi

    jq --argjson id "$id" --arg ts "$timestamp" '
        .deadlines = [.deadlines[] | if .id == $id then .completed = true | .completed_at = $ts else . end]
    ' "$DEADLINES_FILE" > "$DEADLINES_FILE.tmp" && mv "$DEADLINES_FILE.tmp" "$DEADLINES_FILE"

    local desc=$(jq -r --argjson id "$id" '.deadlines[] | select(.id == $id) | .description' "$DEADLINES_FILE")
    echo -e "${GREEN}Completed:${NC} $desc"
}

remove_deadline() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: deadlines.sh remove <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.deadlines | map(select(.id == $id)) | length' "$DEADLINES_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Deadline #$id not found${NC}"
        exit 1
    fi

    local desc=$(jq -r --argjson id "$id" '.deadlines[] | select(.id == $id) | .description' "$DEADLINES_FILE")

    jq --argjson id "$id" '.deadlines = [.deadlines[] | select(.id != $id)]' "$DEADLINES_FILE" > "$DEADLINES_FILE.tmp" && mv "$DEADLINES_FILE.tmp" "$DEADLINES_FILE"

    echo -e "${RED}Removed:${NC} $desc"
}

snooze_deadline() {
    local id=$1
    local snooze_days=${2:-1}

    if [[ -z "$id" ]]; then
        echo "Usage: deadlines.sh snooze <id> [days]"
        echo "  Default: snooze by 1 day"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.deadlines | map(select(.id == $id and .completed == false)) | length' "$DEADLINES_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Active deadline #$id not found${NC}"
        exit 1
    fi

    local current_due=$(jq -r --argjson id "$id" '.deadlines[] | select(.id == $id) | .due_date' "$DEADLINES_FILE")
    local current_epoch=$(date -d "$current_due" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$current_due" +%s 2>/dev/null)
    local new_epoch=$((current_epoch + (snooze_days * 86400)))
    local new_due=$(date -d "@$new_epoch" +%Y-%m-%d 2>/dev/null || date -r "$new_epoch" +%Y-%m-%d 2>/dev/null)

    jq --argjson id "$id" --arg new_due "$new_due" '
        .deadlines = [.deadlines[] | if .id == $id then .due_date = $new_due else . end]
    ' "$DEADLINES_FILE" > "$DEADLINES_FILE.tmp" && mv "$DEADLINES_FILE.tmp" "$DEADLINES_FILE"

    local desc=$(jq -r --argjson id "$id" '.deadlines[] | select(.id == $id) | .description' "$DEADLINES_FILE")
    echo -e "${YELLOW}Snoozed:${NC} $desc"
    echo -e "  New due date: $new_due"
}

show_summary() {
    echo -e "${BLUE}${BOLD}=== Deadline Summary ===${NC}"
    echo ""

    local total=$(jq '.deadlines | map(select(.completed == false)) | length' "$DEADLINES_FILE")
    local overdue=$(jq -r '.deadlines | map(select(.completed == false)) | .[].due_date' "$DEADLINES_FILE" | \
        while read due_date; do
            [[ $(days_until "$due_date") -lt 0 ]] && echo "1"
        done | wc -l)
    local today_count=$(jq -r '.deadlines | map(select(.completed == false)) | .[].due_date' "$DEADLINES_FILE" | \
        while read due_date; do
            [[ $(days_until "$due_date") -eq 0 ]] && echo "1"
        done | wc -l)
    local this_week=$(jq -r '.deadlines | map(select(.completed == false)) | .[].due_date' "$DEADLINES_FILE" | \
        while read due_date; do
            local d=$(days_until "$due_date")
            [[ $d -ge 0 ]] && [[ $d -le 7 ]] && echo "1"
        done | wc -l)
    local high_pri=$(jq '.deadlines | map(select(.completed == false and .priority == "high")) | length' "$DEADLINES_FILE")

    echo -e "  Total pending:    ${BOLD}$total${NC}"
    [[ $overdue -gt 0 ]] && echo -e "  ${RED}Overdue:          $overdue${NC}"
    [[ $today_count -gt 0 ]] && echo -e "  ${YELLOW}Due today:        $today_count${NC}"
    echo -e "  Due this week:    $this_week"
    [[ $high_pri -gt 0 ]] && echo -e "  ${RED}High priority:    $high_pri${NC}"
}

show_help() {
    echo "Deadlines - Time-sensitive task and deadline tracker"
    echo ""
    echo "Usage:"
    echo "  deadlines.sh add \"desc\" DATE [priority]  Add a deadline"
    echo "  deadlines.sh list [--all]                Show deadlines"
    echo "  deadlines.sh upcoming [days]             Show upcoming (default: 7 days)"
    echo "  deadlines.sh overdue                     Show overdue items"
    echo "  deadlines.sh done <id>                   Mark as complete"
    echo "  deadlines.sh remove <id>                 Remove a deadline"
    echo "  deadlines.sh snooze <id> [days]          Snooze by days (default: 1)"
    echo "  deadlines.sh summary                     Show quick summary"
    echo "  deadlines.sh help                        Show this help"
    echo ""
    echo "Priority levels: high, medium, low (default: medium)"
    echo ""
    echo "Examples:"
    echo "  deadlines.sh add \"Submit report\" 2026-01-25 high"
    echo "  deadlines.sh add \"Call dentist\" 2026-02-01"
    echo "  deadlines.sh upcoming 14"
    echo "  deadlines.sh snooze 3 7"
}

case "$1" in
    add)
        shift
        add_deadline "$1" "$2" "$3"
        ;;
    list|ls)
        if [[ "$2" == "--all" ]]; then
            list_deadlines "true"
        else
            list_deadlines
        fi
        ;;
    upcoming|soon)
        upcoming_deadlines "$2"
        ;;
    overdue|late)
        show_overdue
        ;;
    done|complete)
        complete_deadline "$2"
        ;;
    remove|rm|delete)
        remove_deadline "$2"
        ;;
    snooze|postpone)
        snooze_deadline "$2" "$3"
        ;;
    summary|stats)
        show_summary
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # Default: show summary and upcoming
        show_summary
        echo ""
        upcoming_deadlines 7
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'deadlines.sh help' for usage"
        exit 1
        ;;
esac
