#!/bin/bash
#
# Work Log - Daily work journal for tracking accomplishments, blockers, and goals
#
# Usage:
#   worklog.sh add "What I worked on"      - Log work entry
#   worklog.sh done "Accomplishment"       - Log an accomplishment
#   worklog.sh blocker "Issue description" - Log a blocker
#   worklog.sh goal "Tomorrow's goal"      - Set a goal for tomorrow
#   worklog.sh today                       - Show today's log
#   worklog.sh standup                     - Format for daily standup
#   worklog.sh week                        - Show this week's summary
#   worklog.sh review [n]                  - Show last n days (default: 7)
#   worklog.sh search "keyword"            - Search all entries
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_DIR="$DATA_DIR/logs"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
TODAY_FILE="$LOG_DIR/$TODAY.json"

mkdir -p "$LOG_DIR"

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

# Initialize today's log file if it doesn't exist
init_today() {
    if [[ ! -f "$TODAY_FILE" ]]; then
        cat > "$TODAY_FILE" << EOF
{
    "date": "$TODAY",
    "entries": [],
    "accomplishments": [],
    "blockers": [],
    "goals": []
}
EOF
    fi
}

add_entry() {
    local entry="$*"
    local timestamp=$(date '+%H:%M')

    if [[ -z "$entry" ]]; then
        echo "Usage: worklog.sh add \"What you worked on\""
        exit 1
    fi

    init_today

    jq --arg entry "$entry" --arg time "$timestamp" '
        .entries += [{
            "text": $entry,
            "time": $time
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}Logged:${NC} $entry"
}

add_accomplishment() {
    local accomplishment="$*"
    local timestamp=$(date '+%H:%M')

    if [[ -z "$accomplishment" ]]; then
        echo "Usage: worklog.sh done \"Your accomplishment\""
        exit 1
    fi

    init_today

    jq --arg text "$accomplishment" --arg time "$timestamp" '
        .accomplishments += [{
            "text": $text,
            "time": $time
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}Accomplishment logged:${NC} $accomplishment"
}

add_blocker() {
    local blocker="$*"
    local timestamp=$(date '+%H:%M')

    if [[ -z "$blocker" ]]; then
        echo "Usage: worklog.sh blocker \"Blocker description\""
        exit 1
    fi

    init_today

    jq --arg text "$blocker" --arg time "$timestamp" --arg resolved "false" '
        .blockers += [{
            "text": $text,
            "time": $time,
            "resolved": false
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${RED}Blocker logged:${NC} $blocker"
}

resolve_blocker() {
    local index=$1

    if [[ -z "$index" ]]; then
        echo "Usage: worklog.sh resolve <blocker_number>"
        echo "Use 'worklog.sh today' to see blocker numbers"
        exit 1
    fi

    init_today

    # Convert to 0-based index
    local idx=$((index - 1))

    local exists=$(jq --argjson idx "$idx" '.blockers[$idx] != null' "$TODAY_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Blocker #$index not found${NC}"
        exit 1
    fi

    jq --argjson idx "$idx" '
        .blockers[$idx].resolved = true
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}Blocker #$index marked as resolved${NC}"
}

add_goal() {
    local goal="$*"

    if [[ -z "$goal" ]]; then
        echo "Usage: worklog.sh goal \"Your goal\""
        exit 1
    fi

    init_today

    jq --arg text "$goal" '
        .goals += [{
            "text": $text,
            "completed": false
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${CYAN}Goal set:${NC} $goal"
}

show_today() {
    init_today

    echo -e "${BLUE}${BOLD}=== Work Log: $TODAY ===${NC}"
    echo ""

    # Show entries
    local entries=$(jq -r '.entries | length' "$TODAY_FILE")
    if [[ "$entries" -gt 0 ]]; then
        echo -e "${YELLOW}Work Entries:${NC}"
        jq -r '.entries[] | "  [\(.time)] \(.text)"' "$TODAY_FILE" | while read line; do
            echo -e "  ${GRAY}$(echo "$line" | cut -c3-9)${NC}$(echo "$line" | cut -c10-)"
        done
        echo ""
    fi

    # Show accomplishments
    local accomplishments=$(jq -r '.accomplishments | length' "$TODAY_FILE")
    if [[ "$accomplishments" -gt 0 ]]; then
        echo -e "${GREEN}Accomplishments:${NC}"
        jq -r '.accomplishments[] | "  ✓ \(.text)"' "$TODAY_FILE"
        echo ""
    fi

    # Show blockers
    local blockers=$(jq -r '.blockers | length' "$TODAY_FILE")
    if [[ "$blockers" -gt 0 ]]; then
        echo -e "${RED}Blockers:${NC}"
        local i=1
        jq -r '.blockers[] | "\(.resolved)|\(.text)"' "$TODAY_FILE" | while IFS='|' read -r resolved text; do
            if [[ "$resolved" == "true" ]]; then
                echo -e "  ${GRAY}$i. [RESOLVED] $text${NC}"
            else
                echo -e "  ${RED}$i. $text${NC}"
            fi
            ((i++))
        done
        echo ""
    fi

    # Show goals
    local goals=$(jq -r '.goals | length' "$TODAY_FILE")
    if [[ "$goals" -gt 0 ]]; then
        echo -e "${CYAN}Goals:${NC}"
        jq -r '.goals[] | "  → \(.text)"' "$TODAY_FILE"
        echo ""
    fi

    if [[ "$entries" -eq 0 ]] && [[ "$accomplishments" -eq 0 ]] && [[ "$blockers" -eq 0 ]] && [[ "$goals" -eq 0 ]]; then
        echo "No entries yet today."
        echo ""
        echo "Quick commands:"
        echo "  worklog.sh add \"What you worked on\""
        echo "  worklog.sh done \"Accomplishment\""
        echo "  worklog.sh blocker \"Issue\""
        echo "  worklog.sh goal \"Tomorrow's goal\""
    fi
}

show_standup() {
    echo -e "${BLUE}${BOLD}=== Daily Standup ===${NC}"
    echo ""

    # Yesterday's accomplishments
    echo -e "${YELLOW}Yesterday:${NC}"
    if [[ -f "$LOG_DIR/$YESTERDAY.json" ]]; then
        local yesterday_items=$(jq -r '
            (.accomplishments[] | "  • \(.text)"),
            (.entries[] | "  • \(.text)")
        ' "$LOG_DIR/$YESTERDAY.json" 2>/dev/null)
        if [[ -n "$yesterday_items" ]]; then
            echo "$yesterday_items" | head -5
        else
            echo "  • (no entries)"
        fi
    else
        echo "  • (no log for yesterday)"
    fi
    echo ""

    # Today's plan
    echo -e "${GREEN}Today:${NC}"
    init_today
    local today_goals=$(jq -r '.goals[] | "  • \(.text)"' "$TODAY_FILE" 2>/dev/null)
    local yesterday_goals=""
    if [[ -f "$LOG_DIR/$YESTERDAY.json" ]]; then
        yesterday_goals=$(jq -r '.goals[] | "  • \(.text)"' "$LOG_DIR/$YESTERDAY.json" 2>/dev/null)
    fi

    if [[ -n "$today_goals" ]]; then
        echo "$today_goals"
    elif [[ -n "$yesterday_goals" ]]; then
        echo "$yesterday_goals"
    else
        echo "  • (no goals set)"
    fi
    echo ""

    # Blockers
    echo -e "${RED}Blockers:${NC}"
    local unresolved=$(jq -r '.blockers[] | select(.resolved == false) | "  • \(.text)"' "$TODAY_FILE" 2>/dev/null)
    if [[ -z "$unresolved" ]] && [[ -f "$LOG_DIR/$YESTERDAY.json" ]]; then
        unresolved=$(jq -r '.blockers[] | select(.resolved == false) | "  • \(.text)"' "$LOG_DIR/$YESTERDAY.json" 2>/dev/null)
    fi

    if [[ -n "$unresolved" ]]; then
        echo "$unresolved"
    else
        echo "  • None"
    fi
}

show_week() {
    echo -e "${BLUE}${BOLD}=== This Week's Summary ===${NC}"
    echo ""

    local total_entries=0
    local total_accomplishments=0
    local total_blockers=0
    local unresolved_blockers=0

    # Get dates for last 7 days
    for i in {6..0}; do
        local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local file="$LOG_DIR/$date.json"

        if [[ -f "$file" ]]; then
            local day_name=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null)
            echo -e "${YELLOW}$day_name ($date):${NC}"

            # Show accomplishments
            local accs=$(jq -r '.accomplishments[] | "  ✓ \(.text)"' "$file" 2>/dev/null)
            if [[ -n "$accs" ]]; then
                echo "$accs"
                total_accomplishments=$((total_accomplishments + $(jq '.accomplishments | length' "$file")))
            fi

            # Count entries
            total_entries=$((total_entries + $(jq '.entries | length' "$file" 2>/dev/null || echo 0)))

            echo ""
        fi
    done

    echo -e "${CYAN}Week Stats:${NC}"
    echo "  Work entries: $total_entries"
    echo "  Accomplishments: $total_accomplishments"
}

show_review() {
    local days=${1:-7}

    echo -e "${BLUE}${BOLD}=== Review (Last $days days) ===${NC}"
    echo ""

    for i in $(seq $((days - 1)) -1 0); do
        local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local file="$LOG_DIR/$date.json"

        if [[ -f "$file" ]]; then
            local day_name=$(date -d "$date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%a 2>/dev/null)
            echo -e "${YELLOW}$day_name $date:${NC}"

            # Show entries
            jq -r '
                if .entries | length > 0 then
                    .entries[] | "  • \(.text)"
                else
                    empty
                end
            ' "$file" 2>/dev/null

            # Show accomplishments
            jq -r '
                if .accomplishments | length > 0 then
                    .accomplishments[] | "  ✓ \(.text)"
                else
                    empty
                end
            ' "$file" 2>/dev/null

            echo ""
        fi
    done
}

search_logs() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: worklog.sh search \"keyword\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local found=0

    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local date=$(basename "$file" .json)
            local matches=$(jq -r --arg q "$query" '
                [
                    (.entries[] | select(.text | test($q; "i")) | "  • \(.text)"),
                    (.accomplishments[] | select(.text | test($q; "i")) | "  ✓ \(.text)"),
                    (.blockers[] | select(.text | test($q; "i")) | "  ⚠ \(.text)"),
                    (.goals[] | select(.text | test($q; "i")) | "  → \(.text)")
                ] | .[]
            ' "$file" 2>/dev/null)

            if [[ -n "$matches" ]]; then
                echo -e "${YELLOW}$date:${NC}"
                echo "$matches"
                echo ""
                found=1
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No entries found matching \"$query\""
    fi
}

export_log() {
    local format="${1:-markdown}"
    local days="${2:-7}"

    case "$format" in
        md|markdown)
            echo "# Work Log"
            echo ""
            for i in $(seq $((days - 1)) -1 0); do
                local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
                local file="$LOG_DIR/$date.json"

                if [[ -f "$file" ]]; then
                    echo "## $date"
                    echo ""

                    jq -r '
                        if .accomplishments | length > 0 then
                            "### Accomplishments\n" + (.accomplishments | map("- " + .text) | join("\n")) + "\n"
                        else empty end,
                        if .entries | length > 0 then
                            "### Work Log\n" + (.entries | map("- " + .text) | join("\n")) + "\n"
                        else empty end,
                        if .blockers | length > 0 then
                            "### Blockers\n" + (.blockers | map("- " + (if .resolved then "~~" + .text + "~~" else .text end)) | join("\n")) + "\n"
                        else empty end
                    ' "$file" 2>/dev/null
                fi
            done
            ;;
        *)
            echo "Supported formats: markdown (md)"
            ;;
    esac
}

show_help() {
    echo "Work Log - Daily work journal for standups and tracking"
    echo ""
    echo "Usage:"
    echo "  worklog.sh add \"entry\"       Log what you worked on"
    echo "  worklog.sh done \"text\"       Log an accomplishment"
    echo "  worklog.sh blocker \"issue\"   Log a blocker"
    echo "  worklog.sh resolve <n>       Mark blocker #n as resolved"
    echo "  worklog.sh goal \"text\"       Set a goal"
    echo ""
    echo "  worklog.sh today             Show today's log"
    echo "  worklog.sh standup           Format for daily standup"
    echo "  worklog.sh week              Show this week's summary"
    echo "  worklog.sh review [days]     Show last n days (default: 7)"
    echo "  worklog.sh search \"keyword\"  Search all entries"
    echo "  worklog.sh export [md] [days] Export to markdown"
    echo ""
    echo "Examples:"
    echo "  worklog.sh add \"Fixed login bug\""
    echo "  worklog.sh done \"Deployed v2.0 to production\""
    echo "  worklog.sh blocker \"Waiting on API access\""
    echo "  worklog.sh goal \"Finish code review\""
}

case "$1" in
    add|log)
        shift
        add_entry "$@"
        ;;
    done|accomplished|win)
        shift
        add_accomplishment "$@"
        ;;
    blocker|blocked|block)
        shift
        add_blocker "$@"
        ;;
    resolve|unblock)
        resolve_blocker "$2"
        ;;
    goal|plan|tomorrow)
        shift
        add_goal "$@"
        ;;
    today|show)
        show_today
        ;;
    standup|stand|daily)
        show_standup
        ;;
    week|weekly)
        show_week
        ;;
    review|history)
        show_review "$2"
        ;;
    search|find)
        shift
        search_logs "$@"
        ;;
    export)
        export_log "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_today
        ;;
    *)
        # Assume it's an entry to add
        add_entry "$@"
        ;;
esac
