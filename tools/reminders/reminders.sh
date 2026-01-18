#!/bin/bash
#
# Reminders - Quick reminder and alarm tool for personal productivity
#
# Usage:
#   reminders.sh add "message" in 30m          - Remind in 30 minutes
#   reminders.sh add "message" at 14:30        - Remind at specific time
#   reminders.sh add "message" at 2026-01-20   - Remind on specific date
#   reminders.sh add "message" daily at 09:00  - Daily recurring reminder
#   reminders.sh list                          - Show pending reminders
#   reminders.sh done <id>                     - Mark reminder as done
#   reminders.sh delete <id>                   - Delete a reminder
#   reminders.sh check                         - Check for due reminders
#   reminders.sh snooze <id> <duration>        - Snooze a reminder
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REMINDERS_FILE="$DATA_DIR/reminders.json"
NOW=$(date +%s)
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize reminders file if it doesn't exist
if [[ ! -f "$REMINDERS_FILE" ]]; then
    echo '{"reminders":[],"next_id":1,"completed":[]}' > "$REMINDERS_FILE"
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

notify() {
    local message="$1"
    local title="${2:-Reminder}"

    # Try to send desktop notification
    if command -v notify-send &> /dev/null; then
        notify-send -u critical "$title" "$message"
    fi

    # Also try terminal bell
    echo -e "\a"

    # Print to terminal
    echo -e "${BOLD}${MAGENTA}*** REMINDER ***${NC}"
    echo -e "${YELLOW}$message${NC}"
    echo ""
}

parse_time() {
    local input="$*"
    local target_epoch=""

    # Handle "in X minutes/hours/days"
    if [[ "$input" =~ ^in[[:space:]]+([0-9]+)([mhd]) ]]; then
        local amount="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            m) target_epoch=$((NOW + amount * 60)) ;;
            h) target_epoch=$((NOW + amount * 3600)) ;;
            d) target_epoch=$((NOW + amount * 86400)) ;;
        esac
    # Handle "in X minutes/hours/days" (full words)
    elif [[ "$input" =~ ^in[[:space:]]+([0-9]+)[[:space:]]+(minute|min|hour|hr|day)s? ]]; then
        local amount="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            minute|min) target_epoch=$((NOW + amount * 60)) ;;
            hour|hr) target_epoch=$((NOW + amount * 3600)) ;;
            day) target_epoch=$((NOW + amount * 86400)) ;;
        esac
    # Handle "at HH:MM" (today or tomorrow if past)
    elif [[ "$input" =~ ^at[[:space:]]+([0-9]{1,2}):([0-9]{2}) ]]; then
        local hour="${BASH_REMATCH[1]}"
        local minute="${BASH_REMATCH[2]}"

        # Create timestamp for today at that time
        local target_time="$TODAY $hour:$minute:00"
        target_epoch=$(date -d "$target_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$target_time" +%s 2>/dev/null)

        # If the time has passed today, set for tomorrow
        if [[ $target_epoch -lt $NOW ]]; then
            target_epoch=$((target_epoch + 86400))
        fi
    # Handle "at YYYY-MM-DD" or "at YYYY-MM-DD HH:MM"
    elif [[ "$input" =~ ^at[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})([[:space:]]+([0-9]{2}):([0-9]{2}))? ]]; then
        local target_date="${BASH_REMATCH[1]}"
        local target_hour="${BASH_REMATCH[3]:-09}"
        local target_min="${BASH_REMATCH[4]:-00}"

        local target_time="$target_date $target_hour:$target_min:00"
        target_epoch=$(date -d "$target_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$target_time" +%s 2>/dev/null)
    # Handle "tomorrow" or "tomorrow at HH:MM"
    elif [[ "$input" =~ ^tomorrow([[:space:]]+at[[:space:]]+([0-9]{1,2}):([0-9]{2}))? ]]; then
        local hour="${BASH_REMATCH[2]:-09}"
        local minute="${BASH_REMATCH[3]:-00}"
        local tomorrow=$(date -d "tomorrow" +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d 2>/dev/null)
        local target_time="$tomorrow $hour:$minute:00"
        target_epoch=$(date -d "$target_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$target_time" +%s 2>/dev/null)
    fi

    echo "$target_epoch"
}

parse_recurring() {
    local input="$*"
    local pattern=""

    if [[ "$input" =~ daily ]]; then
        pattern="daily"
    elif [[ "$input" =~ weekly ]]; then
        pattern="weekly"
    elif [[ "$input" =~ (monday|tuesday|wednesday|thursday|friday|saturday|sunday) ]]; then
        pattern="${BASH_REMATCH[1]}"
    fi

    echo "$pattern"
}

add_reminder() {
    # Parse arguments: message first, then time specifier
    local message=""
    local time_spec=""
    local recurring=""
    local found_time=false

    # Build message and time spec
    for arg in "$@"; do
        if [[ "$arg" == "in" ]] || [[ "$arg" == "at" ]] || [[ "$arg" == "tomorrow" ]] || [[ "$arg" == "daily" ]] || [[ "$arg" == "weekly" ]]; then
            found_time=true
        fi

        if $found_time; then
            time_spec="$time_spec $arg"
        else
            message="$message $arg"
        fi
    done

    message=$(echo "$message" | sed 's/^ *//' | sed 's/ *$//')
    time_spec=$(echo "$time_spec" | sed 's/^ *//' | sed 's/ *$//')

    if [[ -z "$message" ]]; then
        echo "Usage: reminders.sh add \"message\" in 30m"
        echo "       reminders.sh add \"message\" at 14:30"
        echo "       reminders.sh add \"message\" tomorrow at 09:00"
        echo "       reminders.sh add \"message\" daily at 09:00"
        exit 1
    fi

    if [[ -z "$time_spec" ]]; then
        echo -e "${RED}Error: Please specify when to remind you${NC}"
        echo "Examples: in 30m, in 1h, at 14:30, tomorrow"
        exit 1
    fi

    # Parse recurring pattern
    recurring=$(parse_recurring "$time_spec")

    # Parse target time
    local target_epoch=$(parse_time "$time_spec")

    if [[ -z "$target_epoch" ]]; then
        echo -e "${RED}Error: Could not parse time specification: $time_spec${NC}"
        echo "Supported formats:"
        echo "  in 30m, in 2h, in 1d"
        echo "  in 30 minutes, in 2 hours"
        echo "  at 14:30, at 09:00"
        echo "  at 2026-01-20"
        echo "  tomorrow, tomorrow at 14:00"
        echo "  daily at 09:00"
        exit 1
    fi

    local target_time=$(date -d "@$target_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$target_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null)
    local created=$(date '+%Y-%m-%d %H:%M:%S')

    local next_id=$(jq -r '.next_id' "$REMINDERS_FILE")

    jq --arg msg "$message" \
       --argjson epoch "$target_epoch" \
       --arg target "$target_time" \
       --arg created "$created" \
       --arg recurring "$recurring" \
       --argjson id "$next_id" '
        .reminders += [{
            "id": $id,
            "message": $msg,
            "target_epoch": $epoch,
            "target_time": $target,
            "created": $created,
            "recurring": (if $recurring == "" then null else $recurring end),
            "snoozed": 0
        }] |
        .next_id = ($id + 1)
    ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

    echo -e "${GREEN}Reminder #$next_id set:${NC} $message"
    echo -e "${CYAN}When:${NC} $target_time"
    if [[ -n "$recurring" ]]; then
        echo -e "${MAGENTA}Recurring:${NC} $recurring"
    fi
}

list_reminders() {
    local reminders=$(jq -r '.reminders | sort_by(.target_epoch)' "$REMINDERS_FILE")
    local count=$(echo "$reminders" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo "No pending reminders."
        echo "Add one with: reminders.sh add \"message\" in 30m"
        exit 0
    fi

    echo -e "${BLUE}=== Pending Reminders ===${NC}"
    echo ""

    local now=$(date +%s)

    echo "$reminders" | jq -r '.[] | "\(.id)|\(.message)|\(.target_time)|\(.target_epoch)|\(.recurring // "")|\(.snoozed)"' | while IFS='|' read -r id msg target target_epoch recurring snoozed; do
        local time_left=$((target_epoch - now))
        local status=""

        if [[ $time_left -lt 0 ]]; then
            status="${RED}OVERDUE${NC}"
        elif [[ $time_left -lt 3600 ]]; then
            local mins=$((time_left / 60))
            status="${YELLOW}in ${mins}m${NC}"
        elif [[ $time_left -lt 86400 ]]; then
            local hours=$((time_left / 3600))
            local mins=$(((time_left % 3600) / 60))
            status="${CYAN}in ${hours}h ${mins}m${NC}"
        else
            local days=$((time_left / 86400))
            status="${GRAY}in ${days}d${NC}"
        fi

        local recurring_tag=""
        if [[ -n "$recurring" ]]; then
            recurring_tag=" ${MAGENTA}($recurring)${NC}"
        fi

        local snooze_tag=""
        if [[ "$snoozed" -gt 0 ]]; then
            snooze_tag=" ${GRAY}[snoozed ${snoozed}x]${NC}"
        fi

        echo -e "  ${BOLD}[$id]${NC} $msg"
        echo -e "       ${GRAY}$target${NC} - $status$recurring_tag$snooze_tag"
    done
}

check_reminders() {
    local now=$(date +%s)
    local due=$(jq -r --argjson now "$now" '
        .reminders | map(select(.target_epoch <= $now)) | .[]
    ' "$REMINDERS_FILE" 2>/dev/null)

    if [[ -z "$due" ]]; then
        echo -e "${GREEN}No reminders due.${NC}"
        exit 0
    fi

    echo "$due" | jq -r '"\(.id)|\(.message)|\(.recurring // "")"' | while IFS='|' read -r id msg recurring; do
        notify "$msg" "Reminder #$id"

        if [[ -n "$recurring" ]]; then
            # Reschedule recurring reminder
            local next_epoch
            case "$recurring" in
                daily) next_epoch=$((now + 86400)) ;;
                weekly) next_epoch=$((now + 604800)) ;;
                monday|tuesday|wednesday|thursday|friday|saturday|sunday)
                    # Find next occurrence of that day
                    local target_day="next $recurring"
                    next_epoch=$(date -d "$target_day" +%s 2>/dev/null || date -v+"$recurring" +%s 2>/dev/null)
                    ;;
            esac

            if [[ -n "$next_epoch" ]]; then
                local next_time=$(date -d "@$next_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$next_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null)
                jq --argjson id "$id" --argjson epoch "$next_epoch" --arg time "$next_time" '
                    .reminders = [.reminders[] | if .id == $id then .target_epoch = $epoch | .target_time = $time else . end]
                ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

                echo -e "${CYAN}Rescheduled to: $next_time${NC}"
            fi
        else
            # Move non-recurring reminder to completed
            jq --argjson id "$id" '
                .completed += [(.reminders[] | select(.id == $id))] |
                .reminders = [.reminders[] | select(.id != $id)]
            ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"
        fi

        echo ""
    done
}

done_reminder() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: reminders.sh done <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.reminders | map(select(.id == $id)) | length' "$REMINDERS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Reminder #$id not found${NC}"
        exit 1
    fi

    local msg=$(jq -r --argjson id "$id" '.reminders[] | select(.id == $id) | .message' "$REMINDERS_FILE")

    jq --argjson id "$id" '
        .completed += [(.reminders[] | select(.id == $id))] |
        .reminders = [.reminders[] | select(.id != $id)]
    ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

    echo -e "${GREEN}Completed:${NC} $msg"
}

delete_reminder() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: reminders.sh delete <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.reminders | map(select(.id == $id)) | length' "$REMINDERS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Reminder #$id not found${NC}"
        exit 1
    fi

    local msg=$(jq -r --argjson id "$id" '.reminders[] | select(.id == $id) | .message' "$REMINDERS_FILE")

    jq --argjson id "$id" '
        .reminders = [.reminders[] | select(.id != $id)]
    ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

    echo -e "${RED}Deleted:${NC} $msg"
}

snooze_reminder() {
    local id="$1"
    local duration="${2:-10m}"

    if [[ -z "$id" ]]; then
        echo "Usage: reminders.sh snooze <id> [duration]"
        echo "Default: 10 minutes"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.reminders | map(select(.id == $id)) | length' "$REMINDERS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Reminder #$id not found${NC}"
        exit 1
    fi

    # Parse snooze duration
    local snooze_seconds=600  # Default 10 minutes

    if [[ "$duration" =~ ^([0-9]+)([mhd])$ ]]; then
        local amount="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            m) snooze_seconds=$((amount * 60)) ;;
            h) snooze_seconds=$((amount * 3600)) ;;
            d) snooze_seconds=$((amount * 86400)) ;;
        esac
    fi

    local now=$(date +%s)
    local new_epoch=$((now + snooze_seconds))
    local new_time=$(date -d "@$new_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$new_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null)

    jq --argjson id "$id" --argjson epoch "$new_epoch" --arg time "$new_time" '
        .reminders = [.reminders[] | if .id == $id then .target_epoch = $epoch | .target_time = $time | .snoozed = (.snoozed + 1) else . end]
    ' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

    local msg=$(jq -r --argjson id "$id" '.reminders[] | select(.id == $id) | .message' "$REMINDERS_FILE")

    echo -e "${YELLOW}Snoozed:${NC} $msg"
    echo -e "${CYAN}New time:${NC} $new_time"
}

show_completed() {
    local count="${1:-10}"

    echo -e "${BLUE}=== Recently Completed ===${NC}"
    echo ""

    local completed=$(jq -r '.completed | .[-'"$count"':]' "$REMINDERS_FILE")
    local num=$(echo "$completed" | jq 'length')

    if [[ "$num" -eq 0 ]]; then
        echo "No completed reminders."
        exit 0
    fi

    echo "$completed" | jq -r '.[] | "  ✓ \(.message) (\(.target_time))"'
}

clear_completed() {
    local count=$(jq '.completed | length' "$REMINDERS_FILE")

    jq '.completed = []' "$REMINDERS_FILE" > "$REMINDERS_FILE.tmp" && mv "$REMINDERS_FILE.tmp" "$REMINDERS_FILE"

    echo -e "${GREEN}Cleared $count completed reminder(s)${NC}"
}

show_help() {
    echo "Reminders - Quick reminder and alarm tool"
    echo ""
    echo "Usage:"
    echo "  reminders.sh add \"msg\" in 30m       Remind in 30 minutes"
    echo "  reminders.sh add \"msg\" in 2h        Remind in 2 hours"
    echo "  reminders.sh add \"msg\" at 14:30     Remind at specific time"
    echo "  reminders.sh add \"msg\" tomorrow     Remind tomorrow at 9am"
    echo "  reminders.sh add \"msg\" at 2026-01-20  Remind on specific date"
    echo "  reminders.sh add \"msg\" daily at 09:00  Daily recurring"
    echo ""
    echo "  reminders.sh list                   Show pending reminders"
    echo "  reminders.sh check                  Check for due reminders"
    echo "  reminders.sh done <id>              Mark reminder as done"
    echo "  reminders.sh delete <id>            Delete a reminder"
    echo "  reminders.sh snooze <id> [duration] Snooze (default: 10m)"
    echo "  reminders.sh completed [n]          Show last n completed"
    echo "  reminders.sh clear                  Clear completed list"
    echo ""
    echo "Time formats:"
    echo "  in Xm, in Xh, in Xd          (minutes, hours, days)"
    echo "  at HH:MM                     (24-hour time)"
    echo "  at YYYY-MM-DD                (specific date)"
    echo "  tomorrow [at HH:MM]          (next day)"
    echo ""
    echo "Tip: Run 'reminders.sh check' periodically or add to cron"
}

case "$1" in
    add|new|set)
        shift
        add_reminder "$@"
        ;;
    list|ls|show)
        list_reminders
        ;;
    check|due)
        check_reminders
        ;;
    done|complete|finish)
        done_reminder "$2"
        ;;
    delete|del|rm|remove)
        delete_reminder "$2"
        ;;
    snooze|postpone|defer)
        snooze_reminder "$2" "$3"
        ;;
    completed|history)
        show_completed "$2"
        ;;
    clear)
        clear_completed
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_reminders
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'reminders.sh help' for usage"
        exit 1
        ;;
esac
