#!/bin/bash
#
# Daily Kickstart - Morning routine and daily planning tool
#
# A structured morning routine helper that integrates with other productivity tools
# to help you start each day with intention and focus.
#
# Usage:
#   kickstart.sh              - Run the full morning routine
#   kickstart.sh quick        - Quick 2-minute version
#   kickstart.sh intentions   - Just set/view today's intentions
#   kickstart.sh review       - Review yesterday's progress
#   kickstart.sh history      - View past kickstart sessions
#   kickstart.sh stats        - View kickstart statistics
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TOOLS_DIR="$(dirname "$SCRIPT_DIR")"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
KICKSTART_FILE="$DATA_DIR/kickstarts.json"
INTENTIONS_FILE="$DATA_DIR/intentions.json"

mkdir -p "$DATA_DIR"

# Initialize files if they don't exist
if [[ ! -f "$KICKSTART_FILE" ]]; then
    echo '{"sessions":[]}' > "$KICKSTART_FILE"
fi

if [[ ! -f "$INTENTIONS_FILE" ]]; then
    echo '{"intentions":[]}' > "$INTENTIONS_FILE"
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

# Helper function to get a random motivational quote
get_quote() {
    local quotes=(
        "The secret of getting ahead is getting started. - Mark Twain"
        "What you do today can improve all your tomorrows. - Ralph Marston"
        "Start where you are. Use what you have. Do what you can. - Arthur Ashe"
        "The only way to do great work is to love what you do. - Steve Jobs"
        "Focus on being productive instead of busy. - Tim Ferriss"
        "Small daily improvements are the key to staggering long-term results."
        "Don't watch the clock; do what it does. Keep going. - Sam Levenson"
        "Action is the foundational key to all success. - Pablo Picasso"
        "The best time to plant a tree was 20 years ago. The second best time is now."
        "Your future is created by what you do today, not tomorrow."
        "Discipline is choosing between what you want now and what you want most."
        "Progress, not perfection."
    )
    echo "${quotes[$RANDOM % ${#quotes[@]}]}"
}

# Check if kickstart was already done today
check_today_kickstart() {
    local done_today=$(jq -r --arg date "$TODAY" '.sessions | map(select(.date == $date)) | length' "$KICKSTART_FILE")
    echo "$done_today"
}

# Display header
show_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║           🌅  DAILY KICKSTART  🌅                         ║"
    echo "  ║                 $(date '+%A, %B %d, %Y')                  ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Breathing exercise
breathing_exercise() {
    echo -e "${CYAN}=== Quick Breathing Exercise ===${NC}"
    echo ""
    echo "Take a moment to center yourself. Follow along:"
    echo ""

    for i in {1..3}; do
        echo -e "${GREEN}Breathe IN...${NC}"
        sleep 4
        echo -e "${YELLOW}Hold...${NC}"
        sleep 2
        echo -e "${BLUE}Breathe OUT...${NC}"
        sleep 4
        echo ""
    done

    echo -e "${GREEN}Great! You're centered and ready.${NC}"
    echo ""
}

# Gather data from other tools
gather_overview() {
    echo -e "${CYAN}=== Today's Overview ===${NC}"
    echo ""

    # Check for pending tasks
    if [[ -f "$TOOLS_DIR/tasks/data/tasks.json" ]]; then
        local pending_tasks=$(jq '.tasks | map(select(.completed == false)) | length' "$TOOLS_DIR/tasks/data/tasks.json" 2>/dev/null || echo "0")
        echo -e "  ${YELLOW}📋 Pending Tasks:${NC} $pending_tasks"
    fi

    # Check for deadlines
    if [[ -f "$TOOLS_DIR/deadlines/data/deadlines.json" ]]; then
        local today_deadlines=$(jq -r --arg date "$TODAY" '.deadlines | map(select(.due_date == $date and .completed == false)) | length' "$TOOLS_DIR/deadlines/data/deadlines.json" 2>/dev/null || echo "0")
        local overdue=$(jq -r --arg date "$TODAY" '.deadlines | map(select(.due_date < $date and .completed == false)) | length' "$TOOLS_DIR/deadlines/data/deadlines.json" 2>/dev/null || echo "0")
        echo -e "  ${RED}⚠️  Due Today:${NC} $today_deadlines"
        if [[ "$overdue" -gt 0 ]]; then
            echo -e "  ${RED}🚨 Overdue:${NC} $overdue"
        fi
    fi

    # Check for habits due today
    if [[ -f "$TOOLS_DIR/habits/data/habits.json" ]]; then
        local active_habits=$(jq '.habits | map(select(.active == true)) | length' "$TOOLS_DIR/habits/data/habits.json" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓ Active Habits:${NC} $active_habits"
    fi

    # Check goals in progress
    if [[ -f "$TOOLS_DIR/goals/data/goals.json" ]]; then
        local active_goals=$(jq '.goals | map(select(.status == "in_progress")) | length' "$TOOLS_DIR/goals/data/goals.json" 2>/dev/null || echo "0")
        echo -e "  ${MAGENTA}🎯 Active Goals:${NC} $active_goals"
    fi

    # Check inbox items
    if [[ -f "$TOOLS_DIR/inbox/data/inbox.json" ]]; then
        local inbox_count=$(jq '.items | map(select(.processed == false)) | length' "$TOOLS_DIR/inbox/data/inbox.json" 2>/dev/null || echo "0")
        if [[ "$inbox_count" -gt 0 ]]; then
            echo -e "  ${YELLOW}📥 Inbox Items:${NC} $inbox_count"
        fi
    fi

    # Yesterday's pomodoros
    if [[ -f "$TOOLS_DIR/pomodoro/data/pomodoro_log.txt" ]]; then
        local yesterday_poms=$(grep "^$YESTERDAY" "$TOOLS_DIR/pomodoro/data/pomodoro_log.txt" 2>/dev/null | wc -l || echo "0")
        echo -e "  ${BLUE}🍅 Yesterday's Pomodoros:${NC} $yesterday_poms"
    fi

    echo ""
}

# Set daily intentions
set_intentions() {
    echo -e "${CYAN}=== Set Your Intentions ===${NC}"
    echo ""
    echo -e "${GRAY}What are your top 3 priorities for today?${NC}"
    echo -e "${GRAY}(Press Enter after each, empty line when done)${NC}"
    echo ""

    local intentions=()
    local count=1

    while [[ $count -le 3 ]]; do
        echo -ne "${YELLOW}Priority $count:${NC} "
        read -r intention
        if [[ -z "$intention" ]]; then
            break
        fi
        intentions+=("$intention")
        ((count++))
    done

    if [[ ${#intentions[@]} -gt 0 ]]; then
        # Save intentions
        local json_array=$(printf '%s\n' "${intentions[@]}" | jq -R . | jq -s .)
        jq --arg date "$TODAY" --argjson intentions "$json_array" '
            .intentions += [{
                "date": $date,
                "items": $intentions,
                "created_at": (now | strftime("%Y-%m-%d %H:%M:%S"))
            }]
        ' "$INTENTIONS_FILE" > "$INTENTIONS_FILE.tmp" && mv "$INTENTIONS_FILE.tmp" "$INTENTIONS_FILE"

        echo ""
        echo -e "${GREEN}Intentions set for today:${NC}"
        for i in "${!intentions[@]}"; do
            echo -e "  ${CYAN}$((i+1)).${NC} ${intentions[$i]}"
        done
    fi

    echo ""
}

# View today's intentions
view_intentions() {
    local today_intentions=$(jq -r --arg date "$TODAY" '.intentions | map(select(.date == $date)) | last' "$INTENTIONS_FILE")

    if [[ "$today_intentions" != "null" && -n "$today_intentions" ]]; then
        echo -e "${CYAN}=== Today's Intentions ===${NC}"
        echo ""
        echo "$today_intentions" | jq -r '.items[]' | while read -r item; do
            echo -e "  ${CYAN}•${NC} $item"
        done
        echo ""
    else
        echo -e "${YELLOW}No intentions set for today yet.${NC}"
        echo ""
    fi
}

# Energy/mood check
energy_check() {
    echo -e "${CYAN}=== Energy Check ===${NC}"
    echo ""
    echo "How's your energy level right now?"
    echo -e "  ${GREEN}1${NC} - High energy, ready to tackle anything"
    echo -e "  ${YELLOW}2${NC} - Moderate, feeling okay"
    echo -e "  ${RED}3${NC} - Low, need to ease into the day"
    echo ""
    echo -ne "Your energy (1-3): "
    read -r energy_level

    local energy_msg=""
    case "$energy_level" in
        1)
            energy_msg="high"
            echo -e "${GREEN}Great! Start with your most challenging task.${NC}"
            ;;
        2)
            energy_msg="moderate"
            echo -e "${YELLOW}Good. Start with a medium task to build momentum.${NC}"
            ;;
        3)
            energy_msg="low"
            echo -e "${BLUE}That's okay. Start with something small and easy.${NC}"
            ;;
        *)
            energy_msg="moderate"
            echo -e "${GRAY}Starting the day at your own pace.${NC}"
            ;;
    esac

    echo "$energy_msg"
}

# Log kickstart session
log_session() {
    local energy=$1
    local intentions_count=$2

    jq --arg date "$TODAY" --arg time "$(date '+%H:%M')" --arg energy "$energy" --argjson intentions "$intentions_count" '
        .sessions += [{
            "date": $date,
            "time": $time,
            "energy_level": $energy,
            "intentions_set": $intentions
        }]
    ' "$KICKSTART_FILE" > "$KICKSTART_FILE.tmp" && mv "$KICKSTART_FILE.tmp" "$KICKSTART_FILE"
}

# Review yesterday
review_yesterday() {
    echo -e "${CYAN}=== Yesterday's Review ===${NC}"
    echo ""

    # Check yesterday's intentions
    local yesterday_intentions=$(jq -r --arg date "$YESTERDAY" '.intentions | map(select(.date == $date)) | last' "$INTENTIONS_FILE")

    if [[ "$yesterday_intentions" != "null" && -n "$yesterday_intentions" ]]; then
        echo -e "${YELLOW}Yesterday's Intentions:${NC}"
        echo "$yesterday_intentions" | jq -r '.items[]' 2>/dev/null | while read -r item; do
            echo -e "  ${GRAY}•${NC} $item"
        done
        echo ""
    fi

    # Check yesterday's completed tasks
    if [[ -f "$TOOLS_DIR/tasks/data/tasks.json" ]]; then
        echo -e "${GREEN}Tasks Completed Yesterday:${NC}"
        jq -r --arg date "$YESTERDAY" '.tasks | map(select(.completed == true and (.completed_at | startswith($date)))) | .[] | "  ✓ \(.description)"' "$TOOLS_DIR/tasks/data/tasks.json" 2>/dev/null || echo "  No tasks completed"
        echo ""
    fi

    # Check worklog entry
    if [[ -f "$TOOLS_DIR/worklog/data/entries.json" ]]; then
        local yesterday_entry=$(jq -r --arg date "$YESTERDAY" '.entries | map(select(.date == $date)) | last' "$TOOLS_DIR/worklog/data/entries.json" 2>/dev/null)
        if [[ "$yesterday_entry" != "null" && -n "$yesterday_entry" ]]; then
            echo -e "${BLUE}Yesterday's Accomplishments:${NC}"
            echo "$yesterday_entry" | jq -r '.accomplishments[]' 2>/dev/null | while read -r item; do
                echo -e "  ${GREEN}•${NC} $item"
            done
            echo ""
        fi
    fi
}

# Full morning routine
full_routine() {
    local already_done=$(check_today_kickstart)

    show_header

    if [[ "$already_done" -gt 0 ]]; then
        echo -e "${YELLOW}You've already done your kickstart today!${NC}"
        echo ""
        view_intentions
        gather_overview
        return
    fi

    # Show motivational quote
    echo -e "${GRAY}\"$(get_quote)\"${NC}"
    echo ""
    echo -e "${GRAY}Press Enter to begin your morning routine...${NC}"
    read -r

    # Step 1: Optional breathing exercise
    echo -e "Would you like a quick breathing exercise? (y/N) "
    read -r -n 1 do_breathing
    echo ""
    if [[ "$do_breathing" =~ ^[Yy]$ ]]; then
        breathing_exercise
    fi

    # Step 2: Review yesterday (if available)
    review_yesterday
    echo -e "${GRAY}Press Enter to continue...${NC}"
    read -r

    # Step 3: Show today's overview
    gather_overview

    # Step 4: Set intentions
    set_intentions
    local intentions_count=$(jq -r --arg date "$TODAY" '.intentions | map(select(.date == $date)) | last | .items | length' "$INTENTIONS_FILE" 2>/dev/null || echo "0")

    # Step 5: Energy check
    energy_level=$(energy_check)
    echo ""

    # Log the session
    log_session "$energy_level" "$intentions_count"

    # Final message
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  You're all set! Have a productive day! 🚀                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Quick kickstart (2-minute version)
quick_routine() {
    show_header

    echo -e "${GRAY}\"$(get_quote)\"${NC}"
    echo ""

    gather_overview
    view_intentions

    if [[ $(jq -r --arg date "$TODAY" '.intentions | map(select(.date == $date)) | length' "$INTENTIONS_FILE") -eq 0 ]]; then
        echo -e "${YELLOW}Quick intention - What's your ONE must-do today?${NC}"
        echo -ne "${CYAN}→${NC} "
        read -r quick_intention
        if [[ -n "$quick_intention" ]]; then
            jq --arg date "$TODAY" --arg intention "$quick_intention" '
                .intentions += [{
                    "date": $date,
                    "items": [$intention],
                    "created_at": (now | strftime("%Y-%m-%d %H:%M:%S"))
                }]
            ' "$INTENTIONS_FILE" > "$INTENTIONS_FILE.tmp" && mv "$INTENTIONS_FILE.tmp" "$INTENTIONS_FILE"
            echo -e "${GREEN}Got it! Focus on: $quick_intention${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}Quick kickstart complete. Go get it! 💪${NC}"
}

# Show kickstart history
show_history() {
    echo -e "${CYAN}=== Kickstart History (Last 14 Days) ===${NC}"
    echo ""

    jq -r '.sessions | sort_by(.date) | reverse | .[0:14] | .[] | "\(.date) \(.time) - Energy: \(.energy_level), Intentions: \(.intentions_set)"' "$KICKSTART_FILE" 2>/dev/null | while read -r line; do
        echo "  $line"
    done

    echo ""
}

# Show statistics
show_stats() {
    echo -e "${CYAN}=== Kickstart Statistics ===${NC}"
    echo ""

    local total_sessions=$(jq '.sessions | length' "$KICKSTART_FILE")
    local this_week=$(jq --arg start "$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" '.sessions | map(select(.date >= $start)) | length' "$KICKSTART_FILE")
    local avg_intentions=$(jq '[.sessions[].intentions_set] | if length > 0 then (add / length) else 0 end' "$KICKSTART_FILE")

    echo -e "  ${YELLOW}Total Sessions:${NC} $total_sessions"
    echo -e "  ${GREEN}This Week:${NC} $this_week"
    echo -e "  ${BLUE}Avg Intentions/Day:${NC} $(printf "%.1f" "$avg_intentions")"

    # Streak calculation
    local current_streak=0
    local check_date="$TODAY"
    while true; do
        local has_session=$(jq -r --arg date "$check_date" '.sessions | map(select(.date == $date)) | length' "$KICKSTART_FILE")
        if [[ "$has_session" -gt 0 ]]; then
            ((current_streak++))
            check_date=$(date -d "$check_date - 1 day" +%Y-%m-%d 2>/dev/null || date -j -v-1d -f "%Y-%m-%d" "$check_date" +%Y-%m-%d 2>/dev/null)
        else
            break
        fi
    done

    echo -e "  ${MAGENTA}Current Streak:${NC} $current_streak days"
    echo ""
}

# Show help
show_help() {
    echo "Daily Kickstart - Morning routine and daily planning tool"
    echo ""
    echo "Usage:"
    echo "  kickstart.sh              Run the full morning routine"
    echo "  kickstart.sh quick        Quick 2-minute version"
    echo "  kickstart.sh intentions   Set or view today's intentions"
    echo "  kickstart.sh review       Review yesterday's progress"
    echo "  kickstart.sh history      View past kickstart sessions"
    echo "  kickstart.sh stats        View kickstart statistics"
    echo "  kickstart.sh help         Show this help"
    echo ""
    echo "The full routine includes:"
    echo "  - Optional breathing exercise"
    echo "  - Review of yesterday's progress"
    echo "  - Today's task/deadline overview"
    echo "  - Setting daily intentions/priorities"
    echo "  - Energy level check with recommendations"
    echo ""
    echo "Integrates with: tasks, deadlines, habits, goals, inbox, pomodoro, worklog"
}

# Main
case "$1" in
    quick|q)
        quick_routine
        ;;
    intentions|int)
        if [[ -n "$2" ]]; then
            shift
            # Set intentions directly from command line
            echo -e "${CYAN}=== Setting Intentions ===${NC}"
            intentions=("$@")
            json_array=$(printf '%s\n' "${intentions[@]}" | jq -R . | jq -s .)
            jq --arg date "$TODAY" --argjson intentions "$json_array" '
                .intentions += [{
                    "date": $date,
                    "items": $intentions,
                    "created_at": (now | strftime("%Y-%m-%d %H:%M:%S"))
                }]
            ' "$INTENTIONS_FILE" > "$INTENTIONS_FILE.tmp" && mv "$INTENTIONS_FILE.tmp" "$INTENTIONS_FILE"
            echo -e "${GREEN}Intentions set!${NC}"
            view_intentions
        else
            view_intentions
        fi
        ;;
    review)
        review_yesterday
        ;;
    history|hist)
        show_history
        ;;
    stats)
        show_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        full_routine
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'kickstart.sh help' for usage"
        exit 1
        ;;
esac
