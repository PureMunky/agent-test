#!/bin/bash
#
# Time Log - Track time spent on projects and activities
#
# Usage:
#   timelog.sh start "project" ["description"]  - Start timing a project
#   timelog.sh stop                             - Stop current timer
#   timelog.sh status                           - Show current timer
#   timelog.sh log "project" <minutes> ["desc"] - Log time manually
#   timelog.sh report [days]                    - Show time report (default: 7 days)
#   timelog.sh today                            - Show today's time
#   timelog.sh projects                         - List all projects
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_FILE="$DATA_DIR/timelog.csv"
ACTIVE_FILE="$DATA_DIR/active.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize log file with header if it doesn't exist
if [[ ! -f "$LOG_FILE" ]]; then
    echo "date,project,minutes,description,start_time,end_time" > "$LOG_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

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

start_timer() {
    local project="$1"
    local description="${2:-}"

    if [[ -z "$project" ]]; then
        echo "Usage: timelog.sh start \"project\" [\"description\"]"
        exit 1
    fi

    # Check if there's already an active timer
    if [[ -f "$ACTIVE_FILE" ]]; then
        local active_project=$(cat "$ACTIVE_FILE" | grep -oP '"project":\s*"\K[^"]+')
        echo -e "${YELLOW}Timer already running for: $active_project${NC}"
        echo "Stop it first with: timelog.sh stop"
        exit 1
    fi

    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local start_epoch=$(date +%s)

    cat > "$ACTIVE_FILE" << EOF
{
    "project": "$project",
    "description": "$description",
    "start_time": "$start_time",
    "start_epoch": $start_epoch
}
EOF

    echo -e "${GREEN}Started timer for:${NC} $project"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
    echo -e "${CYAN}Started at:${NC} $start_time"
}

stop_timer() {
    if [[ ! -f "$ACTIVE_FILE" ]]; then
        echo -e "${YELLOW}No active timer to stop.${NC}"
        exit 0
    fi

    local project=$(grep -oP '"project":\s*"\K[^"]+' "$ACTIVE_FILE")
    local description=$(grep -oP '"description":\s*"\K[^"]*' "$ACTIVE_FILE")
    local start_time=$(grep -oP '"start_time":\s*"\K[^"]+' "$ACTIVE_FILE")
    local start_epoch=$(grep -oP '"start_epoch":\s*\K[0-9]+' "$ACTIVE_FILE")

    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local end_epoch=$(date +%s)
    local duration_seconds=$((end_epoch - start_epoch))
    local duration_minutes=$(( (duration_seconds + 30) / 60 ))  # Round to nearest minute

    # Minimum 1 minute
    if [[ $duration_minutes -lt 1 ]]; then
        duration_minutes=1
    fi

    # Escape description for CSV (replace commas and quotes)
    local safe_desc=$(echo "$description" | sed 's/"/""/g')

    # Log to CSV
    echo "$TODAY,\"$project\",$duration_minutes,\"$safe_desc\",\"$start_time\",\"$end_time\"" >> "$LOG_FILE"

    # Remove active file
    rm "$ACTIVE_FILE"

    echo -e "${GREEN}Stopped timer for:${NC} $project"
    echo -e "${CYAN}Duration:${NC} $(format_duration $duration_minutes)"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
}

show_status() {
    if [[ ! -f "$ACTIVE_FILE" ]]; then
        echo -e "${BLUE}No active timer.${NC}"
        echo "Start one with: timelog.sh start \"project\""
        exit 0
    fi

    local project=$(grep -oP '"project":\s*"\K[^"]+' "$ACTIVE_FILE")
    local description=$(grep -oP '"description":\s*"\K[^"]*' "$ACTIVE_FILE")
    local start_time=$(grep -oP '"start_time":\s*"\K[^"]+' "$ACTIVE_FILE")
    local start_epoch=$(grep -oP '"start_epoch":\s*\K[0-9]+' "$ACTIVE_FILE")

    local now_epoch=$(date +%s)
    local elapsed_seconds=$((now_epoch - start_epoch))
    local elapsed_minutes=$((elapsed_seconds / 60))

    echo -e "${BLUE}=== Active Timer ===${NC}"
    echo ""
    echo -e "${GREEN}Project:${NC} $project"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
    echo -e "${CYAN}Started:${NC} $start_time"
    echo -e "${YELLOW}Elapsed:${NC} $(format_duration $elapsed_minutes)"
}

log_manual() {
    local project="$1"
    local minutes="$2"
    local description="${3:-}"

    if [[ -z "$project" ]] || [[ -z "$minutes" ]]; then
        echo "Usage: timelog.sh log \"project\" <minutes> [\"description\"]"
        exit 1
    fi

    # Validate minutes is a number
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: minutes must be a positive number${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local safe_desc=$(echo "$description" | sed 's/"/""/g')

    echo "$TODAY,\"$project\",$minutes,\"$safe_desc\",\"$timestamp\",\"$timestamp\"" >> "$LOG_FILE"

    echo -e "${GREEN}Logged:${NC} $(format_duration $minutes) for $project"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
}

show_report() {
    local days=${1:-7}
    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)

    echo -e "${BLUE}=== Time Report (Last $days days) ===${NC}"
    echo ""

    # Check if we have any data
    local line_count=$(tail -n +2 "$LOG_FILE" | wc -l)
    if [[ $line_count -eq 0 ]]; then
        echo "No time logged yet."
        echo "Start tracking with: timelog.sh start \"project\""
        exit 0
    fi

    # Calculate totals per project
    echo -e "${YELLOW}Time by Project:${NC}"
    echo ""

    local total_minutes=0

    # Get unique projects and their totals
    tail -n +2 "$LOG_FILE" | while IFS=, read -r date project minutes rest; do
        # Remove quotes from project
        project=$(echo "$project" | tr -d '"')
        echo "$date $project $minutes"
    done | awk -v cutoff="$cutoff_date" '
        $1 >= cutoff {
            projects[$2] += $3
            total += $3
        }
        END {
            # Sort by time descending
            n = asorti(projects, sorted)
            for (i = 1; i <= n; i++) {
                p = sorted[i]
                mins = projects[p]
                hours = int(mins / 60)
                remaining = mins % 60
                if (hours > 0) {
                    printf "  %-20s %dh %dm\n", p, hours, remaining
                } else {
                    printf "  %-20s %dm\n", p, remaining
                }
            }
            print ""
            hours = int(total / 60)
            remaining = total % 60
            if (hours > 0) {
                printf "  TOTAL: %dh %dm\n", hours, remaining
            } else {
                printf "  TOTAL: %dm\n", remaining
            }
        }
    '

    echo ""
    echo -e "${YELLOW}Daily Breakdown:${NC}"
    echo ""

    tail -n +2 "$LOG_FILE" | while IFS=, read -r date project minutes rest; do
        project=$(echo "$project" | tr -d '"')
        echo "$date $minutes"
    done | awk -v cutoff="$cutoff_date" '
        $1 >= cutoff {
            days[$1] += $2
        }
        END {
            n = asorti(days, sorted)
            for (i = n; i >= 1 && i > n-7; i--) {
                d = sorted[i]
                mins = days[d]
                hours = int(mins / 60)
                remaining = mins % 60
                if (hours > 0) {
                    printf "  %s: %dh %dm\n", d, hours, remaining
                } else {
                    printf "  %s: %dm\n", d, remaining
                }
            }
        }
    '
}

show_today() {
    echo -e "${BLUE}=== Today's Time ($TODAY) ===${NC}"
    echo ""

    local today_entries=$(grep "^$TODAY" "$LOG_FILE")

    if [[ -z "$today_entries" ]]; then
        echo "No time logged today."

        # Check for active timer
        if [[ -f "$ACTIVE_FILE" ]]; then
            echo ""
            show_status
        fi
        exit 0
    fi

    local total=0

    echo "$today_entries" | while IFS=, read -r date project minutes desc start end; do
        project=$(echo "$project" | tr -d '"')
        desc=$(echo "$desc" | tr -d '"')
        total=$((total + minutes))

        if [[ -n "$desc" ]]; then
            echo -e "  ${GREEN}$project${NC} - $(format_duration $minutes) - $desc"
        else
            echo -e "  ${GREEN}$project${NC} - $(format_duration $minutes)"
        fi
    done

    echo ""

    # Calculate total
    local day_total=$(echo "$today_entries" | awk -F, '{sum += $3} END {print sum}')
    echo -e "${CYAN}Total today:${NC} $(format_duration $day_total)"

    # Show active timer if any
    if [[ -f "$ACTIVE_FILE" ]]; then
        echo ""
        show_status
    fi
}

list_projects() {
    echo -e "${BLUE}=== Projects ===${NC}"
    echo ""

    local projects=$(tail -n +2 "$LOG_FILE" | cut -d, -f2 | tr -d '"' | sort -u)

    if [[ -z "$projects" ]]; then
        echo "No projects yet."
        exit 0
    fi

    echo "$projects" | while read project; do
        local total=$(grep "\"$project\"" "$LOG_FILE" | awk -F, '{sum += $3} END {print sum}')
        echo -e "  ${GREEN}$project${NC} - $(format_duration $total) total"
    done
}

show_help() {
    echo "Time Log - Track time spent on projects and activities"
    echo ""
    echo "Usage:"
    echo "  timelog.sh start \"project\" [\"desc\"]  Start timing a project"
    echo "  timelog.sh stop                       Stop current timer"
    echo "  timelog.sh status                     Show current timer"
    echo "  timelog.sh log \"project\" <min> [desc] Log time manually"
    echo "  timelog.sh report [days]              Show report (default: 7 days)"
    echo "  timelog.sh today                      Show today's time"
    echo "  timelog.sh projects                   List all projects"
    echo "  timelog.sh help                       Show this help"
    echo ""
    echo "Examples:"
    echo "  timelog.sh start \"coding\" \"Working on feature X\""
    echo "  timelog.sh stop"
    echo "  timelog.sh log \"meeting\" 30 \"Team standup\""
    echo "  timelog.sh report 30"
}

case "$1" in
    start)
        shift
        start_timer "$@"
        ;;
    stop)
        stop_timer
        ;;
    status|st)
        show_status
        ;;
    log|add)
        shift
        log_manual "$@"
        ;;
    report|rep)
        show_report "$2"
        ;;
    today|td)
        show_today
        ;;
    projects|proj)
        list_projects
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_today
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'timelog.sh help' for usage"
        exit 1
        ;;
esac
