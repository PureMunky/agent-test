#!/bin/bash
#
# Stopwatch - Simple stopwatch with lap times and named timers
#
# Usage:
#   stopwatch.sh start [name]        - Start a new stopwatch (default: "default")
#   stopwatch.sh stop [name]         - Stop and display final time
#   stopwatch.sh lap [name]          - Record a lap time
#   stopwatch.sh status [name]       - Show current elapsed time
#   stopwatch.sh reset [name]        - Reset a stopwatch
#   stopwatch.sh list                - List all active stopwatches
#   stopwatch.sh history [n]         - Show last n completed sessions (default: 10)
#   stopwatch.sh live [name]         - Show live updating display (Ctrl+C to stop watching)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
ACTIVE_DIR="$DATA_DIR/active"
HISTORY_FILE="$DATA_DIR/history.csv"

mkdir -p "$ACTIVE_DIR"

# Initialize history file with header if it doesn't exist
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo "date,name,duration_seconds,laps,start_time,end_time" > "$HISTORY_FILE"
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

# Format seconds into HH:MM:SS.ms format
format_duration() {
    local total_ms=$1
    local total_seconds=$((total_ms / 1000))
    local ms=$((total_ms % 1000))
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%d:%02d:%02d.%03d" $hours $minutes $seconds $ms
    elif [[ $minutes -gt 0 ]]; then
        printf "%d:%02d.%03d" $minutes $seconds $ms
    else
        printf "%d.%03d" $seconds $ms
    fi
}

# Format seconds into human-readable format
format_human() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

get_current_ms() {
    # Get current time in milliseconds since epoch
    local now_sec=$(date +%s)
    local now_nano=$(date +%N 2>/dev/null || echo "000000000")
    # Remove leading zeros to avoid octal interpretation
    now_nano=$(echo "$now_nano" | sed 's/^0*//')
    [[ -z "$now_nano" ]] && now_nano=0
    local now_ms=$(( now_sec * 1000 + now_nano / 1000000 ))
    echo "$now_ms"
}

start_stopwatch() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    # Check if already running
    if [[ -f "$active_file" ]]; then
        local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
        if [[ "$state" == "running" ]]; then
            echo -e "${YELLOW}Stopwatch '$name' is already running.${NC}"
            show_status "$name"
            exit 0
        elif [[ "$state" == "paused" ]]; then
            # Resume paused stopwatch
            local elapsed=$(grep -o '"elapsed_ms":\s*[0-9]*' "$active_file" | grep -o '[0-9]*$')
            local start_ms=$(get_current_ms)
            local laps=$(grep -o '"laps":\s*\[[^]]*\]' "$active_file")
            local start_time=$(grep -o '"start_time":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)

            cat > "$active_file" << EOF
{
    "name": "$name",
    "state": "running",
    "start_ms": $start_ms,
    "elapsed_ms": $elapsed,
    "start_time": "$start_time",
    $laps
}
EOF
            echo -e "${GREEN}Resumed stopwatch:${NC} $name"
            echo -e "${CYAN}Previously elapsed:${NC} $(format_duration $elapsed)"
            exit 0
        fi
    fi

    local start_ms=$(get_current_ms)
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$active_file" << EOF
{
    "name": "$name",
    "state": "running",
    "start_ms": $start_ms,
    "elapsed_ms": 0,
    "start_time": "$start_time",
    "laps": []
}
EOF

    echo -e "${GREEN}Started stopwatch:${NC} $name"
    echo -e "${CYAN}Started at:${NC} $start_time"
    echo ""
    echo -e "${GRAY}Use 'stopwatch.sh lap $name' to record lap times${NC}"
    echo -e "${GRAY}Use 'stopwatch.sh live $name' for live display${NC}"
}

get_elapsed() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo "0"
        return
    fi

    local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
    local elapsed=$(grep -o '"elapsed_ms":\s*[0-9]*' "$active_file" | grep -o '[0-9]*$')
    [[ -z "$elapsed" ]] && elapsed=0

    if [[ "$state" == "running" ]]; then
        local start_ms=$(grep -o '"start_ms":\s*[0-9]*' "$active_file" | grep -o '[0-9]*$')
        local now_ms=$(get_current_ms)
        local total=$((elapsed + now_ms - start_ms))
        echo "$total"
    else
        echo "$elapsed"
    fi
}

stop_stopwatch() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${RED}No stopwatch '$name' found.${NC}"
        echo "Start one with: stopwatch.sh start $name"
        exit 1
    fi

    local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)

    if [[ "$state" != "running" ]]; then
        echo -e "${YELLOW}Stopwatch '$name' is not running.${NC}"
        exit 0
    fi

    local elapsed_ms=$(get_elapsed "$name")
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local start_time=$(grep -o '"start_time":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
    local lap_count=$(grep -o '"lap":' "$active_file" | wc -l)
    local elapsed_seconds=$((elapsed_ms / 1000))

    # Save to history
    echo "$(date +%Y-%m-%d),\"$name\",$elapsed_seconds,$lap_count,\"$start_time\",\"$end_time\"" >> "$HISTORY_FILE"

    # Show final results
    echo -e "${BLUE}=== Stopwatch Stopped: $name ===${NC}"
    echo ""
    echo -e "${GREEN}Final time:${NC} $(format_duration $elapsed_ms)"
    echo -e "${CYAN}Duration:${NC} $(format_human $elapsed_seconds)"

    # Show lap times if any
    if [[ $lap_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Lap times:${NC}"
        grep -o '"lap":[0-9]*,"time":[0-9]*,"split":[0-9]*' "$active_file" | while read lap_data; do
            local lap_num=$(echo "$lap_data" | grep -o '"lap":[0-9]*' | grep -o '[0-9]*')
            local lap_time=$(echo "$lap_data" | grep -o '"time":[0-9]*' | grep -o '[0-9]*$')
            local lap_split=$(echo "$lap_data" | grep -o '"split":[0-9]*' | grep -o '[0-9]*$')
            printf "  Lap %d: %s (split: %s)\n" "$lap_num" "$(format_duration $lap_time)" "$(format_duration $lap_split)"
        done
    fi

    # Remove active file
    rm "$active_file"

    echo ""
    echo -e "${GRAY}Session saved to history.${NC}"
}

pause_stopwatch() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${RED}No stopwatch '$name' found.${NC}"
        exit 1
    fi

    local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)

    if [[ "$state" != "running" ]]; then
        echo -e "${YELLOW}Stopwatch '$name' is not running.${NC}"
        exit 0
    fi

    local elapsed_ms=$(get_elapsed "$name")
    local start_time=$(grep -o '"start_time":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
    local laps=$(grep -o '"laps":\s*\[[^]]*\]' "$active_file")

    cat > "$active_file" << EOF
{
    "name": "$name",
    "state": "paused",
    "start_ms": 0,
    "elapsed_ms": $elapsed_ms,
    "start_time": "$start_time",
    $laps
}
EOF

    echo -e "${YELLOW}Paused stopwatch:${NC} $name"
    echo -e "${CYAN}Elapsed:${NC} $(format_duration $elapsed_ms)"
    echo ""
    echo -e "${GRAY}Resume with: stopwatch.sh start $name${NC}"
}

record_lap() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${RED}No stopwatch '$name' found.${NC}"
        exit 1
    fi

    local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)

    if [[ "$state" != "running" ]]; then
        echo -e "${YELLOW}Stopwatch '$name' is not running.${NC}"
        exit 0
    fi

    local elapsed_ms=$(get_elapsed "$name")
    local lap_count=$(grep -o '"lap":' "$active_file" | wc -l)
    local new_lap=$((lap_count + 1))

    # Calculate split time (time since last lap)
    local last_lap_time=0
    if [[ $lap_count -gt 0 ]]; then
        last_lap_time=$(grep -o '"time":[0-9]*' "$active_file" | tail -1 | grep -o '[0-9]*$')
    fi
    local split_time=$((elapsed_ms - last_lap_time))

    # Read current values
    local start_ms=$(grep -o '"start_ms":\s*[0-9]*' "$active_file" | grep -o '[0-9]*$')
    local base_elapsed=$(grep -o '"elapsed_ms":\s*[0-9]*' "$active_file" | grep -o '[0-9]*$')
    local start_time=$(grep -o '"start_time":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)

    # Build new laps array
    local new_lap_entry='{"lap":'$new_lap',"time":'$elapsed_ms',"split":'$split_time'}'

    if [[ $lap_count -eq 0 ]]; then
        local laps_json="[$new_lap_entry]"
    else
        # Get existing laps entries and append new one
        local existing_laps=$(grep -o '\[{[^]]*}]' "$active_file" | head -1)
        # Remove trailing ] and add new entry
        existing_laps="${existing_laps%]}"
        local laps_json="${existing_laps},${new_lap_entry}]"
    fi

    # Rewrite the entire file with updated laps
    cat > "$active_file" << EOF
{
    "name": "$name",
    "state": "running",
    "start_ms": $start_ms,
    "elapsed_ms": $base_elapsed,
    "start_time": "$start_time",
    "laps": $laps_json
}
EOF

    echo -e "${GREEN}Lap $new_lap:${NC} $(format_duration $elapsed_ms) ${GRAY}(split: $(format_duration $split_time))${NC}"
}

show_status() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${BLUE}No active stopwatch '$name'.${NC}"
        echo "Start one with: stopwatch.sh start $name"
        exit 0
    fi

    local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
    local elapsed_ms=$(get_elapsed "$name")
    local start_time=$(grep -o '"start_time":\s*"[^"]*"' "$active_file" | cut -d'"' -f4)
    local lap_count=$(grep -o '"lap":' "$active_file" | wc -l)

    echo -e "${BLUE}=== Stopwatch: $name ===${NC}"
    echo ""

    if [[ "$state" == "running" ]]; then
        echo -e "${GREEN}Status:${NC} Running"
    else
        echo -e "${YELLOW}Status:${NC} Paused"
    fi

    echo -e "${CYAN}Elapsed:${NC} $(format_duration $elapsed_ms)"
    echo -e "${CYAN}Started:${NC} $start_time"
    echo -e "${CYAN}Laps:${NC} $lap_count"

    # Show lap times if any
    if [[ $lap_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Lap times:${NC}"
        grep -o '"lap":[0-9]*,"time":[0-9]*,"split":[0-9]*' "$active_file" | while read lap_data; do
            local lap_num=$(echo "$lap_data" | grep -o '"lap":[0-9]*' | grep -o '[0-9]*')
            local lap_time=$(echo "$lap_data" | grep -o '"time":[0-9]*' | grep -o '[0-9]*$')
            local lap_split=$(echo "$lap_data" | grep -o '"split":[0-9]*' | grep -o '[0-9]*$')
            printf "  Lap %d: %s (split: %s)\n" "$lap_num" "$(format_duration $lap_time)" "$(format_duration $lap_split)"
        done
    fi
}

reset_stopwatch() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${YELLOW}No stopwatch '$name' to reset.${NC}"
        exit 0
    fi

    rm "$active_file"
    echo -e "${RED}Reset stopwatch:${NC} $name"
}

list_stopwatches() {
    echo -e "${BLUE}=== Active Stopwatches ===${NC}"
    echo ""

    local count=0
    for file in "$ACTIVE_DIR"/*.json; do
        [[ ! -f "$file" ]] && continue
        count=$((count + 1))

        local name=$(basename "$file" .json)
        local state=$(grep -o '"state":\s*"[^"]*"' "$file" | cut -d'"' -f4)
        local elapsed_ms=$(get_elapsed "$name")

        if [[ "$state" == "running" ]]; then
            echo -e "  ${GREEN}[running]${NC} $name - $(format_duration $elapsed_ms)"
        else
            echo -e "  ${YELLOW}[paused]${NC}  $name - $(format_duration $elapsed_ms)"
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "No active stopwatches."
        echo ""
        echo "Start one with: stopwatch.sh start [name]"
    fi
}

show_history() {
    local count=${1:-10}

    echo -e "${BLUE}=== Stopwatch History (Last $count) ===${NC}"
    echo ""

    local line_count=$(tail -n +2 "$HISTORY_FILE" 2>/dev/null | wc -l)

    if [[ $line_count -eq 0 ]]; then
        echo "No history yet."
        echo "Complete a stopwatch session to see it here."
        exit 0
    fi

    tail -n +2 "$HISTORY_FILE" | tail -n "$count" | tac | while IFS=, read -r date name seconds laps start end; do
        name=$(echo "$name" | tr -d '"')
        start=$(echo "$start" | tr -d '"')
        end=$(echo "$end" | tr -d '"')

        local time_str=$(format_human $seconds)

        if [[ $laps -gt 0 ]]; then
            echo -e "  ${GREEN}$name${NC} - $time_str ${GRAY}($laps laps) - $date${NC}"
        else
            echo -e "  ${GREEN}$name${NC} - $time_str ${GRAY}- $date${NC}"
        fi
    done
}

live_display() {
    local name="${1:-default}"
    local active_file="$ACTIVE_DIR/${name}.json"

    if [[ ! -f "$active_file" ]]; then
        echo -e "${RED}No stopwatch '$name' found.${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Live Stopwatch: $name ===${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop watching (stopwatch continues running)${NC}"
    echo ""

    # Hide cursor
    tput civis 2>/dev/null

    # Restore cursor on exit
    trap 'tput cnorm 2>/dev/null; echo ""; exit 0' INT TERM

    while true; do
        local state=$(grep -o '"state":\s*"[^"]*"' "$active_file" 2>/dev/null | cut -d'"' -f4)

        if [[ ! -f "$active_file" ]] || [[ "$state" != "running" ]]; then
            tput cnorm 2>/dev/null
            echo ""
            if [[ ! -f "$active_file" ]]; then
                echo -e "${YELLOW}Stopwatch stopped.${NC}"
            else
                echo -e "${YELLOW}Stopwatch paused.${NC}"
            fi
            exit 0
        fi

        local elapsed_ms=$(get_elapsed "$name")
        local lap_count=$(grep -o '"lap":' "$active_file" 2>/dev/null | wc -l)

        # Move cursor and display
        printf "\r  ${BOLD}${GREEN}%s${NC}  ${GRAY}(Laps: %d)${NC}   " "$(format_duration $elapsed_ms)" "$lap_count"

        sleep 0.1
    done
}

show_help() {
    echo "Stopwatch - Simple stopwatch with lap times"
    echo ""
    echo "Usage:"
    echo "  stopwatch.sh start [name]   Start a stopwatch (default: 'default')"
    echo "  stopwatch.sh stop [name]    Stop and save to history"
    echo "  stopwatch.sh pause [name]   Pause the stopwatch"
    echo "  stopwatch.sh lap [name]     Record a lap time"
    echo "  stopwatch.sh status [name]  Show current elapsed time"
    echo "  stopwatch.sh reset [name]   Reset without saving"
    echo "  stopwatch.sh list           List all active stopwatches"
    echo "  stopwatch.sh history [n]    Show last n sessions (default: 10)"
    echo "  stopwatch.sh live [name]    Live updating display"
    echo "  stopwatch.sh help           Show this help"
    echo ""
    echo "Examples:"
    echo "  stopwatch.sh start workout"
    echo "  stopwatch.sh lap workout    # Record lap time"
    echo "  stopwatch.sh lap workout    # Another lap"
    echo "  stopwatch.sh stop workout   # Stop and see results"
    echo ""
    echo "  stopwatch.sh start          # Start default stopwatch"
    echo "  stopwatch.sh live           # Watch it tick"
}

case "$1" in
    start|begin)
        start_stopwatch "$2"
        ;;
    stop|end|finish)
        stop_stopwatch "$2"
        ;;
    pause)
        pause_stopwatch "$2"
        ;;
    lap|split)
        record_lap "$2"
        ;;
    status|st|show)
        show_status "$2"
        ;;
    reset|clear)
        reset_stopwatch "$2"
        ;;
    list|ls)
        list_stopwatches
        ;;
    history|hist)
        show_history "$2"
        ;;
    live|watch)
        live_display "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # No args - show list or start default
        if ls "$ACTIVE_DIR"/*.json &>/dev/null; then
            list_stopwatches
        else
            echo "No active stopwatches."
            echo ""
            echo "Usage: stopwatch.sh start [name]"
            echo "Run 'stopwatch.sh help' for more options"
        fi
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'stopwatch.sh help' for usage"
        exit 1
        ;;
esac
