#!/bin/bash
#
# Journal - Personal daily journal for reflection and thought capture
#
# Usage:
#   journal.sh                          - Write today's journal entry
#   journal.sh write                    - Write today's journal entry
#   journal.sh add "quick thought"      - Add a quick thought to today's entry
#   journal.sh prompt                   - Get a random journaling prompt
#   journal.sh today                    - View today's entry
#   journal.sh read [date]              - Read a specific day's entry (YYYY-MM-DD)
#   journal.sh list [n]                 - List recent entries (default: 10)
#   journal.sh search "query"           - Search all journal entries
#   journal.sh mood [1-5]               - Log today's mood (1=low, 5=high)
#   journal.sh stats                    - Show journaling statistics
#   journal.sh streak                   - Show current journaling streak
#   journal.sh export [format] [days]   - Export entries (markdown/json)
#   journal.sh prompts                  - List all available prompts
#   journal.sh random                   - Read a random past entry
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
ENTRIES_DIR="$DATA_DIR/entries"
INDEX_FILE="$DATA_DIR/index.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%H:%M')

mkdir -p "$ENTRIES_DIR"

# Initialize index file if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"entries":[],"moods":{},"streak":{"current":0,"longest":0,"last_entry":null}}' > "$INDEX_FILE"
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

# Journaling prompts for inspiration
PROMPTS=(
    "What's on your mind right now?"
    "What are you grateful for today?"
    "What's one thing you learned recently?"
    "How are you feeling, and why?"
    "What's a challenge you're facing?"
    "What made you smile today?"
    "What would make today a great day?"
    "What's something you're looking forward to?"
    "Describe your ideal day."
    "What's a goal you're working toward?"
    "What's something you'd like to change?"
    "Who had an impact on you today?"
    "What's weighing on your mind?"
    "What's a small win from today?"
    "What are you curious about?"
    "How did you take care of yourself today?"
    "What's something you're proud of?"
    "What would you tell your past self?"
    "What's a lesson life has taught you?"
    "What does success mean to you right now?"
    "What boundaries do you need to set?"
    "What are you avoiding, and why?"
    "How have you grown recently?"
    "What brings you peace?"
    "What's your intention for tomorrow?"
)

get_random_prompt() {
    local idx=$((RANDOM % ${#PROMPTS[@]}))
    echo "${PROMPTS[$idx]}"
}

get_entry_file() {
    local date="${1:-$TODAY}"
    echo "$ENTRIES_DIR/$date.md"
}

entry_exists() {
    local date="${1:-$TODAY}"
    [[ -f "$(get_entry_file "$date")" ]]
}

update_streak() {
    local last_entry=$(jq -r '.streak.last_entry // ""' "$INDEX_FILE")
    local current=$(jq -r '.streak.current' "$INDEX_FILE")
    local longest=$(jq -r '.streak.longest' "$INDEX_FILE")

    local yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)

    if [[ "$last_entry" == "$TODAY" ]]; then
        # Already recorded today, no change
        return
    elif [[ "$last_entry" == "$yesterday" ]]; then
        # Continuing streak
        current=$((current + 1))
    else
        # Streak broken, start new
        current=1
    fi

    if [[ $current -gt $longest ]]; then
        longest=$current
    fi

    jq --argjson current "$current" \
       --argjson longest "$longest" \
       --arg last "$TODAY" '
        .streak.current = $current |
        .streak.longest = $longest |
        .streak.last_entry = $last
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
}

record_entry() {
    local date="$1"
    local word_count="$2"

    # Check if entry already exists in index
    local exists=$(jq -r --arg date "$date" '.entries | map(select(.date == $date)) | length' "$INDEX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        jq --arg date "$date" \
           --argjson words "$word_count" \
           --arg time "$(date '+%H:%M')" '
            .entries += [{
                "date": $date,
                "word_count": $words,
                "time": $time
            }]
        ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    else
        jq --arg date "$date" \
           --argjson words "$word_count" '
            .entries = [.entries[] | if .date == $date then .word_count = $words else . end]
        ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    fi

    update_streak
}

write_entry() {
    local entry_file=$(get_entry_file "$TODAY")
    local is_new=true

    if [[ -f "$entry_file" ]]; then
        is_new=false
    fi

    echo ""
    echo -e "${BLUE}${BOLD}=== Journal: $TODAY ===${NC}"
    echo ""

    if $is_new; then
        # Create new entry with template
        local prompt=$(get_random_prompt)

        cat > "$entry_file" << EOF
# Journal Entry - $TODAY

**Time:** $NOW

---

## Prompt
*$prompt*

## Entry


---

## Quick Thoughts


---

*Written with journal*
EOF

        echo -e "${CYAN}Prompt:${NC} $prompt"
        echo ""
    fi

    # Open in editor
    local editor="${EDITOR:-${VISUAL:-nano}}"

    echo -e "Opening in ${GREEN}$editor${NC}..."
    echo ""

    $editor "$entry_file"

    # Count words and record
    local word_count=$(wc -w < "$entry_file")
    record_entry "$TODAY" "$word_count"

    echo ""
    echo -e "${GREEN}Journal entry saved${NC} ($word_count words)"

    # Show streak
    local streak=$(jq -r '.streak.current' "$INDEX_FILE")
    if [[ $streak -gt 1 ]]; then
        echo -e "${MAGENTA}Current streak: $streak days${NC}"
    fi
}

add_quick_thought() {
    local thought="$*"

    if [[ -z "$thought" ]]; then
        echo "Usage: journal.sh add \"your thought here\""
        exit 1
    fi

    local entry_file=$(get_entry_file "$TODAY")

    if [[ ! -f "$entry_file" ]]; then
        # Create minimal entry
        cat > "$entry_file" << EOF
# Journal Entry - $TODAY

**Time:** $NOW

---

## Quick Thoughts

EOF
    fi

    # Append the thought
    echo "- [$NOW] $thought" >> "$entry_file"

    # Count words and record
    local word_count=$(wc -w < "$entry_file")
    record_entry "$TODAY" "$word_count"

    echo -e "${GREEN}Added:${NC} $thought"
}

show_prompt() {
    local prompt=$(get_random_prompt)

    echo ""
    echo -e "${BLUE}${BOLD}=== Journaling Prompt ===${NC}"
    echo ""
    echo -e "${CYAN}$prompt${NC}"
    echo ""
    echo -e "${GRAY}Start writing with: journal.sh write${NC}"
}

list_prompts() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Journaling Prompts ===${NC}"
    echo ""

    local i=1
    for prompt in "${PROMPTS[@]}"; do
        echo -e "  ${YELLOW}$i.${NC} $prompt"
        ((i++))
    done
}

view_today() {
    local entry_file=$(get_entry_file "$TODAY")

    if [[ ! -f "$entry_file" ]]; then
        echo ""
        echo -e "${YELLOW}No journal entry for today yet.${NC}"
        echo ""
        echo -e "Start writing with: ${CYAN}journal.sh write${NC}"
        echo -e "Or add a quick thought: ${CYAN}journal.sh add \"your thought\"${NC}"
        exit 0
    fi

    echo ""
    cat "$entry_file"
}

read_entry() {
    local date="$1"

    if [[ -z "$date" ]]; then
        view_today
        return
    fi

    # Handle relative dates
    case "$date" in
        yesterday)
            date=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
            ;;
        today)
            date="$TODAY"
            ;;
    esac

    local entry_file=$(get_entry_file "$date")

    if [[ ! -f "$entry_file" ]]; then
        echo -e "${YELLOW}No journal entry for $date${NC}"
        exit 1
    fi

    echo ""
    cat "$entry_file"
}

list_entries() {
    local count=${1:-10}

    local total=$(jq '.entries | length' "$INDEX_FILE")

    if [[ "$total" -eq 0 ]]; then
        echo ""
        echo "No journal entries yet."
        echo ""
        echo -e "Start your first entry with: ${CYAN}journal.sh write${NC}"
        exit 0
    fi

    echo ""
    echo -e "${BLUE}${BOLD}=== Recent Journal Entries ===${NC}"
    echo ""

    jq -r ".entries | sort_by(.date) | reverse | .[0:$count] | .[] | \"\(.date)|\(.word_count)|\(.time)\"" "$INDEX_FILE" | \
    while IFS='|' read -r date words time; do
        local day_name=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null)

        # Check if mood was logged
        local mood=$(jq -r --arg date "$date" '.moods[$date] // ""' "$INDEX_FILE")
        local mood_display=""
        if [[ -n "$mood" && "$mood" != "null" ]]; then
            local mood_emoji=""
            case "$mood" in
                1) mood_emoji="😔" ;;
                2) mood_emoji="😐" ;;
                3) mood_emoji="🙂" ;;
                4) mood_emoji="😊" ;;
                5) mood_emoji="😄" ;;
            esac
            mood_display=" $mood_emoji"
        fi

        echo -e "  ${GREEN}$date${NC} ${GRAY}($day_name)${NC}$mood_display"
        echo -e "    ${CYAN}$words words${NC} ${GRAY}written at $time${NC}"

        # Show preview (first meaningful line)
        local entry_file=$(get_entry_file "$date")
        if [[ -f "$entry_file" ]]; then
            local preview=$(grep -v "^#" "$entry_file" | grep -v "^\*" | grep -v "^---" | grep -v "^$" | head -1 | cut -c1-60)
            if [[ -n "$preview" ]]; then
                echo -e "    ${GRAY}\"$preview...\"${NC}"
            fi
        fi
        echo ""
    done
}

search_entries() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: journal.sh search \"query\""
        exit 1
    fi

    echo ""
    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local found=0

    for entry_file in "$ENTRIES_DIR"/*.md; do
        if [[ -f "$entry_file" ]]; then
            if grep -qi "$query" "$entry_file" 2>/dev/null; then
                local date=$(basename "$entry_file" .md)
                local day_name=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null)

                echo -e "${GREEN}$date${NC} ${GRAY}($day_name)${NC}"

                # Show matching lines with context
                grep -i --color=always -C 1 "$query" "$entry_file" 2>/dev/null | head -6 | while read line; do
                    echo "    $line"
                done
                echo ""

                found=$((found + 1))
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No entries found matching \"$query\""
    else
        echo -e "${CYAN}Found in $found entries${NC}"
    fi
}

log_mood() {
    local mood="$1"

    if [[ -z "$mood" ]]; then
        echo ""
        echo -e "${BLUE}=== Log Today's Mood ===${NC}"
        echo ""
        echo "Rate your mood from 1-5:"
        echo "  1 - Low/Difficult"
        echo "  2 - Below Average"
        echo "  3 - Neutral/Okay"
        echo "  4 - Good"
        echo "  5 - Great/Excellent"
        echo ""
        read -p "Your mood (1-5): " mood
    fi

    if [[ ! "$mood" =~ ^[1-5]$ ]]; then
        echo -e "${RED}Invalid mood. Please enter a number from 1-5${NC}"
        exit 1
    fi

    jq --arg date "$TODAY" --argjson mood "$mood" '
        .moods[$date] = $mood
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    local mood_text=""
    local mood_emoji=""
    case "$mood" in
        1) mood_text="Low/Difficult"; mood_emoji="😔" ;;
        2) mood_text="Below Average"; mood_emoji="😐" ;;
        3) mood_text="Neutral/Okay"; mood_emoji="🙂" ;;
        4) mood_text="Good"; mood_emoji="😊" ;;
        5) mood_text="Great/Excellent"; mood_emoji="😄" ;;
    esac

    echo -e "${GREEN}Mood logged:${NC} $mood_emoji $mood_text"
}

show_streak() {
    local current=$(jq -r '.streak.current' "$INDEX_FILE")
    local longest=$(jq -r '.streak.longest' "$INDEX_FILE")
    local last=$(jq -r '.streak.last_entry // "never"' "$INDEX_FILE")

    echo ""
    echo -e "${BLUE}${BOLD}=== Journaling Streak ===${NC}"
    echo ""

    # Visual streak display
    echo -n "  "
    for ((i=1; i<=current && i<=30; i++)); do
        echo -ne "${GREEN}█${NC}"
    done
    if [[ $current -gt 30 ]]; then
        echo -n "..."
    fi
    echo ""
    echo ""

    echo -e "  ${CYAN}Current streak:${NC} $current day(s)"
    echo -e "  ${CYAN}Longest streak:${NC} $longest day(s)"
    echo -e "  ${CYAN}Last entry:${NC} $last"
    echo ""

    if [[ "$last" != "$TODAY" ]]; then
        echo -e "${YELLOW}Don't break your streak! Write today's entry.${NC}"
    else
        echo -e "${GREEN}You've already journaled today.${NC}"
    fi
}

show_stats() {
    echo ""
    echo -e "${BLUE}${BOLD}=== Journal Statistics ===${NC}"
    echo ""

    local total_entries=$(jq '.entries | length' "$INDEX_FILE")
    local total_words=$(jq '[.entries[].word_count] | add // 0' "$INDEX_FILE")
    local avg_words=0
    if [[ $total_entries -gt 0 ]]; then
        avg_words=$((total_words / total_entries))
    fi

    local current_streak=$(jq -r '.streak.current' "$INDEX_FILE")
    local longest_streak=$(jq -r '.streak.longest' "$INDEX_FILE")

    echo -e "${CYAN}Entries:${NC}"
    echo "  Total entries: $total_entries"
    echo "  Total words: $total_words"
    echo "  Average words per entry: $avg_words"
    echo ""

    echo -e "${CYAN}Streaks:${NC}"
    echo "  Current streak: $current_streak days"
    echo "  Longest streak: $longest_streak days"
    echo ""

    # Mood stats
    local mood_count=$(jq '.moods | length' "$INDEX_FILE")
    if [[ $mood_count -gt 0 ]]; then
        local avg_mood=$(jq '[.moods | to_entries[].value] | add / length | . * 10 | floor / 10' "$INDEX_FILE")

        echo -e "${CYAN}Mood Tracking:${NC}"
        echo "  Days logged: $mood_count"
        echo "  Average mood: $avg_mood / 5"

        # Mood distribution
        echo ""
        echo "  Distribution:"
        for m in 1 2 3 4 5; do
            local count=$(jq --argjson m "$m" '[.moods | to_entries[] | select(.value == $m)] | length' "$INDEX_FILE")
            local bar=""
            for ((i=0; i<count; i++)); do
                bar+="█"
            done
            local emoji=""
            case "$m" in
                1) emoji="😔" ;;
                2) emoji="😐" ;;
                3) emoji="🙂" ;;
                4) emoji="😊" ;;
                5) emoji="😄" ;;
            esac
            echo -e "    $emoji ${MAGENTA}$bar${NC} ($count)"
        done
        echo ""
    fi

    # This week
    echo -e "${CYAN}This Week:${NC}"
    local week_entries=0
    local week_words=0

    for i in {0..6}; do
        local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
        if entry_exists "$date"; then
            week_entries=$((week_entries + 1))
            local entry_file=$(get_entry_file "$date")
            local words=$(wc -w < "$entry_file")
            week_words=$((week_words + words))
        fi
    done

    echo "  Entries: $week_entries / 7"
    echo "  Words: $week_words"
}

read_random() {
    local entries=($(jq -r '.entries[].date' "$INDEX_FILE" 2>/dev/null))

    if [[ ${#entries[@]} -eq 0 ]]; then
        echo "No past entries to read."
        exit 0
    fi

    local idx=$((RANDOM % ${#entries[@]}))
    local random_date="${entries[$idx]}"

    echo ""
    echo -e "${MAGENTA}Random entry from the past...${NC}"
    echo ""

    read_entry "$random_date"
}

export_entries() {
    local format="${1:-markdown}"
    local days="${2:-30}"

    case "$format" in
        md|markdown)
            echo "# Personal Journal"
            echo ""
            echo "Exported: $(date '+%Y-%m-%d %H:%M')"
            echo ""
            echo "---"
            echo ""

            jq -r ".entries | sort_by(.date) | reverse | .[0:$days] | .[].date" "$INDEX_FILE" | \
            while read date; do
                local entry_file=$(get_entry_file "$date")
                if [[ -f "$entry_file" ]]; then
                    cat "$entry_file"
                    echo ""
                    echo "---"
                    echo ""
                fi
            done
            ;;
        json)
            echo "{"
            echo "  \"exported\": \"$(date '+%Y-%m-%d %H:%M')\","
            echo "  \"entries\": ["

            local first=true
            jq -r ".entries | sort_by(.date) | reverse | .[0:$days] | .[].date" "$INDEX_FILE" | \
            while read date; do
                local entry_file=$(get_entry_file "$date")
                if [[ -f "$entry_file" ]]; then
                    if ! $first; then
                        echo ","
                    fi
                    first=false

                    local content=$(cat "$entry_file" | jq -Rs .)
                    local mood=$(jq -r --arg date "$date" '.moods[$date] // null' "$INDEX_FILE")

                    echo "    {"
                    echo "      \"date\": \"$date\","
                    echo "      \"mood\": $mood,"
                    echo "      \"content\": $content"
                    echo -n "    }"
                fi
            done

            echo ""
            echo "  ]"
            echo "}"
            ;;
        *)
            echo "Supported formats: markdown (md), json"
            ;;
    esac
}

show_help() {
    echo "Journal - Personal daily journal for reflection and thought capture"
    echo ""
    echo "Usage:"
    echo "  journal.sh                     Open today's journal entry"
    echo "  journal.sh write               Write/edit today's entry"
    echo "  journal.sh add \"thought\"       Add a quick thought"
    echo "  journal.sh prompt              Get a journaling prompt"
    echo "  journal.sh prompts             List all prompts"
    echo ""
    echo "  journal.sh today               View today's entry"
    echo "  journal.sh read [date]         Read entry (YYYY-MM-DD or 'yesterday')"
    echo "  journal.sh list [n]            List recent entries (default: 10)"
    echo "  journal.sh search \"query\"      Search all entries"
    echo "  journal.sh random              Read a random past entry"
    echo ""
    echo "  journal.sh mood [1-5]          Log today's mood"
    echo "  journal.sh streak              Show journaling streak"
    echo "  journal.sh stats               Show statistics"
    echo ""
    echo "  journal.sh export [format] [n] Export entries (md/json, n days)"
    echo "  journal.sh help                Show this help"
    echo ""
    echo "Examples:"
    echo "  journal.sh                   # Start writing today's entry"
    echo "  journal.sh add \"Had a great insight about the project\""
    echo "  journal.sh mood 4            # Log a good mood"
    echo "  journal.sh read yesterday"
    echo "  journal.sh search \"gratitude\""
    echo "  journal.sh export markdown 7 > week.md"
}

case "$1" in
    write|w|edit)
        write_entry
        ;;
    add|quick|q)
        shift
        add_quick_thought "$@"
        ;;
    prompt|p)
        show_prompt
        ;;
    prompts)
        list_prompts
        ;;
    today|t)
        view_today
        ;;
    read|view|show)
        read_entry "$2"
        ;;
    list|ls|entries)
        list_entries "$2"
        ;;
    search|find|grep)
        shift
        search_entries "$@"
        ;;
    mood|m)
        log_mood "$2"
        ;;
    streak|s)
        show_streak
        ;;
    stats|statistics)
        show_stats
        ;;
    random|surprise)
        read_random
        ;;
    export|backup)
        export_entries "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # Default: write today's entry
        write_entry
        ;;
    *)
        # If argument looks like a date, try to read it
        if [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            read_entry "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'journal.sh help' for usage"
            exit 1
        fi
        ;;
esac
