#!/bin/bash
#
# Pomodoro Timer - Enhanced command-line focus timer
#
# Usage:
#   pomodoro.sh start [project] [--work N] [--break N]  - Start a pomodoro session
#   pomodoro.sh stop                                     - Stop current session early
#   pomodoro.sh pause                                    - Pause the timer
#   pomodoro.sh resume                                   - Resume paused timer
#   pomodoro.sh status                                   - Show today's sessions
#   pomodoro.sh history [days]                          - Show session history (default: 7)
#   pomodoro.sh stats [days]                            - Show statistics (default: 7)
#   pomodoro.sh projects                                - List projects with time
#   pomodoro.sh config [key] [value]                    - View/set configuration
#   pomodoro.sh long-break                              - Take a 15 minute break
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_FILE="$DATA_DIR/pomodoro_log.csv"
ACTIVE_FILE="$DATA_DIR/active.json"
CONFIG_FILE="$DATA_DIR/config.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize log file with header if it doesn't exist
if [[ ! -f "$LOG_FILE" ]]; then
    echo "date,time,project,duration,type,completed,notes" > "$LOG_FILE"
fi

# Initialize config file with defaults
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
    "work_minutes": 25,
    "short_break": 5,
    "long_break": 15,
    "sessions_until_long_break": 4,
    "auto_start_break": false,
    "sound_enabled": true,
    "desktop_notification": true
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

# Get config value
get_config() {
    local key="$1"
    local default="$2"
    if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
        local value=$(jq -r ".$key // \"$default\"" "$CONFIG_FILE" 2>/dev/null)
        [[ "$value" == "null" ]] && value="$default"
        echo "$value"
    else
        echo "$default"
    fi
}

# Set config value
set_config() {
    local key="$1"
    local value="$2"

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required for config management${NC}"
        exit 1
    fi

    # Determine if value should be a number or boolean
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        jq ".$key = $value" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    elif [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
        jq ".$key = $value" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        jq ".$key = \"$value\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi

    echo -e "${GREEN}Set $key = $value${NC}"
}

# Send notification
notify() {
    local message="$1"
    local use_desktop=$(get_config "desktop_notification" "true")
    local use_sound=$(get_config "sound_enabled" "true")

    # Desktop notification
    if [[ "$use_desktop" == "true" ]] && command -v notify-send &> /dev/null; then
        notify-send "🍅 Pomodoro" "$message" 2>/dev/null
    fi

    # Terminal bell
    if [[ "$use_sound" == "true" ]]; then
        echo -e "\a"
    fi
}

# Format duration
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

# Countdown timer
countdown() {
    local minutes=$1
    local label=$2
    local total_seconds=$((minutes * 60))
    local remaining=$total_seconds
    local start_epoch=$(date +%s)

    # Save state for pause/resume
    echo "{\"remaining\":$remaining,\"label\":\"$label\",\"start_epoch\":$start_epoch,\"paused\":false}" > "$DATA_DIR/.countdown_state"

    echo -e "${BLUE}Starting $label: $minutes minutes${NC}"
    echo -e "${GRAY}Press Ctrl+C to pause${NC}"
    echo ""

    # Hide cursor
    tput civis 2>/dev/null

    # Trap Ctrl+C for pause
    trap 'handle_interrupt' INT

    while [[ $remaining -gt 0 ]]; do
        # Check if paused
        if [[ -f "$DATA_DIR/.paused" ]]; then
            tput cnorm 2>/dev/null
            rm -f "$DATA_DIR/.paused"
            echo "{\"remaining\":$remaining,\"label\":\"$label\",\"paused\":true}" > "$DATA_DIR/.countdown_state"
            echo ""
            echo -e "${YELLOW}Timer paused with $remaining seconds remaining.${NC}"
            echo -e "${GRAY}Resume with: pomodoro.sh resume${NC}"
            return 1
        fi

        local mins=$((remaining / 60))
        local secs=$((remaining % 60))
        printf "\r  ${YELLOW}%02d:%02d${NC} remaining   " $mins $secs
        sleep 1
        ((remaining--))

        # Update state
        echo "{\"remaining\":$remaining,\"label\":\"$label\",\"start_epoch\":$start_epoch,\"paused\":false}" > "$DATA_DIR/.countdown_state"
    done

    # Restore cursor
    tput cnorm 2>/dev/null

    # Reset trap
    trap - INT

    echo ""
    echo -e "${GREEN}✓ $label complete!${NC}"
    notify "$label complete!"

    # Clean up state
    rm -f "$DATA_DIR/.countdown_state"

    return 0
}

handle_interrupt() {
    touch "$DATA_DIR/.paused"
}

# Log a completed pomodoro
log_session() {
    local project="$1"
    local duration="$2"
    local type="$3"
    local completed="$4"
    local notes="$5"

    local timestamp=$(date '+%H:%M')
    local safe_project=$(echo "$project" | sed 's/,/;/g' | sed 's/"//g')
    local safe_notes=$(echo "$notes" | sed 's/,/;/g' | sed 's/"//g')

    echo "$TODAY,$timestamp,\"$safe_project\",$duration,$type,$completed,\"$safe_notes\"" >> "$LOG_FILE"
}

# Get today's completed sessions count
get_today_count() {
    grep "^$TODAY" "$LOG_FILE" 2>/dev/null | grep ",work,true," | wc -l
}

# Start a pomodoro session
start_session() {
    local project="general"
    local work_minutes=$(get_config "work_minutes" "25")
    local break_minutes=$(get_config "short_break" "5")

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --work)
                work_minutes="$2"
                shift 2
                ;;
            --break)
                break_minutes="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                exit 1
                ;;
            *)
                project="$1"
                shift
                ;;
        esac
    done

    # Check for existing active session
    if [[ -f "$ACTIVE_FILE" ]]; then
        echo -e "${YELLOW}A session is already active.${NC}"
        echo "Stop it first with: pomodoro.sh stop"
        exit 1
    fi

    # Check for paused countdown
    if [[ -f "$DATA_DIR/.countdown_state" ]]; then
        local paused=$(grep -o '"paused":true' "$DATA_DIR/.countdown_state" 2>/dev/null)
        if [[ -n "$paused" ]]; then
            echo -e "${YELLOW}A paused timer exists.${NC}"
            echo "Resume with: pomodoro.sh resume"
            echo "Or cancel with: pomodoro.sh stop"
            exit 1
        fi
    fi

    # Get session count for long break suggestion
    local today_count=$(get_today_count)
    local sessions_for_long=$(get_config "sessions_until_long_break" "4")

    # Create active session marker
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$ACTIVE_FILE" << EOF
{
    "project": "$project",
    "work_minutes": $work_minutes,
    "break_minutes": $break_minutes,
    "start_time": "$start_time",
    "state": "work"
}
EOF

    echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}         ${BOLD}🍅 POMODORO TIMER${NC}            ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Project:${NC} $project"
    echo -e "${CYAN}Session:${NC} #$((today_count + 1)) today"
    echo ""

    # Work session
    if countdown $work_minutes "Work session"; then
        log_session "$project" "$work_minutes" "work" "true" ""
        rm -f "$ACTIVE_FILE"

        today_count=$(get_today_count)

        echo ""
        echo -e "${GREEN}🎉 Pomodoro #$today_count completed!${NC}"

        # Check if it's time for a long break
        if [[ $((today_count % sessions_for_long)) -eq 0 ]]; then
            echo ""
            echo -e "${MAGENTA}You've completed $sessions_for_long sessions! Time for a long break.${NC}"
            read -p "Start long break? (Y/n) " -n 1 -r
            echo ""

            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                local long_break=$(get_config "long_break" "15")
                countdown $long_break "Long break"
                log_session "$project" "$long_break" "long_break" "true" ""
            fi
        else
            # Regular break prompt
            local auto_break=$(get_config "auto_start_break" "false")

            if [[ "$auto_break" == "true" ]]; then
                echo ""
                countdown $break_minutes "Short break"
                log_session "$project" "$break_minutes" "short_break" "true" ""
            else
                echo ""
                read -p "Start short break? (Y/n) " -n 1 -r
                echo ""

                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    countdown $break_minutes "Short break"
                    log_session "$project" "$break_minutes" "short_break" "true" ""
                fi
            fi
        fi

        echo ""
        echo -e "${GREEN}Ready for another pomodoro? Run: pomodoro.sh start $project${NC}"
    else
        # Session was paused
        # Update active file to paused state
        if [[ -f "$ACTIVE_FILE" ]]; then
            local remaining=$(grep -o '"remaining":[0-9]*' "$DATA_DIR/.countdown_state" 2>/dev/null | grep -o '[0-9]*')
            jq --argjson rem "${remaining:-0}" '.state = "paused" | .remaining_seconds = $rem' "$ACTIVE_FILE" > "$ACTIVE_FILE.tmp" && mv "$ACTIVE_FILE.tmp" "$ACTIVE_FILE"
        fi
    fi
}

# Stop current session
stop_session() {
    if [[ -f "$DATA_DIR/.countdown_state" ]]; then
        rm -f "$DATA_DIR/.countdown_state"
    fi

    if [[ -f "$ACTIVE_FILE" ]]; then
        local project=$(grep -o '"project":\s*"[^"]*"' "$ACTIVE_FILE" | cut -d'"' -f4)
        rm -f "$ACTIVE_FILE"
        rm -f "$DATA_DIR/.paused"
        echo -e "${RED}Stopped session:${NC} $project"
        echo -e "${GRAY}Session was not logged.${NC}"
    else
        echo -e "${YELLOW}No active session to stop.${NC}"
    fi
}

# Pause current timer
pause_session() {
    if [[ ! -f "$ACTIVE_FILE" ]]; then
        echo -e "${YELLOW}No active session to pause.${NC}"
        exit 0
    fi

    # Signal the countdown to pause
    touch "$DATA_DIR/.paused"
    echo -e "${YELLOW}Pause signal sent.${NC}"
}

# Resume paused timer
resume_session() {
    if [[ ! -f "$DATA_DIR/.countdown_state" ]]; then
        echo -e "${YELLOW}No paused timer to resume.${NC}"
        exit 0
    fi

    local paused=$(grep -o '"paused":true' "$DATA_DIR/.countdown_state" 2>/dev/null)
    if [[ -z "$paused" ]]; then
        echo -e "${YELLOW}Timer is not paused.${NC}"
        exit 0
    fi

    local remaining=$(grep -o '"remaining":[0-9]*' "$DATA_DIR/.countdown_state" | grep -o '[0-9]*')
    local label=$(grep -o '"label":"[^"]*"' "$DATA_DIR/.countdown_state" | cut -d'"' -f4)

    # Get project from active file
    local project="general"
    if [[ -f "$ACTIVE_FILE" ]]; then
        project=$(grep -o '"project":\s*"[^"]*"' "$ACTIVE_FILE" | cut -d'"' -f4)
    fi

    echo -e "${GREEN}Resuming timer...${NC}"
    echo -e "${CYAN}Project:${NC} $project"
    echo ""

    # Update active file state
    if [[ -f "$ACTIVE_FILE" ]]; then
        jq '.state = "work"' "$ACTIVE_FILE" > "$ACTIVE_FILE.tmp" && mv "$ACTIVE_FILE.tmp" "$ACTIVE_FILE" 2>/dev/null
    fi

    # Resume countdown with remaining seconds
    local remaining_minutes=$((remaining / 60 + 1))
    local total_seconds=$remaining

    # Directly run remaining countdown
    echo "{\"remaining\":$remaining,\"label\":\"$label\",\"paused\":false}" > "$DATA_DIR/.countdown_state"

    tput civis 2>/dev/null
    trap 'handle_interrupt' INT

    while [[ $remaining -gt 0 ]]; do
        if [[ -f "$DATA_DIR/.paused" ]]; then
            tput cnorm 2>/dev/null
            rm -f "$DATA_DIR/.paused"
            echo "{\"remaining\":$remaining,\"label\":\"$label\",\"paused\":true}" > "$DATA_DIR/.countdown_state"
            echo ""
            echo -e "${YELLOW}Timer paused with $remaining seconds remaining.${NC}"
            return
        fi

        local mins=$((remaining / 60))
        local secs=$((remaining % 60))
        printf "\r  ${YELLOW}%02d:%02d${NC} remaining   " $mins $secs
        sleep 1
        ((remaining--))
        echo "{\"remaining\":$remaining,\"label\":\"$label\",\"paused\":false}" > "$DATA_DIR/.countdown_state"
    done

    tput cnorm 2>/dev/null
    trap - INT

    echo ""
    echo -e "${GREEN}✓ $label complete!${NC}"
    notify "$label complete!"

    # Log the session
    local work_minutes=$(grep -o '"work_minutes":[0-9]*' "$ACTIVE_FILE" 2>/dev/null | grep -o '[0-9]*')
    [[ -z "$work_minutes" ]] && work_minutes=25

    log_session "$project" "$work_minutes" "work" "true" ""
    rm -f "$ACTIVE_FILE" "$DATA_DIR/.countdown_state"

    echo ""
    echo -e "${GREEN}🎉 Pomodoro completed!${NC}"
}

# Show today's status
show_status() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}       ${BOLD}Today's Pomodoros ($TODAY)${NC}     ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""

    # Check for active session
    if [[ -f "$ACTIVE_FILE" ]]; then
        local project=$(grep -o '"project":\s*"[^"]*"' "$ACTIVE_FILE" | cut -d'"' -f4)
        local state=$(grep -o '"state":\s*"[^"]*"' "$ACTIVE_FILE" | cut -d'"' -f4)

        if [[ "$state" == "paused" ]]; then
            local remaining=$(grep -o '"remaining_seconds":[0-9]*' "$ACTIVE_FILE" | grep -o '[0-9]*')
            echo -e "${YELLOW}⏸  Paused session:${NC} $project ($(($remaining / 60))m $(($remaining % 60))s remaining)"
        else
            echo -e "${GREEN}▶  Active session:${NC} $project"
        fi
        echo ""
    fi

    local today_sessions=$(grep "^$TODAY" "$LOG_FILE" 2>/dev/null | grep ",work,true,")

    if [[ -z "$today_sessions" ]]; then
        echo "No completed pomodoros today."
        echo ""
        echo -e "${GRAY}Start one with: pomodoro.sh start [project]${NC}"
        return
    fi

    local count=$(echo "$today_sessions" | wc -l)
    local total_work=$(echo "$today_sessions" | cut -d, -f4 | paste -sd+ | bc)

    echo -e "${GREEN}Completed:${NC} $count pomodoros"
    echo -e "${CYAN}Focus time:${NC} $(format_duration $total_work)"
    echo ""

    echo -e "${YELLOW}Sessions:${NC}"
    echo "$today_sessions" | while IFS=, read -r date time project duration type completed notes; do
        project=$(echo "$project" | tr -d '"')
        echo -e "  ${GRAY}$time${NC} - ${GREEN}$project${NC} (${duration}m)"
    done

    # Show by project
    echo ""
    echo -e "${YELLOW}By project:${NC}"
    echo "$today_sessions" | cut -d, -f3,4 | tr -d '"' | awk -F, '{projects[$1]+=$2} END {for(p in projects) printf "  %-20s %s\n", p, projects[p]"m"}' | sort
}

# Show session history
show_history() {
    local days=${1:-7}

    echo -e "${BLUE}=== Pomodoro History (Last $days days) ===${NC}"
    echo ""

    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)

    tail -n +2 "$LOG_FILE" | awk -F, -v cutoff="$cutoff_date" '
        $1 >= cutoff && $5 == "work" && $6 == "true" {
            gsub(/"/, "", $3)
            dates[$1]++
            date_mins[$1] += $4
        }
        END {
            n = asorti(dates, sorted)
            for (i = n; i >= 1; i--) {
                d = sorted[i]
                count = dates[d]
                mins = date_mins[d]
                hours = int(mins / 60)
                remaining = mins % 60
                if (hours > 0) {
                    printf "  %s: %d pomodoros (%dh %dm focus time)\n", d, count, hours, remaining
                } else {
                    printf "  %s: %d pomodoros (%dm focus time)\n", d, count, remaining
                }
            }
        }
    '
}

# Show statistics
show_stats() {
    local days=${1:-7}

    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}      ${BOLD}Pomodoro Statistics ($days days)${NC}      ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""

    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)

    # Calculate stats
    local stats=$(tail -n +2 "$LOG_FILE" | awk -F, -v cutoff="$cutoff_date" '
        $1 >= cutoff && $5 == "work" && $6 == "true" {
            total_count++
            total_mins += $4
            gsub(/"/, "", $3)
            projects[$3] += $4
            project_count[$3]++
            dates[$1]++
        }
        END {
            if (total_count == 0) {
                print "EMPTY"
                exit
            }

            # Find max project
            max_proj = ""
            max_mins = 0
            for (p in projects) {
                if (projects[p] > max_mins) {
                    max_mins = projects[p]
                    max_proj = p
                }
            }

            # Count active days
            active_days = length(dates)

            # Calculate average
            avg = total_count / active_days

            print "total_count=" total_count
            print "total_mins=" total_mins
            print "active_days=" active_days
            print "avg_per_day=" avg
            print "top_project=" max_proj
            print "top_project_mins=" max_mins
        }
    ')

    if [[ "$stats" == "EMPTY" ]]; then
        echo "No pomodoros completed in the last $days days."
        echo ""
        echo -e "${GRAY}Start one with: pomodoro.sh start [project]${NC}"
        return
    fi

    eval "$stats"

    local hours=$((total_mins / 60))
    local mins=$((total_mins % 60))

    echo -e "${GREEN}Total pomodoros:${NC}    $total_count"
    echo -e "${GREEN}Total focus time:${NC}   ${hours}h ${mins}m"
    echo -e "${GREEN}Active days:${NC}        $active_days"
    printf "${GREEN}Average per day:${NC}    %.1f pomodoros\n" "$avg_per_day"
    echo ""
    echo -e "${YELLOW}Top project:${NC}        $top_project ($(format_duration $top_project_mins))"
    echo ""

    # Show project breakdown
    echo -e "${CYAN}Time by project:${NC}"
    tail -n +2 "$LOG_FILE" | awk -F, -v cutoff="$cutoff_date" '
        $1 >= cutoff && $5 == "work" && $6 == "true" {
            gsub(/"/, "", $3)
            projects[$3] += $4
            project_count[$3]++
        }
        END {
            for (p in projects) {
                mins = projects[p]
                count = project_count[p]
                hours = int(mins / 60)
                remaining = mins % 60
                if (hours > 0) {
                    printf "  %-20s %d sessions, %dh %dm\n", p, count, hours, remaining
                } else {
                    printf "  %-20s %d sessions, %dm\n", p, count, remaining
                }
            }
        }
    ' | sort -t',' -k2 -rn

    echo ""

    # Show daily breakdown (last 7 days)
    echo -e "${CYAN}Daily breakdown:${NC}"
    for ((i = 6; i >= 0; i--)); do
        local check_date=$(date -d "$TODAY - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local day_name=$(date -d "$check_date" +%a 2>/dev/null || date -jf "%Y-%m-%d" "$check_date" +%a 2>/dev/null)
        local day_count=$(grep "^$check_date" "$LOG_FILE" 2>/dev/null | grep ",work,true," | wc -l)

        # Create visual bar
        local bar=""
        for ((j = 0; j < day_count && j < 12; j++)); do
            bar+="🍅"
        done

        if [[ $check_date == "$TODAY" ]]; then
            printf "  ${GREEN}%s %s${NC}: %-2d %s\n" "$day_name" "$check_date" "$day_count" "$bar"
        else
            printf "  %s %s: %-2d %s\n" "$day_name" "$check_date" "$day_count" "$bar"
        fi
    done
}

# List projects
list_projects() {
    echo -e "${BLUE}=== Projects ===${NC}"
    echo ""

    local projects=$(tail -n +2 "$LOG_FILE" | grep ",work,true," | cut -d, -f3 | tr -d '"' | sort -u)

    if [[ -z "$projects" ]]; then
        echo "No projects yet."
        return
    fi

    echo "$projects" | while read project; do
        local stats=$(grep ",\"$project\"," "$LOG_FILE" | grep ",work,true," | awk -F, '{count++; mins+=$4} END {print count, mins}')
        local count=$(echo "$stats" | cut -d' ' -f1)
        local mins=$(echo "$stats" | cut -d' ' -f2)

        printf "  ${GREEN}%-20s${NC} %d pomodoros, %s\n" "$project" "$count" "$(format_duration $mins)"
    done
}

# Manage configuration
manage_config() {
    local key="$1"
    local value="$2"

    if [[ -z "$key" ]]; then
        # Show all config
        echo -e "${BLUE}=== Configuration ===${NC}"
        echo ""

        if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
            jq -r 'to_entries | .[] | "  \(.key): \(.value)"' "$CONFIG_FILE"
        else
            echo "  work_minutes: $(get_config work_minutes 25)"
            echo "  short_break: $(get_config short_break 5)"
            echo "  long_break: $(get_config long_break 15)"
            echo "  sessions_until_long_break: $(get_config sessions_until_long_break 4)"
            echo "  auto_start_break: $(get_config auto_start_break false)"
            echo "  sound_enabled: $(get_config sound_enabled true)"
            echo "  desktop_notification: $(get_config desktop_notification true)"
        fi
        echo ""
        echo -e "${GRAY}Set with: pomodoro.sh config <key> <value>${NC}"
    elif [[ -z "$value" ]]; then
        # Show single config
        echo -e "${CYAN}$key:${NC} $(get_config "$key" "not set")"
    else
        # Set config
        set_config "$key" "$value"
    fi
}

# Long break
long_break() {
    local duration=$(get_config "long_break" "15")

    echo -e "${GREEN}=== Long Break ===${NC}"
    echo ""
    countdown $duration "Long break"
    log_session "break" "$duration" "long_break" "true" ""
}

# Show help
show_help() {
    echo "Pomodoro Timer - Enhanced focus timer"
    echo ""
    echo "Usage:"
    echo "  pomodoro.sh start [project] [options]  Start a pomodoro"
    echo "  pomodoro.sh stop                       Stop current session"
    echo "  pomodoro.sh pause                      Pause the timer"
    echo "  pomodoro.sh resume                     Resume paused timer"
    echo "  pomodoro.sh status                     Show today's sessions"
    echo "  pomodoro.sh history [days]             Show history (default: 7)"
    echo "  pomodoro.sh stats [days]               Show statistics"
    echo "  pomodoro.sh projects                   List all projects"
    echo "  pomodoro.sh config [key] [value]       View/set configuration"
    echo "  pomodoro.sh long-break                 Start a long break"
    echo "  pomodoro.sh help                       Show this help"
    echo ""
    echo "Options for start:"
    echo "  --work N     Set work duration in minutes"
    echo "  --break N    Set break duration in minutes"
    echo ""
    echo "Examples:"
    echo "  pomodoro.sh start coding"
    echo "  pomodoro.sh start \"project-x\" --work 50 --break 10"
    echo "  pomodoro.sh stats 30"
    echo "  pomodoro.sh config work_minutes 30"
    echo ""
    echo "Configuration options:"
    echo "  work_minutes              Default work duration (25)"
    echo "  short_break               Short break duration (5)"
    echo "  long_break                Long break duration (15)"
    echo "  sessions_until_long_break Sessions before long break (4)"
    echo "  auto_start_break          Auto-start breaks (false)"
    echo "  sound_enabled             Play sounds (true)"
    echo "  desktop_notification      Show notifications (true)"
}

# Main command router
case "$1" in
    start|begin)
        shift
        start_session "$@"
        ;;
    stop|cancel)
        stop_session
        ;;
    pause)
        pause_session
        ;;
    resume|continue)
        resume_session
        ;;
    status|today|st)
        show_status
        ;;
    history|hist)
        show_history "$2"
        ;;
    stats|statistics)
        show_stats "$2"
        ;;
    projects|proj)
        list_projects
        ;;
    config|cfg)
        manage_config "$2" "$3"
        ;;
    long-break|lb)
        long_break
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_status
        ;;
    *)
        # Check if it's a project name (backwards compatibility)
        if [[ "$1" =~ ^[0-9]+$ ]] && [[ -z "$2" || "$2" =~ ^[0-9]+$ ]]; then
            # Looks like old style: pomodoro.sh 25 5
            start_session "general" --work "$1" --break "${2:-5}"
        else
            echo "Unknown command: $1"
            echo "Run 'pomodoro.sh help' for usage"
            exit 1
        fi
        ;;
esac
