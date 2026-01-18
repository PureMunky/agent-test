#!/bin/bash
#
# Wins - Gratitude and small wins journal for daily positivity
#
# Usage:
#   wins.sh add "Your win or gratitude"     - Log a win or gratitude
#   wins.sh win "Achievement"               - Log a personal win
#   wins.sh grateful "Something good"       - Log gratitude
#   wins.sh today                           - Show today's entries
#   wins.sh week                            - Show this week's wins
#   wins.sh streak                          - Show your journaling streak
#   wins.sh random                          - Show a random past win for motivation
#   wins.sh stats                           - Show statistics
#   wins.sh search "keyword"                - Search past entries
#   wins.sh export [days]                   - Export to markdown
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
WINS_FILE="$DATA_DIR/wins.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GOLD='\033[0;33m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Initialize wins file if it doesn't exist
if [[ ! -f "$WINS_FILE" ]]; then
    echo '{"entries":[]}' > "$WINS_FILE"
fi

add_entry() {
    local text="$1"
    local type="$2"  # "win" or "gratitude"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -z "$text" ]]; then
        echo "Usage: wins.sh add \"Your win or gratitude\""
        exit 1
    fi

    jq --arg text "$text" --arg type "$type" --arg date "$TODAY" --arg time "$timestamp" '
        .entries += [{
            "text": $text,
            "type": $type,
            "date": $date,
            "timestamp": $time
        }]
    ' "$WINS_FILE" > "$WINS_FILE.tmp" && mv "$WINS_FILE.tmp" "$WINS_FILE"

    local emoji=""
    local label=""
    if [[ "$type" == "win" ]]; then
        emoji="🏆"
        label="Win"
    else
        emoji="✨"
        label="Gratitude"
    fi

    echo -e "${GREEN}$label logged:${NC} $text"

    # Show a motivational message occasionally
    local count=$(jq '.entries | length' "$WINS_FILE")
    if [[ $((count % 10)) -eq 0 ]]; then
        echo ""
        echo -e "${GOLD}Milestone: You've logged $count entries! Keep celebrating the wins!${NC}"
    fi
}

show_today() {
    echo -e "${BLUE}${BOLD}=== Today's Wins & Gratitude ($TODAY) ===${NC}"
    echo ""

    local today_entries=$(jq -r --arg date "$TODAY" '.entries | map(select(.date == $date))' "$WINS_FILE")
    local count=$(echo "$today_entries" | jq 'length')

    if [[ "$count" -eq 0 || "$count" == "0" ]]; then
        echo "No entries today yet."
        echo ""
        echo "Add your first win:"
        echo "  wins.sh win \"Completed a difficult task\""
        echo ""
        echo "Or something you're grateful for:"
        echo "  wins.sh grateful \"Had a great cup of coffee\""
        return
    fi

    # Show wins
    local wins=$(echo "$today_entries" | jq -r 'map(select(.type == "win"))')
    local win_count=$(echo "$wins" | jq 'length')

    if [[ "$win_count" -gt 0 && "$win_count" != "0" ]]; then
        echo -e "${GOLD}Wins:${NC}"
        echo "$wins" | jq -r '.[] | "  🏆 \(.text)"'
        echo ""
    fi

    # Show gratitude
    local gratitude=$(echo "$today_entries" | jq -r 'map(select(.type == "gratitude"))')
    local grat_count=$(echo "$gratitude" | jq 'length')

    if [[ "$grat_count" -gt 0 && "$grat_count" != "0" ]]; then
        echo -e "${MAGENTA}Gratitude:${NC}"
        echo "$gratitude" | jq -r '.[] | "  ✨ \(.text)"'
        echo ""
    fi

    echo -e "${CYAN}Total entries today: $count${NC}"
}

show_week() {
    echo -e "${BLUE}${BOLD}=== This Week's Wins & Gratitude ===${NC}"
    echo ""

    local total_wins=0
    local total_gratitude=0

    for i in {6..0}; do
        local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local day_name=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null)

        local day_entries=$(jq -r --arg date "$date" '.entries | map(select(.date == $date))' "$WINS_FILE")
        local count=$(echo "$day_entries" | jq 'length')

        if [[ "$count" -gt 0 && "$count" != "0" ]]; then
            echo -e "${YELLOW}$day_name ($date):${NC}"

            echo "$day_entries" | jq -r '.[] |
                if .type == "win" then "  🏆 \(.text)"
                else "  ✨ \(.text)"
                end'
            echo ""

            local day_wins=$(echo "$day_entries" | jq '[.[] | select(.type == "win")] | length')
            local day_grat=$(echo "$day_entries" | jq '[.[] | select(.type == "gratitude")] | length')
            total_wins=$((total_wins + day_wins))
            total_gratitude=$((total_gratitude + day_grat))
        fi
    done

    if [[ $total_wins -eq 0 && $total_gratitude -eq 0 ]]; then
        echo "No entries this week yet. Start building your streak!"
        return
    fi

    echo -e "${CYAN}Week totals:${NC} $total_wins wins, $total_gratitude gratitude entries"
}

show_streak() {
    echo -e "${BLUE}${BOLD}=== Your Journaling Streak ===${NC}"
    echo ""

    local streak=0
    local check_date="$TODAY"

    while true; do
        local count=$(jq -r --arg date "$check_date" '.entries | map(select(.date == $date)) | length' "$WINS_FILE")

        if [[ "$count" -gt 0 && "$count" != "0" ]]; then
            ((streak++))
            check_date=$(date -d "$check_date - 1 day" +%Y-%m-%d 2>/dev/null || date -j -v-1d -f "%Y-%m-%d" "$check_date" +%Y-%m-%d 2>/dev/null)
        else
            break
        fi
    done

    # Calculate longest streak
    local dates=$(jq -r '.entries | map(.date) | unique | sort | .[]' "$WINS_FILE")
    local longest=0
    local current=0
    local prev_date=""

    while read -r date; do
        if [[ -z "$date" ]]; then continue; fi

        if [[ -z "$prev_date" ]]; then
            current=1
        else
            local expected=$(date -d "$prev_date + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$prev_date" +%Y-%m-%d 2>/dev/null)
            if [[ "$date" == "$expected" ]]; then
                ((current++))
            else
                if [[ $current -gt $longest ]]; then
                    longest=$current
                fi
                current=1
            fi
        fi
        prev_date="$date"
    done <<< "$dates"

    if [[ $current -gt $longest ]]; then
        longest=$current
    fi

    # Display streak with visual
    if [[ $streak -gt 0 ]]; then
        echo -e "${GREEN}Current streak: $streak day(s)${NC}"

        # Fire emoji for streaks
        local fire=""
        for ((i=0; i<streak && i<7; i++)); do
            fire+="🔥"
        done
        if [[ $streak -gt 7 ]]; then
            fire+="..."
        fi
        echo "  $fire"
    else
        echo -e "${YELLOW}Current streak: 0 days${NC}"
        echo "  Add an entry today to start your streak!"
    fi

    echo ""
    echo -e "${CYAN}Longest streak: $longest day(s)${NC}"

    # Total entries
    local total=$(jq '.entries | length' "$WINS_FILE")
    local total_days=$(jq '.entries | map(.date) | unique | length' "$WINS_FILE")
    echo -e "${CYAN}Total entries: $total across $total_days days${NC}"
}

show_random() {
    local count=$(jq '.entries | length' "$WINS_FILE")

    if [[ "$count" -eq 0 || "$count" == "0" ]]; then
        echo "No entries yet. Add some wins first!"
        exit 0
    fi

    echo -e "${BLUE}${BOLD}=== Random Win for Motivation ===${NC}"
    echo ""

    local entry=$(jq -r '.entries | .[rand * (. | length) | floor]' "$WINS_FILE")
    local text=$(echo "$entry" | jq -r '.text')
    local date=$(echo "$entry" | jq -r '.date')
    local type=$(echo "$entry" | jq -r '.type')

    local emoji="🏆"
    if [[ "$type" == "gratitude" ]]; then
        emoji="✨"
    fi

    echo -e "${GOLD}$emoji $text${NC}"
    echo ""
    echo -e "${GRAY}From: $date${NC}"
    echo ""
    echo -e "${CYAN}You've accomplished this before. You can do it again!${NC}"
}

show_stats() {
    echo -e "${BLUE}${BOLD}=== Wins & Gratitude Statistics ===${NC}"
    echo ""

    local total=$(jq '.entries | length' "$WINS_FILE")
    local total_wins=$(jq '[.entries[] | select(.type == "win")] | length' "$WINS_FILE")
    local total_gratitude=$(jq '[.entries[] | select(.type == "gratitude")] | length' "$WINS_FILE")
    local total_days=$(jq '.entries | map(.date) | unique | length' "$WINS_FILE")
    local first_date=$(jq -r '.entries | map(.date) | sort | first // "N/A"' "$WINS_FILE")

    echo -e "${YELLOW}Overview:${NC}"
    echo "  Total entries: $total"
    echo "  Wins logged: $total_wins"
    echo "  Gratitude logged: $total_gratitude"
    echo "  Days with entries: $total_days"
    echo "  First entry: $first_date"
    echo ""

    if [[ "$total_days" -gt 0 && "$total_days" != "0" ]]; then
        local avg=$(echo "scale=1; $total / $total_days" | bc 2>/dev/null || echo "N/A")
        echo "  Average per day: $avg entries"
    fi

    echo ""
    echo -e "${YELLOW}Recent Activity (Last 7 days):${NC}"
    echo ""

    # Visual grid for last 7 days
    for i in {6..0}; do
        local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        local day_short=$(date -d "$date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%a 2>/dev/null)
        local count=$(jq -r --arg date "$date" '.entries | map(select(.date == $date)) | length' "$WINS_FILE")

        local bar=""
        for ((j=0; j<count && j<10; j++)); do
            bar+="█"
        done

        if [[ "$date" == "$TODAY" ]]; then
            printf "  ${GREEN}%-3s${NC} %s %s\n" "$day_short" "$bar" "($count)"
        else
            printf "  %-3s %s %s\n" "$day_short" "$bar" "($count)"
        fi
    done
}

search_entries() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: wins.sh search \"keyword\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$query" '
        .entries | map(select(.text | test($q; "i")))
    ' "$WINS_FILE")

    local count=$(echo "$results" | jq 'length')

    if [[ "$count" -eq 0 || "$count" == "0" ]]; then
        echo "No entries found matching \"$query\""
        return
    fi

    echo "$results" | jq -r 'group_by(.date) | .[] |
        "\(.[ 0].date):",
        (.[] |
            if .type == "win" then "  🏆 \(.text)"
            else "  ✨ \(.text)"
            end
        ),
        ""'

    echo -e "${CYAN}Found $count matching entries${NC}"
}

export_entries() {
    local days=${1:-30}
    local cutoff=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)

    echo "# Wins & Gratitude Journal"
    echo ""
    echo "Exported: $(date '+%Y-%m-%d %H:%M')"
    echo ""

    jq -r --arg cutoff "$cutoff" '
        .entries | map(select(.date >= $cutoff)) | group_by(.date) | reverse | .[] |
        "## \(.[0].date)\n" +
        (map(
            if .type == "win" then "- 🏆 **Win:** \(.text)"
            else "- ✨ **Grateful for:** \(.text)"
            end
        ) | join("\n")) + "\n"
    ' "$WINS_FILE"
}

show_help() {
    echo "Wins - Gratitude and small wins journal for daily positivity"
    echo ""
    echo "Usage:"
    echo "  wins.sh add \"text\"         Log a win or gratitude (auto-detect)"
    echo "  wins.sh win \"text\"         Log a personal win"
    echo "  wins.sh grateful \"text\"    Log gratitude"
    echo "  wins.sh today              Show today's entries"
    echo "  wins.sh week               Show this week's entries"
    echo "  wins.sh streak             Show your journaling streak"
    echo "  wins.sh random             Show a random past win"
    echo "  wins.sh stats              Show statistics"
    echo "  wins.sh search \"keyword\"   Search past entries"
    echo "  wins.sh export [days]      Export to markdown (default: 30 days)"
    echo "  wins.sh help               Show this help"
    echo ""
    echo "Examples:"
    echo "  wins.sh win \"Finished the big project!\""
    echo "  wins.sh grateful \"Beautiful weather today\""
    echo "  wins.sh add \"Got positive feedback from team\""
    echo ""
    echo "Pro tip: Build a streak by adding at least one entry daily!"
}

# Main command handling
case "$1" in
    add)
        shift
        # Auto-detect type based on content or default to win
        text="$*"
        if [[ "$text" =~ ^(grateful|thankful|appreciate|glad) ]]; then
            add_entry "$text" "gratitude"
        else
            add_entry "$text" "win"
        fi
        ;;
    win|w)
        shift
        add_entry "$*" "win"
        ;;
    grateful|gratitude|thanks|g)
        shift
        add_entry "$*" "gratitude"
        ;;
    today|t)
        show_today
        ;;
    week|weekly)
        show_week
        ;;
    streak|s)
        show_streak
        ;;
    random|r|motivate)
        show_random
        ;;
    stats|statistics)
        show_stats
        ;;
    search|find)
        shift
        search_entries "$@"
        ;;
    export)
        export_entries "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_today
        ;;
    *)
        # Assume it's a win to add
        add_entry "$*" "win"
        ;;
esac
