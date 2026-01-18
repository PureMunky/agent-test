#!/bin/bash
#
# Break Timer - Smart break reminders with healthy activity suggestions
#
# Usage:
#   break-timer.sh start [minutes]  - Start break reminder timer (default: 50 min)
#   break-timer.sh break [duration] - Take a break now (default: 5 min)
#   break-timer.sh long             - Take a long break (15 min)
#   break-timer.sh stretch          - Quick stretch break (2 min)
#   break-timer.sh suggest          - Get a random break activity suggestion
#   break-timer.sh history          - Show today's break history
#   break-timer.sh stats            - Show break statistics
#   break-timer.sh configure        - Configure reminder settings
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CONFIG_FILE="$DATA_DIR/config.json"
HISTORY_FILE="$DATA_DIR/break_history.csv"
PID_FILE="$DATA_DIR/reminder.pid"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize config file with defaults
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
    "work_interval": 50,
    "short_break": 5,
    "long_break": 15,
    "stretch_break": 2,
    "notify_sound": true,
    "show_suggestion": true
}
EOF
fi

# Initialize history file
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo "date,time,type,duration,activity" > "$HISTORY_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Break activity suggestions organized by type
STRETCH_ACTIVITIES=(
    "Neck rolls - slowly roll your head in circles"
    "Shoulder shrugs - raise shoulders to ears, hold, release"
    "Wrist circles - rotate wrists in both directions"
    "Standing stretch - reach arms overhead and stretch tall"
    "Chest opener - clasp hands behind back, squeeze shoulder blades"
    "Seated spinal twist - gently twist torso left and right"
    "Eye palming - rub palms together, cup over closed eyes"
    "Ankle circles - rotate ankles to improve circulation"
)

SHORT_BREAK_ACTIVITIES=(
    "Walk to get water - hydration boost"
    "Look at something 20 feet away for 20 seconds (20-20-20 rule)"
    "Step outside for fresh air"
    "Do 10 jumping jacks"
    "Practice deep breathing - 4 counts in, 4 out"
    "Make a cup of tea or coffee"
    "Quick tidy - clear one small area of your desk"
    "Listen to one favorite song"
    "Text a friend or family member"
    "Water a plant or look out the window"
    "Doodle or sketch for a few minutes"
    "Do a quick mindfulness check-in"
)

LONG_BREAK_ACTIVITIES=(
    "Take a short walk around the block"
    "Do a 10-minute guided meditation"
    "Prepare a healthy snack"
    "Call a friend for a quick chat"
    "Read a chapter of a book"
    "Do a quick yoga routine"
    "Play with a pet"
    "Step outside and observe nature"
    "Journal for 10 minutes"
    "Do some light housekeeping"
    "Practice a hobby for 15 minutes"
    "Take a power nap (set an alarm!)"
)

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

get_config() {
    local key=$1
    jq -r ".$key" "$CONFIG_FILE"
}

notify() {
    local title="$1"
    local message="$2"

    # Try desktop notification
    if command -v notify-send &> /dev/null; then
        notify-send -u critical "$title" "$message"
    fi

    # Terminal bell
    if [[ "$(get_config notify_sound)" == "true" ]]; then
        echo -e "\a"
    fi
}

get_random_activity() {
    local type="$1"
    local -n activities=$2
    local count=${#activities[@]}
    local index=$((RANDOM % count))
    echo "${activities[$index]}"
}

log_break() {
    local type="$1"
    local duration="$2"
    local activity="$3"
    local time=$(date +%H:%M:%S)

    # Escape commas in activity
    activity=$(echo "$activity" | tr ',' ';')
    echo "$TODAY,$time,$type,$duration,\"$activity\"" >> "$HISTORY_FILE"
}

countdown_timer() {
    local minutes=$1
    local label=$2
    local total_seconds=$((minutes * 60))
    local remaining=$total_seconds

    while [[ $remaining -gt 0 ]]; do
        local mins=$((remaining / 60))
        local secs=$((remaining % 60))
        printf "\r${CYAN}  %s: ${YELLOW}%02d:%02d${NC} remaining " "$label" $mins $secs
        sleep 1
        ((remaining--))
    done

    echo ""
    echo -e "${GREEN}$label complete!${NC}"
}

start_reminder() {
    local interval="${1:-$(get_config work_interval)}"

    # Check if already running
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}Break reminder already running (PID: $old_pid)${NC}"
            echo "Stop it first with: break-timer.sh stop"
            exit 1
        fi
    fi

    echo -e "${GREEN}Starting break reminder timer${NC}"
    echo -e "You'll be reminded to take a break every ${CYAN}$interval minutes${NC}"
    echo ""

    # Start background reminder
    (
        while true; do
            sleep $((interval * 60))

            local suggestion=""
            if [[ "$(get_config show_suggestion)" == "true" ]]; then
                suggestion=$(get_random_activity "short" SHORT_BREAK_ACTIVITIES)
            fi

            notify "Time for a break!" "$suggestion"
            echo -e "\n${BOLD}${MAGENTA}=== BREAK TIME ===${NC}"
            echo -e "You've been working for $interval minutes."
            echo ""
            if [[ -n "$suggestion" ]]; then
                echo -e "${CYAN}Suggestion:${NC} $suggestion"
            fi
            echo ""
            echo "Run 'break-timer.sh break' to start your break timer"
            echo -e "\a"
        done
    ) &

    echo $! > "$PID_FILE"
    echo -e "Reminder started (PID: $(cat $PID_FILE))"
    echo "Run 'break-timer.sh stop' to disable reminders"
}

stop_reminder() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}Break reminder stopped${NC}"
        else
            echo "Reminder was not running"
        fi
        rm -f "$PID_FILE"
    else
        echo "No active reminder found"
    fi
}

take_break() {
    local duration="${1:-$(get_config short_break)}"
    local type="short"
    local activity=""

    # Determine break type and get suggestion
    if [[ $duration -le 3 ]]; then
        type="stretch"
        activity=$(get_random_activity "stretch" STRETCH_ACTIVITIES)
    elif [[ $duration -ge 10 ]]; then
        type="long"
        activity=$(get_random_activity "long" LONG_BREAK_ACTIVITIES)
    else
        type="short"
        activity=$(get_random_activity "short" SHORT_BREAK_ACTIVITIES)
    fi

    echo ""
    echo -e "${BOLD}${GREEN}=== Taking a ${duration}-minute break ===${NC}"
    echo ""

    if [[ "$(get_config show_suggestion)" == "true" ]] && [[ -n "$activity" ]]; then
        echo -e "${CYAN}Suggested activity:${NC}"
        echo -e "  $activity"
        echo ""
    fi

    countdown_timer "$duration" "Break"

    log_break "$type" "$duration" "$activity"

    notify "Break over!" "Time to get back to work!"

    echo ""
    echo -e "${GREEN}Break logged. Great job taking care of yourself!${NC}"
}

take_stretch() {
    local duration=$(get_config stretch_break)

    echo ""
    echo -e "${BOLD}${MAGENTA}=== Quick Stretch Break ===${NC}"
    echo ""

    local activity=$(get_random_activity "stretch" STRETCH_ACTIVITIES)
    echo -e "${CYAN}Stretch:${NC} $activity"
    echo ""

    countdown_timer "$duration" "Stretch"

    log_break "stretch" "$duration" "$activity"

    echo ""
    echo -e "${GREEN}Stretch complete!${NC}"
}

take_long_break() {
    local duration=$(get_config long_break)

    echo ""
    echo -e "${BOLD}${BLUE}=== Long Break Time ===${NC}"
    echo ""

    local activity=$(get_random_activity "long" LONG_BREAK_ACTIVITIES)
    echo -e "${CYAN}Suggested activity:${NC}"
    echo -e "  $activity"
    echo ""

    countdown_timer "$duration" "Long break"

    log_break "long" "$duration" "$activity"

    notify "Long break over!" "Ready to be productive again?"

    echo ""
    echo -e "${GREEN}Long break complete! You should feel refreshed.${NC}"
}

show_suggestion() {
    local type="${1:-random}"

    echo ""
    echo -e "${BOLD}${CYAN}=== Break Activity Suggestion ===${NC}"
    echo ""

    case "$type" in
        stretch|s)
            echo -e "${MAGENTA}Stretch:${NC}"
            echo "  $(get_random_activity "stretch" STRETCH_ACTIVITIES)"
            ;;
        short)
            echo -e "${GREEN}Short break:${NC}"
            echo "  $(get_random_activity "short" SHORT_BREAK_ACTIVITIES)"
            ;;
        long|l)
            echo -e "${BLUE}Long break:${NC}"
            echo "  $(get_random_activity "long" LONG_BREAK_ACTIVITIES)"
            ;;
        *)
            # Random type
            local types=("stretch" "short" "long")
            local rand_type=${types[$((RANDOM % 3))]}
            case "$rand_type" in
                stretch)
                    echo -e "${MAGENTA}Stretch suggestion:${NC}"
                    echo "  $(get_random_activity "stretch" STRETCH_ACTIVITIES)"
                    ;;
                short)
                    echo -e "${GREEN}Quick break suggestion:${NC}"
                    echo "  $(get_random_activity "short" SHORT_BREAK_ACTIVITIES)"
                    ;;
                long)
                    echo -e "${BLUE}Long break suggestion:${NC}"
                    echo "  $(get_random_activity "long" LONG_BREAK_ACTIVITIES)"
                    ;;
            esac
            ;;
    esac
    echo ""
}

show_history() {
    local date="${1:-$TODAY}"

    echo ""
    echo -e "${BOLD}${BLUE}=== Break History for $date ===${NC}"
    echo ""

    local breaks=$(grep "^$date" "$HISTORY_FILE" 2>/dev/null | tail -n +1)

    if [[ -z "$breaks" ]]; then
        echo "No breaks recorded for $date"
        echo ""
        echo -e "${YELLOW}Remember: Taking regular breaks improves focus and productivity!${NC}"
    else
        printf "  ${BOLD}%-10s %-10s %-8s %s${NC}\n" "Time" "Type" "Duration" "Activity"
        echo "  ────────────────────────────────────────────────────────"

        echo "$breaks" | while IFS=, read -r d time type duration activity; do
            activity=$(echo "$activity" | tr -d '"')
            printf "  %-10s %-10s %-8s %s\n" "$time" "$type" "${duration}m" "$activity"
        done

        echo ""

        # Summary
        local total_breaks=$(echo "$breaks" | wc -l)
        local total_minutes=$(echo "$breaks" | awk -F, '{sum += $4} END {print sum}')

        echo -e "${CYAN}Today's summary:${NC}"
        echo "  Total breaks: $total_breaks"
        echo "  Total break time: ${total_minutes:-0} minutes"
    fi
    echo ""
}

show_stats() {
    echo ""
    echo -e "${BOLD}${BLUE}=== Break Statistics ===${NC}"
    echo ""

    if [[ ! -s "$HISTORY_FILE" ]] || [[ $(wc -l < "$HISTORY_FILE") -le 1 ]]; then
        echo "No break data recorded yet."
        echo "Start taking breaks with: break-timer.sh break"
        return
    fi

    # Calculate stats
    local total_breaks=$(tail -n +2 "$HISTORY_FILE" | wc -l)
    local total_minutes=$(tail -n +2 "$HISTORY_FILE" | awk -F, '{sum += $4} END {print sum+0}')

    local stretch_count=$(grep ",stretch," "$HISTORY_FILE" | wc -l)
    local short_count=$(grep ",short," "$HISTORY_FILE" | wc -l)
    local long_count=$(grep ",long," "$HISTORY_FILE" | wc -l)

    local unique_days=$(tail -n +2 "$HISTORY_FILE" | cut -d, -f1 | sort -u | wc -l)

    echo -e "${CYAN}Overall:${NC}"
    echo "  Total breaks taken: $total_breaks"
    echo "  Total break time: $total_minutes minutes"
    echo "  Days with breaks: $unique_days"

    if [[ $unique_days -gt 0 ]]; then
        echo "  Average breaks/day: $((total_breaks / unique_days))"
        echo "  Average break time/day: $((total_minutes / unique_days)) minutes"
    fi

    echo ""
    echo -e "${CYAN}By type:${NC}"
    echo "  Stretch breaks: $stretch_count"
    echo "  Short breaks: $short_count"
    echo "  Long breaks: $long_count"

    echo ""

    # Today's stats
    local today_breaks=$(grep "^$TODAY" "$HISTORY_FILE" | wc -l)
    local today_minutes=$(grep "^$TODAY" "$HISTORY_FILE" | awk -F, '{sum += $4} END {print sum+0}')

    echo -e "${CYAN}Today:${NC}"
    echo "  Breaks taken: $today_breaks"
    echo "  Break time: $today_minutes minutes"

    # Health tip based on today's breaks
    echo ""
    if [[ $today_breaks -eq 0 ]]; then
        echo -e "${YELLOW}Tip: You haven't taken any breaks today. Time to step away!${NC}"
    elif [[ $today_breaks -lt 4 ]]; then
        echo -e "${YELLOW}Tip: Consider taking more frequent breaks for better focus.${NC}"
    else
        echo -e "${GREEN}Great job taking regular breaks today!${NC}"
    fi
    echo ""
}

configure() {
    echo ""
    echo -e "${BOLD}${BLUE}=== Break Timer Configuration ===${NC}"
    echo ""
    echo "Current settings:"
    echo "  Work interval: $(get_config work_interval) minutes"
    echo "  Short break: $(get_config short_break) minutes"
    echo "  Long break: $(get_config long_break) minutes"
    echo "  Stretch break: $(get_config stretch_break) minutes"
    echo "  Sound notifications: $(get_config notify_sound)"
    echo "  Show suggestions: $(get_config show_suggestion)"
    echo ""
    echo "To modify, edit: $CONFIG_FILE"
    echo ""
    echo "Or use:"
    echo "  break-timer.sh config set work_interval 45"
    echo "  break-timer.sh config set short_break 10"
}

set_config() {
    local key="$1"
    local value="$2"

    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
        echo "Usage: break-timer.sh config set <key> <value>"
        echo ""
        echo "Keys: work_interval, short_break, long_break, stretch_break,"
        echo "      notify_sound (true/false), show_suggestion (true/false)"
        exit 1
    fi

    # Validate key
    local valid_keys="work_interval short_break long_break stretch_break notify_sound show_suggestion"
    if ! echo "$valid_keys" | grep -q "$key"; then
        echo "Unknown key: $key"
        echo "Valid keys: $valid_keys"
        exit 1
    fi

    # Update config
    if [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
        jq ".$key = $value" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        jq ".$key = $value" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi

    echo -e "${GREEN}Updated $key to $value${NC}"
}

show_help() {
    echo "Break Timer - Smart break reminders with healthy activity suggestions"
    echo ""
    echo "Usage:"
    echo "  break-timer.sh start [mins]    Start reminder timer (default: 50 min)"
    echo "  break-timer.sh stop            Stop the reminder timer"
    echo "  break-timer.sh break [mins]    Take a break now (default: 5 min)"
    echo "  break-timer.sh long            Take a long break (15 min)"
    echo "  break-timer.sh stretch         Quick stretch break (2 min)"
    echo "  break-timer.sh suggest [type]  Get activity suggestion (stretch/short/long)"
    echo "  break-timer.sh history [date]  Show break history"
    echo "  break-timer.sh stats           Show break statistics"
    echo "  break-timer.sh config          View configuration"
    echo "  break-timer.sh config set K V  Update configuration"
    echo "  break-timer.sh help            Show this help"
    echo ""
    echo "Examples:"
    echo "  break-timer.sh start           # Remind every 50 minutes"
    echo "  break-timer.sh start 30        # Remind every 30 minutes"
    echo "  break-timer.sh break           # Take a 5-minute break"
    echo "  break-timer.sh break 10        # Take a 10-minute break"
    echo "  break-timer.sh suggest stretch # Get a stretch suggestion"
}

case "$1" in
    start)
        start_reminder "$2"
        ;;
    stop)
        stop_reminder
        ;;
    break|b)
        take_break "$2"
        ;;
    long|l)
        take_long_break
        ;;
    stretch|s)
        take_stretch
        ;;
    suggest|idea)
        show_suggestion "$2"
        ;;
    history|h)
        show_history "$2"
        ;;
    stats|st)
        show_stats
        ;;
    config|configure|c)
        if [[ "$2" == "set" ]]; then
            set_config "$3" "$4"
        else
            configure
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        # Check if it's a number (duration for break)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            take_break "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'break-timer.sh help' for usage"
            exit 1
        fi
        ;;
esac
