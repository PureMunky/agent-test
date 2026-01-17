#!/bin/bash
#
# Pomodoro Timer - A simple command-line focus timer
#
# Usage:
#   pomodoro.sh [work_minutes] [break_minutes]
#   pomodoro.sh start       - Start a 25/5 pomodoro
#   pomodoro.sh long-break  - Take a 15 minute break
#   pomodoro.sh status      - Show today's completed pomodoros
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="$DATA_DIR/pomodoro_log.txt"

mkdir -p "$DATA_DIR"

# Default durations
WORK_MINUTES=${1:-25}
BREAK_MINUTES=${2:-5}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

notify() {
    local message="$1"
    # Try to send desktop notification
    if command -v notify-send &> /dev/null; then
        notify-send "Pomodoro" "$message"
    fi
    # Also try terminal bell
    echo -e "\a"
}

countdown() {
    local minutes=$1
    local label=$2
    local total_seconds=$((minutes * 60))
    local remaining=$total_seconds

    echo -e "${BLUE}Starting $label: $minutes minutes${NC}"
    echo ""

    while [[ $remaining -gt 0 ]]; do
        local mins=$((remaining / 60))
        local secs=$((remaining % 60))
        printf "\r${YELLOW}  %02d:%02d remaining ${NC}" $mins $secs
        sleep 1
        ((remaining--))
    done

    echo ""
    echo -e "${GREEN}$label complete!${NC}"
    notify "$label complete!"
}

log_pomodoro() {
    echo "$TODAY $(date +%H:%M) - Completed pomodoro" >> "$LOG_FILE"
}

show_status() {
    echo -e "${BLUE}=== Pomodoro Status ===${NC}"
    echo ""

    if [[ -f "$LOG_FILE" ]]; then
        local today_count=$(grep "^$TODAY" "$LOG_FILE" 2>/dev/null | wc -l)
        echo -e "Today's completed pomodoros: ${GREEN}$today_count${NC}"
        echo ""

        if [[ $today_count -gt 0 ]]; then
            echo "Today's sessions:"
            grep "^$TODAY" "$LOG_FILE" | while read line; do
                echo "  - $(echo "$line" | cut -d' ' -f2)"
            done
        fi
    else
        echo "No pomodoros logged yet."
    fi
}

case "$1" in
    status)
        show_status
        ;;
    long-break)
        echo -e "${GREEN}=== Long Break ===${NC}"
        countdown 15 "Long break"
        ;;
    help|--help|-h)
        echo "Pomodoro Timer"
        echo ""
        echo "Usage:"
        echo "  pomodoro.sh              Start default 25/5 pomodoro"
        echo "  pomodoro.sh [work] [break]  Custom durations"
        echo "  pomodoro.sh status       Show today's completions"
        echo "  pomodoro.sh long-break   15 minute break"
        echo ""
        ;;
    *)
        echo -e "${RED}=== Pomodoro Timer ===${NC}"
        echo ""

        # Work session
        countdown $WORK_MINUTES "Work session"
        log_pomodoro

        echo ""
        read -p "Start break? (Y/n) " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            countdown $BREAK_MINUTES "Break"
            echo ""
            echo -e "${GREEN}Ready for another pomodoro? Run the script again!${NC}"
        fi

        show_status
        ;;
esac
