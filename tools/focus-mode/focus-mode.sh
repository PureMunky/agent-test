#!/bin/bash
#
# Focus Mode - Distraction blocker and focus environment manager
#
# Usage:
#   focus-mode.sh start [minutes]  - Start focus mode (default: 25 min)
#   focus-mode.sh stop             - Stop focus mode
#   focus-mode.sh status           - Check if focus mode is active
#   focus-mode.sh block add <site> - Add site to block list
#   focus-mode.sh block remove <site> - Remove site from block list
#   focus-mode.sh block list       - List blocked sites
#   focus-mode.sh stats            - Show focus session statistics
#   focus-mode.sh config           - Show/edit configuration
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CONFIG_FILE="$DATA_DIR/config.json"
SESSION_FILE="$DATA_DIR/current_session.json"
HISTORY_FILE="$DATA_DIR/history.csv"
HOSTS_BACKUP="$DATA_DIR/hosts_backup"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Initialize config with defaults
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
    "blocked_sites": [
        "facebook.com",
        "twitter.com",
        "x.com",
        "instagram.com",
        "reddit.com",
        "youtube.com",
        "tiktok.com",
        "netflix.com",
        "twitch.tv"
    ],
    "default_duration": 25,
    "show_notifications": true,
    "play_sounds": true,
    "auto_dnd": true,
    "break_reminder": true
}
EOF
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

notify() {
    local message="$1"
    local urgency="${2:-normal}"

    if [[ "$(jq -r '.show_notifications' "$CONFIG_FILE")" == "true" ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send -u "$urgency" "Focus Mode" "$message"
        fi
    fi
    echo -e "\a"  # Terminal bell
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

is_focus_active() {
    if [[ -f "$SESSION_FILE" ]]; then
        local end_time=$(jq -r '.end_time' "$SESSION_FILE" 2>/dev/null)
        local current_time=$(date +%s)

        if [[ -n "$end_time" ]] && [[ "$end_time" != "null" ]] && [[ $current_time -lt $end_time ]]; then
            return 0
        fi
    fi
    return 1
}

get_remaining_time() {
    if [[ -f "$SESSION_FILE" ]]; then
        local end_time=$(jq -r '.end_time' "$SESSION_FILE" 2>/dev/null)
        local current_time=$(date +%s)

        if [[ -n "$end_time" ]] && [[ "$end_time" != "null" ]]; then
            echo $((end_time - current_time))
            return
        fi
    fi
    echo 0
}

block_sites() {
    # This creates a local hosts-style block file that can be used with browser extensions
    # or system-level blocking (requires root for /etc/hosts modification)

    local block_file="$DATA_DIR/blocked_hosts.txt"

    echo "# Focus Mode - Blocked Sites" > "$block_file"
    echo "# Generated at $(date)" >> "$block_file"
    echo "" >> "$block_file"

    jq -r '.blocked_sites[]' "$CONFIG_FILE" | while read -r site; do
        echo "127.0.0.1 $site" >> "$block_file"
        echo "127.0.0.1 www.$site" >> "$block_file"
    done

    echo -e "${CYAN}Block list generated: $block_file${NC}"
    echo ""
    echo "To apply system-wide blocking, you can:"
    echo "  1. Use a browser extension that reads hosts files"
    echo "  2. Manually append to /etc/hosts (requires sudo)"
    echo "  3. Use tools like 'Cold Turkey' or 'Freedom'"
}

unblock_sites() {
    local block_file="$DATA_DIR/blocked_hosts.txt"

    if [[ -f "$block_file" ]]; then
        rm "$block_file"
        echo -e "${GREEN}Block list cleared${NC}"
    fi
}

start_focus() {
    local duration=${1:-$(jq -r '.default_duration' "$CONFIG_FILE")}

    if is_focus_active; then
        local remaining=$(get_remaining_time)
        echo -e "${YELLOW}Focus mode is already active!${NC}"
        echo -e "Time remaining: ${CYAN}$(format_duration $remaining)${NC}"
        exit 0
    fi

    local start_time=$(date +%s)
    local end_time=$((start_time + duration * 60))
    local session_id=$(date +%Y%m%d%H%M%S)

    # Create session file
    cat > "$SESSION_FILE" << EOF
{
    "session_id": "$session_id",
    "start_time": $start_time,
    "end_time": $end_time,
    "duration_minutes": $duration,
    "date": "$TODAY",
    "status": "active"
}
EOF

    # Generate block list
    block_sites

    echo ""
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}         ${BOLD}FOCUS MODE ACTIVATED${NC}              ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Duration:${NC} $duration minutes"
    echo -e "${CYAN}End time:${NC} $(date -d "@$end_time" '+%H:%M' 2>/dev/null || date -r "$end_time" '+%H:%M' 2>/dev/null)"
    echo ""

    local sites_count=$(jq -r '.blocked_sites | length' "$CONFIG_FILE")
    echo -e "${YELLOW}Blocking $sites_count distracting sites${NC}"
    echo ""
    echo -e "${GRAY}Tips for maximum focus:${NC}"
    echo "  - Put your phone in another room"
    echo "  - Close unnecessary browser tabs"
    echo "  - Disable desktop notifications"
    echo "  - Have water nearby"
    echo ""
    echo -e "Run ${CYAN}focus-mode.sh status${NC} to check remaining time"
    echo -e "Run ${CYAN}focus-mode.sh stop${NC} to end early"
    echo ""

    notify "Focus mode started for $duration minutes. Stay focused!" "low"

    # Optional: Start a background timer that notifies when done
    if [[ "$(jq -r '.show_notifications' "$CONFIG_FILE")" == "true" ]]; then
        (
            sleep $((duration * 60))
            if is_focus_active; then
                complete_session "completed"
                notify "Focus session complete! Great work!" "critical"
            fi
        ) &>/dev/null &
        disown
    fi
}

stop_focus() {
    if ! is_focus_active && [[ ! -f "$SESSION_FILE" ]]; then
        echo -e "${YELLOW}Focus mode is not active${NC}"
        exit 0
    fi

    complete_session "stopped_early"

    echo ""
    echo -e "${YELLOW}Focus mode stopped${NC}"

    unblock_sites

    notify "Focus mode ended" "low"
}

complete_session() {
    local status="${1:-completed}"

    if [[ -f "$SESSION_FILE" ]]; then
        local session=$(cat "$SESSION_FILE")
        local start_time=$(echo "$session" | jq -r '.start_time')
        local planned_duration=$(echo "$session" | jq -r '.duration_minutes')
        local current_time=$(date +%s)
        local actual_duration=$(((current_time - start_time) / 60))

        # Log to history
        echo "$TODAY,$(date +%H:%M),$planned_duration,$actual_duration,$status" >> "$HISTORY_FILE"

        # Remove session file
        rm "$SESSION_FILE"

        if [[ "$status" == "completed" ]]; then
            echo -e "${GREEN}Session completed: $actual_duration minutes focused${NC}"
        else
            echo -e "${YELLOW}Session ended early: $actual_duration of $planned_duration minutes${NC}"
        fi
    fi
}

show_status() {
    echo ""

    if is_focus_active; then
        local remaining=$(get_remaining_time)
        local session=$(cat "$SESSION_FILE")
        local start_time=$(echo "$session" | jq -r '.start_time')
        local duration=$(echo "$session" | jq -r '.duration_minutes')
        local elapsed=$(($(date +%s) - start_time))
        local progress=$((elapsed * 100 / (duration * 60)))

        echo -e "${BOLD}${GREEN}FOCUS MODE: ACTIVE${NC}"
        echo ""
        echo -e "  Started: $(date -d "@$start_time" '+%H:%M' 2>/dev/null || date -r "$start_time" '+%H:%M' 2>/dev/null)"
        echo -e "  Duration: $duration minutes"
        echo -e "  Elapsed: $(format_duration $elapsed)"
        echo -e "  Remaining: ${CYAN}$(format_duration $remaining)${NC}"
        echo ""

        # Progress bar
        local bar_width=30
        local filled=$((progress * bar_width / 100))
        local empty=$((bar_width - filled))

        printf "  Progress: ["
        printf "${GREEN}"
        for ((i=0; i<filled; i++)); do printf "█"; done
        printf "${NC}"
        for ((i=0; i<empty; i++)); do printf "░"; done
        printf "] %d%%\n" $progress
        echo ""
    else
        echo -e "${BOLD}${GRAY}FOCUS MODE: INACTIVE${NC}"
        echo ""
        echo "Start a focus session with: focus-mode.sh start [minutes]"
        echo ""

        # Show today's stats
        if [[ -f "$HISTORY_FILE" ]]; then
            local today_sessions=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | wc -l)
            local today_minutes=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | awk -F, '{sum += $4} END {print sum+0}')

            if [[ $today_sessions -gt 0 ]]; then
                echo -e "${CYAN}Today's Focus:${NC}"
                echo "  Sessions: $today_sessions"
                echo "  Total focused time: ${today_minutes}m"
                echo ""
            fi
        fi
    fi
}

manage_blocklist() {
    local action="$1"
    local site="$2"

    case "$action" in
        add)
            if [[ -z "$site" ]]; then
                echo "Usage: focus-mode.sh block add <site>"
                exit 1
            fi

            # Remove protocol and www if present
            site=$(echo "$site" | sed 's|https\?://||' | sed 's|^www\.||' | sed 's|/.*||')

            # Check if already exists
            if jq -e --arg site "$site" '.blocked_sites | index($site)' "$CONFIG_FILE" > /dev/null 2>&1; then
                echo -e "${YELLOW}$site is already in the block list${NC}"
                exit 0
            fi

            jq --arg site "$site" '.blocked_sites += [$site]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}Added to block list:${NC} $site"
            ;;

        remove|rm)
            if [[ -z "$site" ]]; then
                echo "Usage: focus-mode.sh block remove <site>"
                exit 1
            fi

            site=$(echo "$site" | sed 's|https\?://||' | sed 's|^www\.||' | sed 's|/.*||')

            jq --arg site "$site" '.blocked_sites = [.blocked_sites[] | select(. != $site)]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            echo -e "${RED}Removed from block list:${NC} $site"
            ;;

        list|ls)
            echo -e "${BLUE}Blocked Sites:${NC}"
            echo ""
            jq -r '.blocked_sites[]' "$CONFIG_FILE" | while read -r s; do
                echo "  - $s"
            done
            echo ""
            ;;

        *)
            echo "Usage:"
            echo "  focus-mode.sh block add <site>    - Add site to block list"
            echo "  focus-mode.sh block remove <site> - Remove site from block list"
            echo "  focus-mode.sh block list          - List all blocked sites"
            ;;
    esac
}

show_stats() {
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}         ${BOLD}FOCUS MODE STATISTICS${NC}             ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        echo "No focus sessions recorded yet."
        echo "Start your first session with: focus-mode.sh start"
        exit 0
    fi

    # Today's stats
    local today_sessions=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | wc -l)
    local today_minutes=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | awk -F, '{sum += $4} END {print sum+0}')
    local today_completed=$(grep "^$TODAY" "$HISTORY_FILE" 2>/dev/null | grep "completed" | wc -l)

    echo -e "${CYAN}Today ($TODAY):${NC}"
    echo "  Sessions: $today_sessions (${today_completed} completed)"
    echo "  Focused time: ${today_minutes} minutes"
    echo ""

    # This week's stats
    local week_sessions=0
    local week_minutes=0
    local week_completed=0

    for ((i=0; i<7; i++)); do
        local date=$(date -d "$TODAY - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local day_sessions=$(grep "^$date" "$HISTORY_FILE" 2>/dev/null | wc -l)
        local day_minutes=$(grep "^$date" "$HISTORY_FILE" 2>/dev/null | awk -F, '{sum += $4} END {print sum+0}')
        local day_completed=$(grep "^$date" "$HISTORY_FILE" 2>/dev/null | grep "completed" | wc -l)

        week_sessions=$((week_sessions + day_sessions))
        week_minutes=$((week_minutes + day_minutes))
        week_completed=$((week_completed + day_completed))
    done

    echo -e "${CYAN}This Week:${NC}"
    echo "  Sessions: $week_sessions (${week_completed} completed)"
    echo "  Focused time: ${week_minutes} minutes (~$((week_minutes / 60)) hours)"
    echo "  Average per day: $((week_minutes / 7)) minutes"
    echo ""

    # All-time stats
    local total_sessions=$(wc -l < "$HISTORY_FILE")
    local total_minutes=$(awk -F, '{sum += $4} END {print sum+0}' "$HISTORY_FILE")
    local total_completed=$(grep "completed" "$HISTORY_FILE" | wc -l)
    local completion_rate=0
    if [[ $total_sessions -gt 0 ]]; then
        completion_rate=$((total_completed * 100 / total_sessions))
    fi

    echo -e "${CYAN}All Time:${NC}"
    echo "  Total sessions: $total_sessions"
    echo "  Completed: $total_completed ($completion_rate%)"
    echo "  Total focused time: $((total_minutes / 60)) hours ${total_minutes % 60} minutes"
    echo ""

    # Recent sessions
    echo -e "${CYAN}Recent Sessions:${NC}"
    tail -5 "$HISTORY_FILE" | while IFS=, read -r date time planned actual status; do
        local status_icon="✓"
        local status_color="$GREEN"
        if [[ "$status" != "completed" ]]; then
            status_icon="○"
            status_color="$YELLOW"
        fi
        echo -e "  ${status_color}${status_icon}${NC} $date $time - ${actual}m / ${planned}m"
    done
    echo ""
}

show_config() {
    echo -e "${BLUE}Focus Mode Configuration:${NC}"
    echo ""
    echo "  Default duration: $(jq -r '.default_duration' "$CONFIG_FILE") minutes"
    echo "  Show notifications: $(jq -r '.show_notifications' "$CONFIG_FILE")"
    echo "  Play sounds: $(jq -r '.play_sounds' "$CONFIG_FILE")"
    echo "  Auto DND: $(jq -r '.auto_dnd' "$CONFIG_FILE")"
    echo "  Break reminder: $(jq -r '.break_reminder' "$CONFIG_FILE")"
    echo ""
    echo "  Blocked sites: $(jq -r '.blocked_sites | length' "$CONFIG_FILE")"
    echo ""
    echo "Edit configuration at: $CONFIG_FILE"
}

show_help() {
    echo "Focus Mode - Distraction blocker and focus environment manager"
    echo ""
    echo "Usage:"
    echo "  focus-mode.sh start [minutes]     Start focus mode (default: 25 min)"
    echo "  focus-mode.sh stop                Stop focus mode early"
    echo "  focus-mode.sh status              Check current status"
    echo "  focus-mode.sh stats               Show focus statistics"
    echo "  focus-mode.sh block add <site>    Add site to block list"
    echo "  focus-mode.sh block remove <site> Remove site from block list"
    echo "  focus-mode.sh block list          List blocked sites"
    echo "  focus-mode.sh config              Show configuration"
    echo "  focus-mode.sh help                Show this help"
    echo ""
    echo "Examples:"
    echo "  focus-mode.sh start               # Start 25-minute focus session"
    echo "  focus-mode.sh start 45            # Start 45-minute focus session"
    echo "  focus-mode.sh block add hacker.news"
    echo ""
    echo "The tool generates a block list that can be used with:"
    echo "  - Browser extensions (like uBlock Origin)"
    echo "  - System hosts file (/etc/hosts)"
    echo "  - Third-party focus apps"
}

case "$1" in
    start|s)
        start_focus "$2"
        ;;
    stop|end)
        stop_focus
        ;;
    status|st)
        show_status
        ;;
    block|b)
        shift
        manage_blocklist "$@"
        ;;
    stats|statistics)
        show_stats
        ;;
    config|cfg)
        show_config
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_status
        ;;
    *)
        # Try parsing as minutes for quick start
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            start_focus "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'focus-mode.sh help' for usage"
            exit 1
        fi
        ;;
esac
