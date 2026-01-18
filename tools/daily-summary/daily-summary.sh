#!/bin/bash
#
# Daily Summary - Aggregate productivity data from all tools
#
# Usage:
#   daily-summary.sh              - Show today's summary
#   daily-summary.sh today        - Show today's summary
#   daily-summary.sh yesterday    - Show yesterday's summary
#   daily-summary.sh week         - Show this week's summary
#   daily-summary.sh date <date>  - Show summary for specific date
#   daily-summary.sh range <from> <to> - Show summary for date range
#   daily-summary.sh goals        - Manage daily goals
#   daily-summary.sh goals set <pomodoros> <hours> <tasks> <habits%>
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/data"
GOALS_FILE="$DATA_DIR/goals.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize goals file with defaults
if [[ ! -f "$GOALS_FILE" ]]; then
    cat > "$GOALS_FILE" << 'EOF'
{
    "pomodoros": 8,
    "hours": 6,
    "tasks": 5,
    "habits_percent": 80
}
EOF
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

format_duration() {
    local minutes=$1
    local hours=$((minutes / 60))
    local mins=$((minutes % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm" $hours $mins
    else
        printf "%dm" $mins
    fi
}

get_pomodoro_count() {
    local date="$1"
    local log_file="$SUITE_DIR/pomodoro/data/pomodoro_log.txt"

    if [[ -f "$log_file" ]]; then
        grep "^$date" "$log_file" 2>/dev/null | wc -l
    else
        echo 0
    fi
}

get_time_logged() {
    local date="$1"
    local log_file="$SUITE_DIR/timelog/data/timelog.csv"

    if [[ -f "$log_file" ]]; then
        grep "^$date" "$log_file" 2>/dev/null | awk -F, '{sum += $3} END {print sum+0}'
    else
        echo 0
    fi
}

get_time_projects() {
    local date="$1"
    local log_file="$SUITE_DIR/timelog/data/timelog.csv"

    if [[ -f "$log_file" ]]; then
        grep "^$date" "$log_file" 2>/dev/null | while IFS=, read -r d project minutes rest; do
            project=$(echo "$project" | tr -d '"')
            echo "$project:$minutes"
        done
    fi
}

get_tasks_completed() {
    local date="$1"
    local tasks_file="$SUITE_DIR/tasks/data/tasks.json"

    if [[ -f "$tasks_file" ]]; then
        jq -r --arg date "$date" '
            .tasks | map(select(.completed == true and (.completed_at | startswith($date)))) | length
        ' "$tasks_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

get_tasks_added() {
    local date="$1"
    local tasks_file="$SUITE_DIR/tasks/data/tasks.json"

    if [[ -f "$tasks_file" ]]; then
        jq -r --arg date "$date" '
            .tasks | map(select(.created | startswith($date))) | length
        ' "$tasks_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

get_habits_status() {
    local date="$1"
    local habits_file="$SUITE_DIR/habits/data/habits.json"

    if [[ -f "$habits_file" ]]; then
        local total=$(jq -r '.habits | length' "$habits_file" 2>/dev/null || echo 0)
        local done=0

        if [[ $total -gt 0 ]]; then
            done=$(jq -r --arg date "$date" '
                [.habits[] as $h | if .completions[$h] != null and (.completions[$h] | index($date)) != null then 1 else 0 end] | add // 0
            ' "$habits_file" 2>/dev/null || echo 0)
        fi

        echo "$done:$total"
    else
        echo "0:0"
    fi
}

get_notes_count() {
    local date="$1"
    local notes_file="$SUITE_DIR/quicknotes/data/notes.txt"

    if [[ -f "$notes_file" ]]; then
        grep "^\[$date" "$notes_file" 2>/dev/null | wc -l
    else
        echo 0
    fi
}

get_bookmarks_added() {
    local date="$1"
    local bookmarks_file="$SUITE_DIR/bookmarks/data/bookmarks.json"

    if [[ -f "$bookmarks_file" ]]; then
        jq -r --arg date "$date" '
            .bookmarks | map(select(.added | startswith($date))) | length
        ' "$bookmarks_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

progress_bar() {
    local current=$1
    local goal=$2
    local width=${3:-20}

    if [[ $goal -eq 0 ]]; then
        printf "[%${width}s]" ""
        return
    fi

    local percent=$((current * 100 / goal))
    if [[ $percent -gt 100 ]]; then
        percent=100
    fi

    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    if [[ $percent -ge 100 ]]; then
        printf "${GREEN}[%s]${NC}" "$bar"
    elif [[ $percent -ge 50 ]]; then
        printf "${YELLOW}[%s]${NC}" "$bar"
    else
        printf "${RED}[%s]${NC}" "$bar"
    fi
}

show_daily_summary() {
    local date="${1:-$TODAY}"
    local date_display=$(date -d "$date" "+%A, %B %d, %Y" 2>/dev/null || date -jf "%Y-%m-%d" "$date" "+%A, %B %d, %Y" 2>/dev/null || echo "$date")

    # Load goals
    local goal_pomodoros=$(jq -r '.pomodoros' "$GOALS_FILE")
    local goal_hours=$(jq -r '.hours' "$GOALS_FILE")
    local goal_tasks=$(jq -r '.tasks' "$GOALS_FILE")
    local goal_habits_pct=$(jq -r '.habits_percent' "$GOALS_FILE")

    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}          ${BOLD}DAILY PRODUCTIVITY SUMMARY${NC}                       ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}║${NC}          ${CYAN}$date_display${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Pomodoro Stats
    local pomodoros=$(get_pomodoro_count "$date")
    echo -e "${MAGENTA}🍅 POMODORO SESSIONS${NC}"
    echo -n "   Completed: $pomodoros / $goal_pomodoros  "
    progress_bar $pomodoros $goal_pomodoros
    echo ""
    echo ""

    # Time Tracking
    local total_minutes=$(get_time_logged "$date")
    local goal_minutes=$((goal_hours * 60))
    echo -e "${CYAN}⏱️  TIME TRACKED${NC}"
    echo -n "   Logged: $(format_duration $total_minutes) / ${goal_hours}h  "
    progress_bar $total_minutes $goal_minutes
    echo ""

    # Show project breakdown
    local projects=$(get_time_projects "$date")
    if [[ -n "$projects" ]]; then
        echo "   ${GRAY}Projects:${NC}"
        echo "$projects" | sort | uniq | while IFS=: read -r proj mins; do
            if [[ -n "$proj" ]] && [[ -n "$mins" ]]; then
                printf "     %-20s %s\n" "$proj" "$(format_duration $mins)"
            fi
        done
    fi
    echo ""

    # Tasks
    local tasks_done=$(get_tasks_completed "$date")
    local tasks_added=$(get_tasks_added "$date")
    echo -e "${GREEN}✓ TASKS${NC}"
    echo -n "   Completed: $tasks_done / $goal_tasks  "
    progress_bar $tasks_done $goal_tasks
    echo ""
    echo "   ${GRAY}Added: $tasks_added${NC}"
    echo ""

    # Habits
    local habits_status=$(get_habits_status "$date")
    local habits_done=$(echo "$habits_status" | cut -d: -f1)
    local habits_total=$(echo "$habits_status" | cut -d: -f2)
    local habits_pct=0
    if [[ $habits_total -gt 0 ]]; then
        habits_pct=$((habits_done * 100 / habits_total))
    fi

    echo -e "${YELLOW}📊 HABITS${NC}"
    echo -n "   Completed: $habits_done / $habits_total ($habits_pct%)  "
    local habit_goal=$((habits_total * goal_habits_pct / 100))
    progress_bar $habits_done $habit_goal
    echo ""
    echo ""

    # Quick Notes
    local notes=$(get_notes_count "$date")
    echo -e "${BLUE}📝 NOTES & BOOKMARKS${NC}"
    echo "   Notes captured: $notes"

    local bookmarks=$(get_bookmarks_added "$date")
    echo "   Bookmarks added: $bookmarks"
    echo ""

    # Overall score
    local score=0
    local max_score=4

    if [[ $pomodoros -ge $goal_pomodoros ]]; then score=$((score + 1)); fi
    if [[ $total_minutes -ge $goal_minutes ]]; then score=$((score + 1)); fi
    if [[ $tasks_done -ge $goal_tasks ]]; then score=$((score + 1)); fi
    if [[ $habits_pct -ge $goal_habits_pct ]]; then score=$((score + 1)); fi

    echo -e "${BOLD}${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo ""

    local stars=""
    for ((i=0; i<score; i++)); do
        stars+="★ "
    done
    for ((i=score; i<max_score; i++)); do
        stars+="☆ "
    done

    local verdict=""
    case $score in
        4) verdict="${GREEN}EXCELLENT! All goals met!${NC}" ;;
        3) verdict="${GREEN}Great job! Almost perfect!${NC}" ;;
        2) verdict="${YELLOW}Good progress. Keep going!${NC}" ;;
        1) verdict="${YELLOW}Some progress made.${NC}" ;;
        0) verdict="${RED}Start fresh tomorrow!${NC}" ;;
    esac

    echo -e "   ${BOLD}DAILY SCORE:${NC} $stars ($score/$max_score goals)"
    echo -e "   $verdict"
    echo ""
}

show_week_summary() {
    local end_date="${1:-$TODAY}"

    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}            ${BOLD}WEEKLY PRODUCTIVITY SUMMARY${NC}                     ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total_pomodoros=0
    local total_minutes=0
    local total_tasks=0
    local total_habits_done=0
    local total_habits_possible=0
    local total_notes=0

    # Table header
    printf "  ${BOLD}%-12s %8s %10s %8s %8s${NC}\n" "Date" "Pomodoro" "Time" "Tasks" "Habits"
    echo "  ─────────────────────────────────────────────────────"

    for ((i=6; i>=0; i--)); do
        local date=$(date -d "$end_date - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local day_name=$(date -d "$date" +%a 2>/dev/null || date -jf "%Y-%m-%d" "$date" +%a 2>/dev/null)

        local pomodoros=$(get_pomodoro_count "$date")
        local minutes=$(get_time_logged "$date")
        local tasks=$(get_tasks_completed "$date")
        local habits_status=$(get_habits_status "$date")
        local habits_done=$(echo "$habits_status" | cut -d: -f1)
        local habits_total=$(echo "$habits_status" | cut -d: -f2)

        total_pomodoros=$((total_pomodoros + pomodoros))
        total_minutes=$((total_minutes + minutes))
        total_tasks=$((total_tasks + tasks))
        total_habits_done=$((total_habits_done + habits_done))
        total_habits_possible=$((total_habits_possible + habits_total))

        local habits_display=""
        if [[ $habits_total -gt 0 ]]; then
            habits_display="$habits_done/$habits_total"
        else
            habits_display="-"
        fi

        local time_display=$(format_duration $minutes)

        # Highlight today
        if [[ "$date" == "$TODAY" ]]; then
            printf "  ${GREEN}%-12s${NC} %8s %10s %8s %8s\n" "$day_name $date" "$pomodoros" "$time_display" "$tasks" "$habits_display"
        else
            printf "  %-12s %8s %10s %8s %8s\n" "$day_name ${date:5}" "$pomodoros" "$time_display" "$tasks" "$habits_display"
        fi
    done

    echo "  ─────────────────────────────────────────────────────"

    local habits_avg=""
    if [[ $total_habits_possible -gt 0 ]]; then
        local pct=$((total_habits_done * 100 / total_habits_possible))
        habits_avg="${pct}%"
    else
        habits_avg="-"
    fi

    printf "  ${BOLD}%-12s %8s %10s %8s %8s${NC}\n" "TOTAL" "$total_pomodoros" "$(format_duration $total_minutes)" "$total_tasks" "$habits_avg"
    echo ""

    # Weekly averages
    echo -e "${CYAN}Weekly Averages:${NC}"
    echo "   Pomodoros/day: $((total_pomodoros / 7))"
    echo "   Time/day: $(format_duration $((total_minutes / 7)))"
    echo "   Tasks/day: $((total_tasks / 7))"
    echo ""
}

show_range_summary() {
    local from_date="$1"
    local to_date="$2"

    if [[ -z "$from_date" ]] || [[ -z "$to_date" ]]; then
        echo "Usage: daily-summary.sh range <from-date> <to-date>"
        echo "Example: daily-summary.sh range 2026-01-01 2026-01-15"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Summary: $from_date to $to_date${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    local total_pomodoros=0
    local total_minutes=0
    local total_tasks=0
    local total_habits_done=0
    local total_habits_possible=0
    local day_count=0

    local current="$from_date"
    while [[ "$current" < "$to_date" ]] || [[ "$current" == "$to_date" ]]; do
        local pomodoros=$(get_pomodoro_count "$current")
        local minutes=$(get_time_logged "$current")
        local tasks=$(get_tasks_completed "$current")
        local habits_status=$(get_habits_status "$current")
        local habits_done=$(echo "$habits_status" | cut -d: -f1)
        local habits_total=$(echo "$habits_status" | cut -d: -f2)

        total_pomodoros=$((total_pomodoros + pomodoros))
        total_minutes=$((total_minutes + minutes))
        total_tasks=$((total_tasks + tasks))
        total_habits_done=$((total_habits_done + habits_done))
        total_habits_possible=$((total_habits_possible + habits_total))
        day_count=$((day_count + 1))

        current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -jf "%Y-%m-%d" "$current" +%Y-%m-%d 2>/dev/null)
    done

    local habits_pct=0
    if [[ $total_habits_possible -gt 0 ]]; then
        habits_pct=$((total_habits_done * 100 / total_habits_possible))
    fi

    echo -e "${MAGENTA}Period Statistics ($day_count days):${NC}"
    echo ""
    echo "   Pomodoro sessions:  $total_pomodoros (avg: $((total_pomodoros / day_count))/day)"
    echo "   Time tracked:       $(format_duration $total_minutes) (avg: $(format_duration $((total_minutes / day_count)))/day)"
    echo "   Tasks completed:    $total_tasks (avg: $((total_tasks / day_count))/day)"
    echo "   Habit completion:   ${habits_pct}% ($total_habits_done/$total_habits_possible)"
    echo ""
}

manage_goals() {
    local action="$1"

    if [[ "$action" == "set" ]]; then
        local pomodoros="${2:-8}"
        local hours="${3:-6}"
        local tasks="${4:-5}"
        local habits_pct="${5:-80}"

        cat > "$GOALS_FILE" << EOF
{
    "pomodoros": $pomodoros,
    "hours": $hours,
    "tasks": $tasks,
    "habits_percent": $habits_pct
}
EOF

        echo -e "${GREEN}Goals updated:${NC}"
        echo "   Pomodoros/day: $pomodoros"
        echo "   Hours/day: $hours"
        echo "   Tasks/day: $tasks"
        echo "   Habits completion: ${habits_pct}%"
    else
        echo -e "${BLUE}Current Goals:${NC}"
        echo ""
        echo "   Pomodoros/day: $(jq -r '.pomodoros' "$GOALS_FILE")"
        echo "   Hours/day: $(jq -r '.hours' "$GOALS_FILE")"
        echo "   Tasks/day: $(jq -r '.tasks' "$GOALS_FILE")"
        echo "   Habits completion: $(jq -r '.habits_percent' "$GOALS_FILE")%"
        echo ""
        echo "Set new goals with: daily-summary.sh goals set <pomodoros> <hours> <tasks> <habits%>"
    fi
}

show_help() {
    echo "Daily Summary - Aggregate productivity data from all tools"
    echo ""
    echo "Usage:"
    echo "  daily-summary.sh              Show today's summary"
    echo "  daily-summary.sh today        Show today's summary"
    echo "  daily-summary.sh yesterday    Show yesterday's summary"
    echo "  daily-summary.sh week         Show this week's summary"
    echo "  daily-summary.sh date <date>  Show summary for specific date"
    echo "  daily-summary.sh range <from> <to>  Show summary for date range"
    echo "  daily-summary.sh goals        View current goals"
    echo "  daily-summary.sh goals set <pomodoros> <hours> <tasks> <habits%>"
    echo "  daily-summary.sh help         Show this help"
    echo ""
    echo "This tool aggregates data from:"
    echo "  - Pomodoro timer sessions"
    echo "  - Time tracking logs"
    echo "  - Completed tasks"
    echo "  - Habit completions"
    echo "  - Quick notes"
    echo "  - Bookmarks"
    echo ""
    echo "Examples:"
    echo "  daily-summary.sh"
    echo "  daily-summary.sh date 2026-01-15"
    echo "  daily-summary.sh range 2026-01-01 2026-01-15"
    echo "  daily-summary.sh goals set 10 8 6 90"
}

case "$1" in
    today|"")
        show_daily_summary "$TODAY"
        ;;
    yesterday|yd)
        local yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
        show_daily_summary "$yesterday"
        ;;
    week|wk)
        show_week_summary "$TODAY"
        ;;
    date|d)
        show_daily_summary "$2"
        ;;
    range|r)
        show_range_summary "$2" "$3"
        ;;
    goals|g)
        shift
        manage_goals "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        # Try to parse as a date
        if date -d "$1" &>/dev/null; then
            show_daily_summary "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'daily-summary.sh help' for usage"
            exit 1
        fi
        ;;
esac
