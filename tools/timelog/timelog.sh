#!/bin/bash
#
# Time Log v2.0 - Enhanced time tracking for projects and activities
#
# New in v2.0:
#   - Pause/resume active timers
#   - Billable hours tracking with hourly rates
#   - Tags for categorization (#tag in description)
#   - Weekly summary with detailed statistics
#   - Edit and delete time entries
#   - Export to JSON format
#   - Filter by project, tag, or date range
#
# Usage:
#   timelog.sh start "project" ["description"]  - Start timing a project
#   timelog.sh stop                             - Stop current timer
#   timelog.sh pause                            - Pause current timer
#   timelog.sh resume                           - Resume paused timer
#   timelog.sh status                           - Show current timer
#   timelog.sh log "project" <minutes> ["desc"] - Log time manually
#   timelog.sh edit <id> [field] [value]        - Edit a time entry
#   timelog.sh delete <id>                      - Delete a time entry
#   timelog.sh report [days]                    - Show time report
#   timelog.sh week                             - Show weekly summary
#   timelog.sh today                            - Show today's time
#   timelog.sh projects                         - List all projects
#   timelog.sh rate "project" <hourly-rate>     - Set billable rate
#   timelog.sh billable [days]                  - Show billable summary
#   timelog.sh tags                             - List all tags
#   timelog.sh filter --project|--tag|--date   - Filter entries
#   timelog.sh export [format]                  - Export data (json/csv)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_FILE="$DATA_DIR/timelog.csv"
ACTIVE_FILE="$DATA_DIR/active.json"
RATES_FILE="$DATA_DIR/rates.json"
CONFIG_FILE="$DATA_DIR/config.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize log file with header if it doesn't exist
if [[ ! -f "$LOG_FILE" ]]; then
    echo "id,date,project,minutes,description,start_time,end_time,billable" > "$LOG_FILE"
fi

# Initialize rates file
if [[ ! -f "$RATES_FILE" ]]; then
    echo '{}' > "$RATES_FILE"
fi

# Initialize config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"default_billable": false, "next_id": 1}' > "$CONFIG_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Get next ID from config
get_next_id() {
    local next_id=$(grep -oP '"next_id":\s*\K[0-9]+' "$CONFIG_FILE" 2>/dev/null || echo "1")
    echo "$next_id"
}

# Increment next ID
increment_id() {
    local current=$(get_next_id)
    local next=$((current + 1))
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/\"next_id\":\s*[0-9]*/\"next_id\": $next/" "$CONFIG_FILE"
    fi
    echo "$current"
}

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

format_duration_decimal() {
    local minutes=$1
    local hours=$(echo "scale=2; $minutes / 60" | bc)
    printf "%.2f" $hours
}

# Extract tags from description (words starting with #)
extract_tags() {
    local desc="$1"
    echo "$desc" | grep -oP '#\w+' | tr '\n' ' ' | sed 's/ $//'
}

start_timer() {
    local project="$1"
    local description="${2:-}"
    local billable="${3:-false}"

    if [[ -z "$project" ]]; then
        echo "Usage: timelog.sh start \"project\" [\"description\"] [--billable]"
        exit 1
    fi

    # Check for billable flag
    if [[ "$description" == "--billable" ]]; then
        billable="true"
        description=""
    elif [[ "$3" == "--billable" ]]; then
        billable="true"
    fi

    # Check if there's already an active timer
    if [[ -f "$ACTIVE_FILE" ]]; then
        local active_project=$(grep -oP '"project":\s*"\K[^"]+' "$ACTIVE_FILE")
        local state=$(grep -oP '"state":\s*"\K[^"]+' "$ACTIVE_FILE" 2>/dev/null || echo "running")

        if [[ "$state" == "paused" ]]; then
            echo -e "${YELLOW}Timer is paused for: $active_project${NC}"
            echo "Resume it with: timelog.sh resume"
            echo "Or stop it first: timelog.sh stop"
        else
            echo -e "${YELLOW}Timer already running for: $active_project${NC}"
            echo "Stop it first with: timelog.sh stop"
        fi
        exit 1
    fi

    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local start_epoch=$(date +%s)

    cat > "$ACTIVE_FILE" << EOF
{
    "project": "$project",
    "description": "$description",
    "start_time": "$start_time",
    "start_epoch": $start_epoch,
    "accumulated_seconds": 0,
    "state": "running",
    "billable": $billable
}
EOF

    echo -e "${GREEN}▶ Started timer for:${NC} ${BOLD}$project${NC}"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}  Description:${NC} $description"
    fi
    echo -e "${CYAN}  Started at:${NC} $start_time"
    if [[ "$billable" == "true" ]]; then
        local rate=$(grep -oP "\"$project\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)
        if [[ -n "$rate" ]]; then
            echo -e "${GREEN}  💰 Billable${NC} @ \$$rate/hr"
        else
            echo -e "${GREEN}  💰 Billable${NC} (no rate set)"
        fi
    fi
}

pause_timer() {
    if [[ ! -f "$ACTIVE_FILE" ]]; then
        echo -e "${YELLOW}No active timer to pause.${NC}"
        exit 0
    fi

    local state=$(grep -oP '"state":\s*"\K[^"]+' "$ACTIVE_FILE" 2>/dev/null || echo "running")
    if [[ "$state" == "paused" ]]; then
        echo -e "${YELLOW}Timer is already paused.${NC}"
        exit 0
    fi

    local project=$(grep -oP '"project":\s*"\K[^"]+' "$ACTIVE_FILE")
    local start_epoch=$(grep -oP '"start_epoch":\s*\K[0-9]+' "$ACTIVE_FILE")
    local accumulated=$(grep -oP '"accumulated_seconds":\s*\K[0-9]+' "$ACTIVE_FILE" 2>/dev/null || echo "0")

    local now_epoch=$(date +%s)
    local session_seconds=$((now_epoch - start_epoch))
    local new_accumulated=$((accumulated + session_seconds))

    # Update state to paused
    sed -i 's/"state":\s*"running"/"state": "paused"/' "$ACTIVE_FILE"
    sed -i "s/\"accumulated_seconds\":\s*[0-9]*/\"accumulated_seconds\": $new_accumulated/" "$ACTIVE_FILE"

    local pause_time=$(date '+%H:%M:%S')
    local elapsed_minutes=$((new_accumulated / 60))

    echo -e "${YELLOW}⏸ Paused timer for:${NC} ${BOLD}$project${NC}"
    echo -e "${CYAN}  Paused at:${NC} $pause_time"
    echo -e "${CYAN}  Elapsed:${NC} $(format_duration $elapsed_minutes)"
}

resume_timer() {
    if [[ ! -f "$ACTIVE_FILE" ]]; then
        echo -e "${YELLOW}No timer to resume.${NC}"
        exit 0
    fi

    local state=$(grep -oP '"state":\s*"\K[^"]+' "$ACTIVE_FILE" 2>/dev/null || echo "running")
    if [[ "$state" == "running" ]]; then
        echo -e "${YELLOW}Timer is already running.${NC}"
        exit 0
    fi

    local project=$(grep -oP '"project":\s*"\K[^"]+' "$ACTIVE_FILE")
    local accumulated=$(grep -oP '"accumulated_seconds":\s*\K[0-9]+' "$ACTIVE_FILE" 2>/dev/null || echo "0")

    # Reset start_epoch to now and update state
    local now_epoch=$(date +%s)
    sed -i 's/"state":\s*"paused"/"state": "running"/' "$ACTIVE_FILE"
    sed -i "s/\"start_epoch\":\s*[0-9]*/\"start_epoch\": $now_epoch/" "$ACTIVE_FILE"

    local resume_time=$(date '+%H:%M:%S')
    local elapsed_minutes=$((accumulated / 60))

    echo -e "${GREEN}▶ Resumed timer for:${NC} ${BOLD}$project${NC}"
    echo -e "${CYAN}  Resumed at:${NC} $resume_time"
    echo -e "${CYAN}  Previously logged:${NC} $(format_duration $elapsed_minutes)"
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
    local accumulated=$(grep -oP '"accumulated_seconds":\s*\K[0-9]+' "$ACTIVE_FILE" 2>/dev/null || echo "0")
    local state=$(grep -oP '"state":\s*"\K[^"]+' "$ACTIVE_FILE" 2>/dev/null || echo "running")
    local billable=$(grep -oP '"billable":\s*\K(true|false)' "$ACTIVE_FILE" 2>/dev/null || echo "false")

    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local end_epoch=$(date +%s)

    local total_seconds=$accumulated
    if [[ "$state" == "running" ]]; then
        local session_seconds=$((end_epoch - start_epoch))
        total_seconds=$((accumulated + session_seconds))
    fi

    local duration_minutes=$(( (total_seconds + 30) / 60 ))  # Round to nearest minute

    # Minimum 1 minute
    if [[ $duration_minutes -lt 1 ]]; then
        duration_minutes=1
    fi

    # Get next entry ID
    local entry_id=$(increment_id)

    # Escape description for CSV (replace commas and quotes)
    local safe_desc=$(echo "$description" | sed 's/"/""/g')

    # Log to CSV with new format including id and billable
    echo "$entry_id,$TODAY,\"$project\",$duration_minutes,\"$safe_desc\",\"$start_time\",\"$end_time\",$billable" >> "$LOG_FILE"

    # Remove active file
    rm "$ACTIVE_FILE"

    echo -e "${GREEN}⏹ Stopped timer for:${NC} ${BOLD}$project${NC}"
    echo -e "${CYAN}  Duration:${NC} $(format_duration $duration_minutes)"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}  Description:${NC} $description"
    fi

    # Show billable info
    if [[ "$billable" == "true" ]]; then
        local rate=$(grep -oP "\"$project\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)
        if [[ -n "$rate" ]]; then
            local amount=$(echo "scale=2; $duration_minutes / 60 * $rate" | bc)
            echo -e "${GREEN}  💰 Billable:${NC} \$$amount ($(format_duration_decimal $duration_minutes)h @ \$$rate/hr)"
        fi
    fi

    echo -e "${DIM}  Entry ID: $entry_id${NC}"
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
    local accumulated=$(grep -oP '"accumulated_seconds":\s*\K[0-9]+' "$ACTIVE_FILE" 2>/dev/null || echo "0")
    local state=$(grep -oP '"state":\s*"\K[^"]+' "$ACTIVE_FILE" 2>/dev/null || echo "running")
    local billable=$(grep -oP '"billable":\s*\K(true|false)' "$ACTIVE_FILE" 2>/dev/null || echo "false")

    local now_epoch=$(date +%s)
    local total_seconds=$accumulated

    if [[ "$state" == "running" ]]; then
        local session_seconds=$((now_epoch - start_epoch))
        total_seconds=$((accumulated + session_seconds))
    fi

    local elapsed_minutes=$((total_seconds / 60))

    if [[ "$state" == "paused" ]]; then
        echo -e "${YELLOW}=== Timer Paused ===${NC}"
    else
        echo -e "${GREEN}=== Timer Running ===${NC}"
    fi
    echo ""
    echo -e "${BOLD}Project:${NC} $project"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
    echo -e "${CYAN}Started:${NC} $start_time"
    echo -e "${YELLOW}Elapsed:${NC} $(format_duration $elapsed_minutes)"

    if [[ "$billable" == "true" ]]; then
        local rate=$(grep -oP "\"$project\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)
        if [[ -n "$rate" ]]; then
            local amount=$(echo "scale=2; $elapsed_minutes / 60 * $rate" | bc)
            echo -e "${GREEN}💰 Billable:${NC} ~\$$amount so far"
        else
            echo -e "${GREEN}💰 Billable${NC}"
        fi
    fi

    if [[ "$state" == "paused" ]]; then
        echo ""
        echo -e "${DIM}Resume with: timelog.sh resume${NC}"
    fi
}

log_manual() {
    local project="$1"
    local minutes="$2"
    local description="${3:-}"
    local billable="false"

    # Check for billable flag
    for arg in "$@"; do
        if [[ "$arg" == "--billable" ]]; then
            billable="true"
        fi
    done

    if [[ -z "$project" ]] || [[ -z "$minutes" ]]; then
        echo "Usage: timelog.sh log \"project\" <minutes> [\"description\"] [--billable]"
        exit 1
    fi

    # Validate minutes is a number
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: minutes must be a positive number${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local safe_desc=$(echo "$description" | sed 's/"/""/g')
    local entry_id=$(increment_id)

    echo "$entry_id,$TODAY,\"$project\",$minutes,\"$safe_desc\",\"$timestamp\",\"$timestamp\",$billable" >> "$LOG_FILE"

    echo -e "${GREEN}✓ Logged:${NC} $(format_duration $minutes) for ${BOLD}$project${NC}"
    if [[ -n "$description" ]]; then
        echo -e "${CYAN}  Description:${NC} $description"
    fi

    if [[ "$billable" == "true" ]]; then
        local rate=$(grep -oP "\"$project\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)
        if [[ -n "$rate" ]]; then
            local amount=$(echo "scale=2; $minutes / 60 * $rate" | bc)
            echo -e "${GREEN}  💰 Billable:${NC} \$$amount"
        fi
    fi

    echo -e "${DIM}  Entry ID: $entry_id${NC}"
}

edit_entry() {
    local id="$1"
    local field="$2"
    local value="$3"

    if [[ -z "$id" ]]; then
        echo "Usage: timelog.sh edit <id> [field] [value]"
        echo ""
        echo "Fields: project, minutes, description, billable"
        echo ""
        echo "Examples:"
        echo "  timelog.sh edit 5 project \"new-project\""
        echo "  timelog.sh edit 5 minutes 45"
        echo "  timelog.sh edit 5 billable true"
        exit 1
    fi

    # Find the entry
    local entry=$(grep "^$id," "$LOG_FILE")
    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: Entry #$id not found${NC}"
        exit 1
    fi

    if [[ -z "$field" ]]; then
        # Show current entry
        echo -e "${BLUE}Entry #$id:${NC}"
        echo "$entry" | awk -F, '{
            gsub(/"/, "", $3); gsub(/"/, "", $5);
            print "  Date: " $2
            print "  Project: " $3
            print "  Minutes: " $4
            print "  Description: " $5
            print "  Billable: " $8
        }'
        echo ""
        echo "Edit with: timelog.sh edit $id <field> <value>"
        exit 0
    fi

    # Edit the field
    case "$field" in
        project)
            sed -i "s/^$id,\([^,]*\),\"[^\"]*\",/$id,\1,\"$value\",/" "$LOG_FILE"
            echo -e "${GREEN}✓ Updated project to: $value${NC}"
            ;;
        minutes)
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: minutes must be a number${NC}"
                exit 1
            fi
            sed -i "s/^$id,\([^,]*\),\([^,]*\),[0-9]*,/$id,\1,\2,$value,/" "$LOG_FILE"
            echo -e "${GREEN}✓ Updated minutes to: $value${NC}"
            ;;
        description|desc)
            local safe_val=$(echo "$value" | sed 's/"/""/g')
            # This is complex with CSV, use a temp approach
            local tmp_file=$(mktemp)
            awk -F, -v id="$id" -v desc="$safe_val" 'BEGIN{OFS=","} {
                if ($1 == id) {
                    $5 = "\"" desc "\""
                }
                print
            }' "$LOG_FILE" > "$tmp_file"
            mv "$tmp_file" "$LOG_FILE"
            echo -e "${GREEN}✓ Updated description${NC}"
            ;;
        billable)
            if [[ "$value" != "true" && "$value" != "false" ]]; then
                echo -e "${RED}Error: billable must be true or false${NC}"
                exit 1
            fi
            sed -i "s/^$id,\(.*\),[^,]*$/\1,$value/" "$LOG_FILE"
            # Fix: proper replacement for billable field
            local tmp_file=$(mktemp)
            awk -F, -v id="$id" -v bill="$value" 'BEGIN{OFS=","} {
                if ($1 == id) {
                    $8 = bill
                }
                print
            }' "$LOG_FILE" > "$tmp_file"
            mv "$tmp_file" "$LOG_FILE"
            echo -e "${GREEN}✓ Updated billable to: $value${NC}"
            ;;
        *)
            echo -e "${RED}Unknown field: $field${NC}"
            echo "Valid fields: project, minutes, description, billable"
            exit 1
            ;;
    esac
}

delete_entry() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: timelog.sh delete <id>"
        exit 1
    fi

    local entry=$(grep "^$id," "$LOG_FILE")
    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: Entry #$id not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Deleting entry #$id:${NC}"
    echo "$entry" | awk -F, '{
        gsub(/"/, "", $3); gsub(/"/, "", $5);
        print "  " $2 " - " $3 " - " $4 "m - " $5
    }'

    sed -i "/^$id,/d" "$LOG_FILE"
    echo -e "${GREEN}✓ Entry deleted${NC}"
}

set_rate() {
    local project="$1"
    local rate="$2"

    if [[ -z "$project" ]] || [[ -z "$rate" ]]; then
        echo "Usage: timelog.sh rate \"project\" <hourly-rate>"
        echo ""
        echo "Examples:"
        echo "  timelog.sh rate \"consulting\" 150"
        echo "  timelog.sh rate \"client-work\" 75.50"
        exit 1
    fi

    # Validate rate is a number
    if ! [[ "$rate" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: rate must be a positive number${NC}"
        exit 1
    fi

    # Update or add rate
    if grep -q "\"$project\":" "$RATES_FILE"; then
        sed -i "s/\"$project\":\s*[0-9.]*,\?/\"$project\": $rate,/" "$RATES_FILE"
    else
        # Add new rate
        local content=$(cat "$RATES_FILE")
        if [[ "$content" == "{}" ]]; then
            echo "{\"$project\": $rate}" > "$RATES_FILE"
        else
            sed -i "s/^{/{\"$project\": $rate, /" "$RATES_FILE"
        fi
    fi

    echo -e "${GREEN}✓ Set rate for '$project': \$$rate/hr${NC}"
}

show_rates() {
    echo -e "${BLUE}=== Billable Rates ===${NC}"
    echo ""

    if [[ ! -s "$RATES_FILE" ]] || [[ "$(cat "$RATES_FILE")" == "{}" ]]; then
        echo "No rates configured."
        echo "Set a rate with: timelog.sh rate \"project\" <hourly-rate>"
        exit 0
    fi

    grep -oP '"[^"]+": [0-9.]+' "$RATES_FILE" | while read line; do
        local proj=$(echo "$line" | grep -oP '"[^"]+' | tr -d '"')
        local rate=$(echo "$line" | grep -oP '[0-9.]+$')
        echo -e "  ${CYAN}$proj${NC}: \$$rate/hr"
    done
}

show_billable() {
    local days=${1:-30}
    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)

    echo -e "${BLUE}=== Billable Summary (Last $days days) ===${NC}"
    echo ""

    # Get billable entries
    local billable_entries=$(tail -n +2 "$LOG_FILE" | grep ",true$")

    if [[ -z "$billable_entries" ]]; then
        echo "No billable time logged."
        echo "Mark time as billable with --billable flag"
        exit 0
    fi

    local total_minutes=0
    local total_amount=0

    echo -e "${YELLOW}By Project:${NC}"
    echo ""

    # Process by project
    echo "$billable_entries" | while IFS=, read -r id date project minutes desc start end billable; do
        project=$(echo "$project" | tr -d '"')
        echo "$date $project $minutes"
    done | awk -v cutoff="$cutoff_date" '
        $1 >= cutoff {
            projects[$2] += $3
            total += $3
        }
        END {
            for (p in projects) {
                print p, projects[p]
            }
            print "TOTAL", total
        }
    ' | while read proj mins; do
        if [[ "$proj" == "TOTAL" ]]; then
            echo ""
            local hours=$(format_duration_decimal $mins)
            echo -e "${BOLD}  Total: $(format_duration $mins) ($hours hours)${NC}"
        else
            local rate=$(grep -oP "\"$proj\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)
            if [[ -n "$rate" ]]; then
                local amount=$(echo "scale=2; $mins / 60 * $rate" | bc)
                printf "  ${CYAN}%-20s${NC} %s (\$%.2f @ \$%s/hr)\n" "$proj" "$(format_duration $mins)" "$amount" "$rate"
            else
                printf "  ${CYAN}%-20s${NC} %s ${DIM}(no rate set)${NC}\n" "$proj" "$(format_duration $mins)"
            fi
        fi
    done
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

    # Get unique projects and their totals
    tail -n +2 "$LOG_FILE" | while IFS=, read -r id date project minutes rest; do
        project=$(echo "$project" | tr -d '"')
        echo "$date $project $minutes"
    done | awk -v cutoff="$cutoff_date" '
        $1 >= cutoff {
            projects[$2] += $3
            total += $3
        }
        END {
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

    tail -n +2 "$LOG_FILE" | while IFS=, read -r id date project minutes rest; do
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

show_week() {
    # Get start of current week (Monday)
    local week_start=$(date -d "last monday" +%Y-%m-%d 2>/dev/null)
    if [[ -z "$week_start" ]] || [[ "$week_start" > "$TODAY" ]]; then
        week_start=$(date -d "monday" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    fi

    echo -e "${BLUE}=== Weekly Summary ===${NC}"
    echo -e "${DIM}Week of $week_start${NC}"
    echo ""

    # Days of the week
    local days=("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")

    echo -e "${YELLOW}Daily Hours:${NC}"
    echo ""

    local total_week=0
    for i in {0..6}; do
        local day_date=$(date -d "$week_start + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -j -f "%Y-%m-%d" "$week_start" +%Y-%m-%d 2>/dev/null)
        local day_minutes=$(tail -n +2 "$LOG_FILE" | awk -F, -v d="$day_date" '$2 == d {sum += $4} END {print sum+0}')
        total_week=$((total_week + day_minutes))

        local bar=""
        local bar_units=$((day_minutes / 15))
        for ((j=0; j<bar_units && j<32; j++)); do
            bar+="█"
        done

        if [[ "$day_date" == "$TODAY" ]]; then
            printf "  ${GREEN}%s %s${NC} %s ${CYAN}%s${NC}\n" "${days[$i]}" "$day_date" "$bar" "$(format_duration $day_minutes)"
        else
            printf "  %s %s %s %s\n" "${days[$i]}" "$day_date" "$bar" "$(format_duration $day_minutes)"
        fi
    done

    echo ""
    echo -e "${BOLD}Week Total: $(format_duration $total_week)${NC}"

    # Show target if 40h/week
    local target=$((40 * 60))
    local percent=$((total_week * 100 / target))
    echo -e "${DIM}  ($percent% of 40h target)${NC}"

    echo ""
    echo -e "${YELLOW}Top Projects This Week:${NC}"
    echo ""

    tail -n +2 "$LOG_FILE" | awk -F, -v start="$week_start" '
        $2 >= start {
            gsub(/"/, "", $3)
            projects[$3] += $4
        }
        END {
            n = asorti(projects, sorted, "@val_num_desc")
            for (i = 1; i <= n && i <= 5; i++) {
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
        }
    '
}

show_today() {
    echo -e "${BLUE}=== Today's Time ($TODAY) ===${NC}"
    echo ""

    local today_entries=$(grep ",$TODAY," "$LOG_FILE")

    if [[ -z "$today_entries" ]]; then
        echo "No time logged today."

        # Check for active timer
        if [[ -f "$ACTIVE_FILE" ]]; then
            echo ""
            show_status
        fi
        exit 0
    fi

    echo "$today_entries" | while IFS=, read -r id date project minutes desc start end billable; do
        project=$(echo "$project" | tr -d '"')
        desc=$(echo "$desc" | tr -d '"')

        local line="  ${GREEN}$project${NC} - $(format_duration $minutes)"
        if [[ -n "$desc" ]]; then
            line+=" - $desc"
        fi
        if [[ "$billable" == "true" ]]; then
            line+=" ${GREEN}💰${NC}"
        fi
        echo -e "$line"
    done

    echo ""

    # Calculate total
    local day_total=$(echo "$today_entries" | awk -F, '{sum += $4} END {print sum}')
    echo -e "${BOLD}Total today:${NC} $(format_duration $day_total)"

    # Show active timer if any
    if [[ -f "$ACTIVE_FILE" ]]; then
        echo ""
        show_status
    fi
}

list_projects() {
    echo -e "${BLUE}=== Projects ===${NC}"
    echo ""

    local projects=$(tail -n +2 "$LOG_FILE" | cut -d, -f3 | tr -d '"' | sort -u)

    if [[ -z "$projects" ]]; then
        echo "No projects yet."
        exit 0
    fi

    echo "$projects" | while read project; do
        local total=$(grep "\"$project\"" "$LOG_FILE" | awk -F, '{sum += $4} END {print sum}')
        local rate=$(grep -oP "\"$project\":\s*\K[0-9.]+" "$RATES_FILE" 2>/dev/null)

        local line="  ${GREEN}$project${NC} - $(format_duration $total) total"
        if [[ -n "$rate" ]]; then
            line+=" ${DIM}(\$$rate/hr)${NC}"
        fi
        echo -e "$line"
    done
}

list_tags() {
    echo -e "${BLUE}=== Tags ===${NC}"
    echo ""

    local tags=$(tail -n +2 "$LOG_FILE" | cut -d, -f5 | grep -oP '#\w+' | sort | uniq -c | sort -rn)

    if [[ -z "$tags" ]]; then
        echo "No tags found."
        echo "Add tags with #tag in your descriptions"
        exit 0
    fi

    echo "$tags" | while read count tag; do
        echo -e "  ${MAGENTA}$tag${NC} ($count entries)"
    done
}

filter_entries() {
    local filter_type="$1"
    local filter_value="$2"
    local days="${3:-30}"

    case "$filter_type" in
        --project|-p)
            if [[ -z "$filter_value" ]]; then
                echo "Usage: timelog.sh filter --project <name>"
                exit 1
            fi
            echo -e "${BLUE}=== Entries for project: $filter_value ===${NC}"
            echo ""
            grep "\"$filter_value\"" "$LOG_FILE" | tail -20 | while IFS=, read -r id date project minutes desc start end billable; do
                desc=$(echo "$desc" | tr -d '"')
                echo -e "  ${DIM}#$id${NC} $date - $(format_duration $minutes) - $desc"
            done
            ;;
        --tag|-t)
            if [[ -z "$filter_value" ]]; then
                echo "Usage: timelog.sh filter --tag <tag>"
                exit 1
            fi
            echo -e "${BLUE}=== Entries with tag: $filter_value ===${NC}"
            echo ""
            grep "$filter_value" "$LOG_FILE" | tail -20 | while IFS=, read -r id date project minutes desc start end billable; do
                project=$(echo "$project" | tr -d '"')
                desc=$(echo "$desc" | tr -d '"')
                echo -e "  ${DIM}#$id${NC} $date - ${CYAN}$project${NC} - $(format_duration $minutes) - $desc"
            done
            ;;
        --date|-d)
            if [[ -z "$filter_value" ]]; then
                echo "Usage: timelog.sh filter --date <YYYY-MM-DD>"
                exit 1
            fi
            echo -e "${BLUE}=== Entries for date: $filter_value ===${NC}"
            echo ""
            grep ",$filter_value," "$LOG_FILE" | while IFS=, read -r id date project minutes desc start end billable; do
                project=$(echo "$project" | tr -d '"')
                desc=$(echo "$desc" | tr -d '"')
                echo -e "  ${DIM}#$id${NC} ${CYAN}$project${NC} - $(format_duration $minutes) - $desc"
            done
            ;;
        *)
            echo "Usage: timelog.sh filter <option> <value>"
            echo ""
            echo "Options:"
            echo "  --project, -p <name>    Filter by project name"
            echo "  --tag, -t <tag>         Filter by tag (#tag)"
            echo "  --date, -d <date>       Filter by date (YYYY-MM-DD)"
            ;;
    esac
}

export_data() {
    local format="${1:-json}"
    local output_file="$DATA_DIR/export_$(date +%Y%m%d_%H%M%S)"

    case "$format" in
        json)
            output_file="${output_file}.json"
            echo "[" > "$output_file"
            local first=true
            tail -n +2 "$LOG_FILE" | while IFS=, read -r id date project minutes desc start end billable; do
                project=$(echo "$project" | tr -d '"')
                desc=$(echo "$desc" | tr -d '"')
                start=$(echo "$start" | tr -d '"')
                end=$(echo "$end" | tr -d '"')

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi

                cat >> "$output_file" << EOF
  {
    "id": $id,
    "date": "$date",
    "project": "$project",
    "minutes": $minutes,
    "description": "$desc",
    "start_time": "$start",
    "end_time": "$end",
    "billable": $billable
  }
EOF
            done
            echo "]" >> "$output_file"
            echo -e "${GREEN}✓ Exported to:${NC} $output_file"
            ;;
        csv)
            output_file="${output_file}.csv"
            cp "$LOG_FILE" "$output_file"
            echo -e "${GREEN}✓ Exported to:${NC} $output_file"
            ;;
        *)
            echo "Usage: timelog.sh export [json|csv]"
            exit 1
            ;;
    esac
}

show_stats() {
    echo -e "${BLUE}=== Time Tracking Statistics ===${NC}"
    echo ""

    local total_entries=$(tail -n +2 "$LOG_FILE" | wc -l)
    local total_minutes=$(tail -n +2 "$LOG_FILE" | awk -F, '{sum += $4} END {print sum+0}')
    local total_projects=$(tail -n +2 "$LOG_FILE" | cut -d, -f3 | tr -d '"' | sort -u | wc -l)
    local first_entry=$(tail -n +2 "$LOG_FILE" | head -1 | cut -d, -f2)
    local billable_minutes=$(tail -n +2 "$LOG_FILE" | grep ",true$" | awk -F, '{sum += $4} END {print sum+0}')

    echo -e "${CYAN}Total entries:${NC} $total_entries"
    echo -e "${CYAN}Total time:${NC} $(format_duration $total_minutes) ($(format_duration_decimal $total_minutes) hours)"
    echo -e "${CYAN}Total projects:${NC} $total_projects"
    echo -e "${CYAN}Tracking since:${NC} $first_entry"
    echo -e "${CYAN}Billable time:${NC} $(format_duration $billable_minutes)"

    if [[ $total_entries -gt 0 ]]; then
        local avg_session=$((total_minutes / total_entries))
        echo -e "${CYAN}Avg session:${NC} $(format_duration $avg_session)"
    fi
}

show_help() {
    echo -e "${BOLD}Time Log v2.0${NC} - Enhanced time tracking for projects and activities"
    echo ""
    echo -e "${YELLOW}Basic Commands:${NC}"
    echo "  start \"project\" [desc] [--billable]  Start timing a project"
    echo "  stop                                  Stop current timer"
    echo "  pause                                 Pause current timer"
    echo "  resume                                Resume paused timer"
    echo "  status                                Show current timer"
    echo "  log \"project\" <min> [desc] [--bill]   Log time manually"
    echo ""
    echo -e "${YELLOW}Reports:${NC}"
    echo "  today                                 Show today's time"
    echo "  week                                  Show weekly summary"
    echo "  report [days]                         Show report (default: 7 days)"
    echo "  projects                              List all projects"
    echo "  stats                                 Show statistics"
    echo ""
    echo -e "${YELLOW}Billable:${NC}"
    echo "  rate \"project\" <hourly-rate>          Set hourly rate"
    echo "  rates                                 Show all rates"
    echo "  billable [days]                       Show billable summary"
    echo ""
    echo -e "${YELLOW}Management:${NC}"
    echo "  edit <id> [field] [value]             Edit an entry"
    echo "  delete <id>                           Delete an entry"
    echo "  filter --project|--tag|--date <val>   Filter entries"
    echo "  tags                                  List all tags"
    echo "  export [json|csv]                     Export data"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  timelog.sh start \"coding\" \"Feature X #backend\""
    echo "  timelog.sh start \"consulting\" --billable"
    echo "  timelog.sh pause"
    echo "  timelog.sh resume"
    echo "  timelog.sh stop"
    echo "  timelog.sh log \"meeting\" 30 \"Team standup #meetings\""
    echo "  timelog.sh rate \"consulting\" 150"
    echo "  timelog.sh filter --tag #backend"
}

# Main command handler
case "$1" in
    start)
        shift
        start_timer "$@"
        ;;
    stop)
        stop_timer
        ;;
    pause)
        pause_timer
        ;;
    resume)
        resume_timer
        ;;
    status|st)
        show_status
        ;;
    log|add)
        shift
        log_manual "$@"
        ;;
    edit)
        shift
        edit_entry "$@"
        ;;
    delete|del|rm)
        delete_entry "$2"
        ;;
    report|rep)
        show_report "$2"
        ;;
    week|wk)
        show_week
        ;;
    today|td)
        show_today
        ;;
    projects|proj)
        list_projects
        ;;
    rate)
        shift
        if [[ -z "$1" ]]; then
            show_rates
        else
            set_rate "$@"
        fi
        ;;
    rates)
        show_rates
        ;;
    billable|bill)
        show_billable "$2"
        ;;
    tags)
        list_tags
        ;;
    filter)
        shift
        filter_entries "$@"
        ;;
    export)
        export_data "$2"
        ;;
    stats)
        show_stats
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
