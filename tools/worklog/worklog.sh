#!/bin/bash
#
# Work Log v2.0 - Daily work journal for tracking accomplishments, blockers, and goals
#
# New in v2.0:
#   - Project/tag support with #tags in entries
#   - Edit and delete entries
#   - Statistics dashboard
#   - JSON/CSV export options
#   - Archive system for old logs
#   - Improved filtering and search
#
# Usage:
#   worklog.sh add "What I worked on"         - Log work entry
#   worklog.sh add "Working on auth #backend" - Log with project tag
#   worklog.sh done "Accomplishment"          - Log an accomplishment
#   worklog.sh blocker "Issue description"    - Log a blocker
#   worklog.sh goal "Tomorrow's goal"         - Set a goal for tomorrow
#   worklog.sh today                          - Show today's log
#   worklog.sh standup                        - Format for daily standup
#   worklog.sh week                           - Show this week's summary
#   worklog.sh review [n]                     - Show last n days (default: 7)
#   worklog.sh search "keyword"               - Search all entries
#   worklog.sh stats                          - Show statistics
#   worklog.sh edit <type> <n> "new text"     - Edit an entry
#   worklog.sh delete <type> <n>              - Delete an entry
#   worklog.sh project <name>                 - Show entries for a project
#   worklog.sh projects                       - List all projects/tags
#   worklog.sh export [format] [days]         - Export (md/json/csv)
#   worklog.sh archive [days]                 - Archive logs older than days
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_DIR="$DATA_DIR/logs"
ARCHIVE_DIR="$DATA_DIR/archive"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
TODAY_FILE="$LOG_DIR/$TODAY.json"

mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"

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

# Extract #tags from text
extract_tags() {
    echo "$1" | grep -oE '#[a-zA-Z0-9_-]+' | tr '\n' ',' | sed 's/,$//'
}

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
        echo "       worklog.sh add \"Working on auth #backend #api\""
        exit 1
    fi

    init_today

    # Extract tags from entry
    local tags=$(extract_tags "$entry")
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^#//' | jq -R . | jq -s .)
    fi

    jq --arg entry "$entry" --arg time "$timestamp" --argjson tags "$tags_json" '
        .entries += [{
            "text": $entry,
            "time": $time,
            "tags": $tags
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}Logged:${NC} $entry"
    if [[ -n "$tags" ]]; then
        echo -e "${MAGENTA}Tags:${NC} $tags"
    fi
}

add_accomplishment() {
    local accomplishment="$*"
    local timestamp=$(date '+%H:%M')

    if [[ -z "$accomplishment" ]]; then
        echo "Usage: worklog.sh done \"Your accomplishment\""
        exit 1
    fi

    init_today

    local tags=$(extract_tags "$accomplishment")
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^#//' | jq -R . | jq -s .)
    fi

    jq --arg text "$accomplishment" --arg time "$timestamp" --argjson tags "$tags_json" '
        .accomplishments += [{
            "text": $text,
            "time": $time,
            "tags": $tags
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}✓ Accomplishment logged:${NC} $accomplishment"
}

add_blocker() {
    local blocker="$*"
    local timestamp=$(date '+%H:%M')

    if [[ -z "$blocker" ]]; then
        echo "Usage: worklog.sh blocker \"Blocker description\""
        exit 1
    fi

    init_today

    local tags=$(extract_tags "$blocker")
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^#//' | jq -R . | jq -s .)
    fi

    jq --arg text "$blocker" --arg time "$timestamp" --argjson tags "$tags_json" '
        .blockers += [{
            "text": $text,
            "time": $time,
            "tags": $tags,
            "resolved": false,
            "resolved_at": null
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${RED}⚠ Blocker logged:${NC} $blocker"
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

    local resolved_time=$(date '+%H:%M')
    jq --argjson idx "$idx" --arg rt "$resolved_time" '
        .blockers[$idx].resolved = true |
        .blockers[$idx].resolved_at = $rt
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}✓ Blocker #$index marked as resolved${NC}"
}

add_goal() {
    local goal="$*"

    if [[ -z "$goal" ]]; then
        echo "Usage: worklog.sh goal \"Your goal\""
        exit 1
    fi

    init_today

    local tags=$(extract_tags "$goal")
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^#//' | jq -R . | jq -s .)
    fi

    jq --arg text "$goal" --argjson tags "$tags_json" '
        .goals += [{
            "text": $text,
            "tags": $tags,
            "completed": false
        }]
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${CYAN}→ Goal set:${NC} $goal"
}

complete_goal() {
    local index=$1

    if [[ -z "$index" ]]; then
        echo "Usage: worklog.sh complete <goal_number>"
        exit 1
    fi

    init_today

    local idx=$((index - 1))

    local exists=$(jq --argjson idx "$idx" '.goals[$idx] != null' "$TODAY_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Goal #$index not found${NC}"
        exit 1
    fi

    jq --argjson idx "$idx" '.goals[$idx].completed = true' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}✓ Goal #$index completed${NC}"
}

edit_entry() {
    local type="$1"
    local index="$2"
    shift 2
    local new_text="$*"

    if [[ -z "$type" ]] || [[ -z "$index" ]] || [[ -z "$new_text" ]]; then
        echo "Usage: worklog.sh edit <type> <n> \"new text\""
        echo "Types: entry, done, blocker, goal"
        exit 1
    fi

    init_today

    local idx=$((index - 1))
    local field=""

    case "$type" in
        entry|entries|e) field="entries" ;;
        done|accomplishment|accomplishments|a) field="accomplishments" ;;
        blocker|blockers|b) field="blockers" ;;
        goal|goals|g) field="goals" ;;
        *)
            echo -e "${RED}Unknown type: $type${NC}"
            echo "Valid types: entry, done, blocker, goal"
            exit 1
            ;;
    esac

    local exists=$(jq --arg field "$field" --argjson idx "$idx" '.[$field][$idx] != null' "$TODAY_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}$type #$index not found${NC}"
        exit 1
    fi

    local tags=$(extract_tags "$new_text")
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^#//' | jq -R . | jq -s .)
    fi

    jq --arg field "$field" --argjson idx "$idx" --arg text "$new_text" --argjson tags "$tags_json" '
        .[$field][$idx].text = $text |
        .[$field][$idx].tags = $tags
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${GREEN}Updated $type #$index${NC}"
}

delete_entry() {
    local type="$1"
    local index="$2"

    if [[ -z "$type" ]] || [[ -z "$index" ]]; then
        echo "Usage: worklog.sh delete <type> <n>"
        echo "Types: entry, done, blocker, goal"
        exit 1
    fi

    init_today

    local idx=$((index - 1))
    local field=""

    case "$type" in
        entry|entries|e) field="entries" ;;
        done|accomplishment|accomplishments|a) field="accomplishments" ;;
        blocker|blockers|b) field="blockers" ;;
        goal|goals|g) field="goals" ;;
        *)
            echo -e "${RED}Unknown type: $type${NC}"
            exit 1
            ;;
    esac

    local exists=$(jq --arg field "$field" --argjson idx "$idx" '.[$field][$idx] != null' "$TODAY_FILE")
    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}$type #$index not found${NC}"
        exit 1
    fi

    jq --arg field "$field" --argjson idx "$idx" '
        .[$field] = (.[$field][:$idx] + .[$field][$idx+1:])
    ' "$TODAY_FILE" > "$TODAY_FILE.tmp" && mv "$TODAY_FILE.tmp" "$TODAY_FILE"

    echo -e "${RED}Deleted $type #$index${NC}"
}

show_today() {
    init_today

    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}                    WORK LOG: $TODAY                        ${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Show entries
    local entries=$(jq -r '.entries | length' "$TODAY_FILE")
    if [[ "$entries" -gt 0 ]]; then
        echo -e "${YELLOW}📝 Work Entries:${NC}"
        local i=1
        jq -r '.entries[] | "\(.time)|\(.text)"' "$TODAY_FILE" | while IFS='|' read -r time text; do
            echo -e "  ${GRAY}$i. [$time]${NC} $text"
            ((i++))
        done
        echo ""
    fi

    # Show accomplishments
    local accomplishments=$(jq -r '.accomplishments | length' "$TODAY_FILE")
    if [[ "$accomplishments" -gt 0 ]]; then
        echo -e "${GREEN}✓ Accomplishments:${NC}"
        local i=1
        jq -r '.accomplishments[] | "\(.text)"' "$TODAY_FILE" | while read text; do
            echo -e "  $i. $text"
            ((i++))
        done
        echo ""
    fi

    # Show blockers
    local blockers=$(jq -r '.blockers | length' "$TODAY_FILE")
    if [[ "$blockers" -gt 0 ]]; then
        echo -e "${RED}⚠ Blockers:${NC}"
        local i=1
        jq -r '.blockers[] | "\(.resolved)|\(.text)|\(.resolved_at // "")"' "$TODAY_FILE" | while IFS='|' read -r resolved text resolved_at; do
            if [[ "$resolved" == "true" ]]; then
                echo -e "  ${GRAY}$i. [RESOLVED at $resolved_at] $text${NC}"
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
        echo -e "${CYAN}→ Goals:${NC}"
        local i=1
        jq -r '.goals[] | "\(.completed)|\(.text)"' "$TODAY_FILE" | while IFS='|' read -r completed text; do
            if [[ "$completed" == "true" ]]; then
                echo -e "  ${GREEN}$i. ✓ $text${NC}"
            else
                echo -e "  $i. $text"
            fi
            ((i++))
        done
        echo ""
    fi

    if [[ "$entries" -eq 0 ]] && [[ "$accomplishments" -eq 0 ]] && [[ "$blockers" -eq 0 ]] && [[ "$goals" -eq 0 ]]; then
        echo "No entries yet today."
        echo ""
        echo "Quick commands:"
        echo "  worklog.sh add \"What you worked on #project\""
        echo "  worklog.sh done \"Accomplishment\""
        echo "  worklog.sh blocker \"Issue\""
        echo "  worklog.sh goal \"Tomorrow's goal\""
    fi
}

show_standup() {
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}                      DAILY STANDUP                         ${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Yesterday's accomplishments
    echo -e "${YELLOW}📅 Yesterday:${NC}"
    if [[ -f "$LOG_DIR/$YESTERDAY.json" ]]; then
        local yesterday_items=$(jq -r '
            (.accomplishments[] | "  • \(.text)"),
            (.entries[] | "  • \(.text)")
        ' "$LOG_DIR/$YESTERDAY.json" 2>/dev/null | head -5)
        if [[ -n "$yesterday_items" ]]; then
            echo "$yesterday_items"
        else
            echo "  • (no entries)"
        fi
    else
        echo "  • (no log for yesterday)"
    fi
    echo ""

    # Today's plan
    echo -e "${GREEN}📋 Today:${NC}"
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
    echo -e "${RED}🚧 Blockers:${NC}"
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
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}                   THIS WEEK'S SUMMARY                      ${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    local total_entries=0
    local total_accomplishments=0
    local total_blockers=0
    local resolved_blockers=0

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

            # Count entries and blockers
            total_entries=$((total_entries + $(jq '.entries | length' "$file" 2>/dev/null || echo 0)))
            total_blockers=$((total_blockers + $(jq '.blockers | length' "$file" 2>/dev/null || echo 0)))
            resolved_blockers=$((resolved_blockers + $(jq '[.blockers[] | select(.resolved == true)] | length' "$file" 2>/dev/null || echo 0)))

            echo ""
        fi
    done

    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Week Stats:${NC}"
    echo "  📝 Work entries:     $total_entries"
    echo "  ✓  Accomplishments:  $total_accomplishments"
    echo "  ⚠  Blockers:         $total_blockers (resolved: $resolved_blockers)"
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

show_stats() {
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}                    WORKLOG STATISTICS                      ${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    local total_days=0
    local total_entries=0
    local total_accomplishments=0
    local total_blockers=0
    local resolved_blockers=0
    local total_goals=0
    local completed_goals=0
    local first_date=""
    local last_date=""

    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            total_days=$((total_days + 1))
            local date=$(basename "$file" .json)
            [[ -z "$first_date" ]] && first_date="$date"
            last_date="$date"

            total_entries=$((total_entries + $(jq '.entries | length' "$file" 2>/dev/null || echo 0)))
            total_accomplishments=$((total_accomplishments + $(jq '.accomplishments | length' "$file" 2>/dev/null || echo 0)))
            total_blockers=$((total_blockers + $(jq '.blockers | length' "$file" 2>/dev/null || echo 0)))
            resolved_blockers=$((resolved_blockers + $(jq '[.blockers[] | select(.resolved == true)] | length' "$file" 2>/dev/null || echo 0)))
            total_goals=$((total_goals + $(jq '.goals | length' "$file" 2>/dev/null || echo 0)))
            completed_goals=$((completed_goals + $(jq '[.goals[] | select(.completed == true)] | length' "$file" 2>/dev/null || echo 0)))
        fi
    done

    if [[ $total_days -eq 0 ]]; then
        echo "No logs yet. Start with: worklog.sh add \"What you worked on\""
        exit 0
    fi

    echo -e "${CYAN}Overview:${NC}"
    echo "  Total days logged:   $total_days"
    echo "  Date range:          $first_date to $last_date"
    echo ""

    echo -e "${CYAN}Entries:${NC}"
    echo "  📝 Work entries:     $total_entries"
    echo "  ✓  Accomplishments:  $total_accomplishments"
    echo "  ⚠  Blockers:         $total_blockers"
    if [[ $total_blockers -gt 0 ]]; then
        local resolve_rate=$((resolved_blockers * 100 / total_blockers))
        echo "     Resolved:         $resolved_blockers ($resolve_rate%)"
    fi
    echo "  → Goals:             $total_goals"
    if [[ $total_goals -gt 0 ]]; then
        local complete_rate=$((completed_goals * 100 / total_goals))
        echo "     Completed:        $completed_goals ($complete_rate%)"
    fi
    echo ""

    # Average per day
    if [[ $total_days -gt 0 ]]; then
        echo -e "${CYAN}Averages per day:${NC}"
        local avg_entries=$((total_entries * 10 / total_days))
        local avg_accs=$((total_accomplishments * 10 / total_days))
        printf "  Entries:          %d.%d\n" $((avg_entries / 10)) $((avg_entries % 10))
        printf "  Accomplishments:  %d.%d\n" $((avg_accs / 10)) $((avg_accs % 10))
    fi
    echo ""

    # Most active days (by entry count)
    echo -e "${CYAN}Most productive days:${NC}"
    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local date=$(basename "$file" .json)
            local count=$(jq '.entries | length + .accomplishments | length' "$file" 2>/dev/null || echo 0)
            echo "$count|$date"
        fi
    done | sort -t'|' -k1 -nr | head -5 | while IFS='|' read -r count date; do
        local day_name=$(date -d "$date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%a 2>/dev/null)
        echo "  $day_name $date: $count entries"
    done
}

show_projects() {
    echo -e "${BLUE}${BOLD}=== Projects/Tags ===${NC}"
    echo ""

    local all_tags=""

    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local tags=$(jq -r '
                [.entries[].tags // [], .accomplishments[].tags // [], .blockers[].tags // [], .goals[].tags // []]
                | flatten | .[]
            ' "$file" 2>/dev/null)
            all_tags="$all_tags $tags"
        fi
    done

    if [[ -z "$all_tags" ]]; then
        echo "No project tags found."
        echo "Add tags with: worklog.sh add \"Working on feature #project\""
        exit 0
    fi

    echo "$all_tags" | tr ' ' '\n' | sort | uniq -c | sort -rn | while read count tag; do
        [[ -z "$tag" ]] && continue
        echo -e "  ${MAGENTA}#$tag${NC} ($count entries)"
    done
}

filter_by_project() {
    local project="$1"
    project="${project#\#}"  # Remove leading # if present

    if [[ -z "$project" ]]; then
        echo "Usage: worklog.sh project <name>"
        exit 1
    fi

    echo -e "${BLUE}${BOLD}=== Entries for #$project ===${NC}"
    echo ""

    local found=0

    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local date=$(basename "$file" .json)
            local matches=$(jq -r --arg p "$project" '
                [
                    (.entries[] | select(.tags // [] | index($p)) | "  • \(.text)"),
                    (.accomplishments[] | select(.tags // [] | index($p)) | "  ✓ \(.text)"),
                    (.blockers[] | select(.tags // [] | index($p)) | "  ⚠ \(.text)"),
                    (.goals[] | select(.tags // [] | index($p)) | "  → \(.text)")
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
        echo "No entries found for #$project"
    fi
}

export_log() {
    local format="${1:-markdown}"
    local days="${2:-7}"

    case "$format" in
        md|markdown)
            echo "# Work Log"
            echo ""
            echo "_Exported: $(date '+%Y-%m-%d %H:%M')_"
            echo ""
            for i in $(seq $((days - 1)) -1 0); do
                local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
                local file="$LOG_DIR/$date.json"

                if [[ -f "$file" ]]; then
                    echo "## $date"
                    echo ""

                    jq -r '
                        if .accomplishments | length > 0 then
                            "### ✓ Accomplishments\n" + (.accomplishments | map("- " + .text) | join("\n")) + "\n"
                        else empty end,
                        if .entries | length > 0 then
                            "### 📝 Work Log\n" + (.entries | map("- " + .text) | join("\n")) + "\n"
                        else empty end,
                        if .blockers | length > 0 then
                            "### ⚠ Blockers\n" + (.blockers | map("- " + (if .resolved then "~~" + .text + "~~" else .text end)) | join("\n")) + "\n"
                        else empty end,
                        if .goals | length > 0 then
                            "### → Goals\n" + (.goals | map("- " + (if .completed then "~~" + .text + "~~ ✓" else .text end)) | join("\n")) + "\n"
                        else empty end
                    ' "$file" 2>/dev/null
                fi
            done
            ;;
        json)
            echo "["
            local first=true
            for i in $(seq $((days - 1)) -1 0); do
                local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
                local file="$LOG_DIR/$date.json"

                if [[ -f "$file" ]]; then
                    [[ "$first" != "true" ]] && echo ","
                    cat "$file"
                    first=false
                fi
            done
            echo ""
            echo "]"
            ;;
        csv)
            echo "date,type,time,text,tags,resolved,completed"
            for i in $(seq $((days - 1)) -1 0); do
                local date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
                local file="$LOG_DIR/$date.json"

                if [[ -f "$file" ]]; then
                    jq -r --arg date "$date" '
                        (.entries[] | [$date, "entry", .time, .text, (.tags // [] | join(";")), "", ""] | @csv),
                        (.accomplishments[] | [$date, "accomplishment", .time, .text, (.tags // [] | join(";")), "", ""] | @csv),
                        (.blockers[] | [$date, "blocker", .time, .text, (.tags // [] | join(";")), .resolved, ""] | @csv),
                        (.goals[] | [$date, "goal", "", .text, (.tags // [] | join(";")), "", .completed] | @csv)
                    ' "$file" 2>/dev/null
                fi
            done
            ;;
        *)
            echo "Supported formats: markdown (md), json, csv"
            ;;
    esac
}

archive_logs() {
    local days_old=${1:-30}

    echo -e "${BLUE}Archiving logs older than $days_old days...${NC}"

    local cutoff_epoch=$(($(date +%s) - (days_old * 86400)))
    local archived=0

    for file in "$LOG_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local date=$(basename "$file" .json)
            local file_epoch=$(date -d "$date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%s 2>/dev/null)

            if [[ $file_epoch -lt $cutoff_epoch ]]; then
                mv "$file" "$ARCHIVE_DIR/"
                archived=$((archived + 1))
            fi
        fi
    done

    echo -e "${GREEN}Archived $archived log file(s) to $ARCHIVE_DIR${NC}"
}

show_help() {
    echo "Work Log v2.0 - Daily work journal for standups and tracking"
    echo ""
    echo "LOGGING:"
    echo "  worklog.sh add \"entry\"       Log what you worked on"
    echo "  worklog.sh done \"text\"       Log an accomplishment"
    echo "  worklog.sh blocker \"issue\"   Log a blocker"
    echo "  worklog.sh goal \"text\"       Set a goal"
    echo "  worklog.sh resolve <n>       Mark blocker #n as resolved"
    echo "  worklog.sh complete <n>      Mark goal #n as completed"
    echo ""
    echo "EDITING:"
    echo "  worklog.sh edit <type> <n> \"text\"  Edit an entry"
    echo "  worklog.sh delete <type> <n>       Delete an entry"
    echo "  Types: entry, done, blocker, goal"
    echo ""
    echo "VIEWING:"
    echo "  worklog.sh today             Show today's log"
    echo "  worklog.sh standup           Format for daily standup"
    echo "  worklog.sh week              Show this week's summary"
    echo "  worklog.sh review [days]     Show last n days (default: 7)"
    echo "  worklog.sh search \"keyword\"  Search all entries"
    echo "  worklog.sh stats             Show statistics"
    echo ""
    echo "PROJECTS:"
    echo "  worklog.sh projects          List all project tags"
    echo "  worklog.sh project <name>    Show entries for a project"
    echo "  Use #tags in entries: worklog.sh add \"Working on auth #backend\""
    echo ""
    echo "EXPORT & ARCHIVE:"
    echo "  worklog.sh export [format] [days]  Export (md/json/csv)"
    echo "  worklog.sh archive [days]          Archive old logs"
    echo ""
    echo "Examples:"
    echo "  worklog.sh add \"Fixed login bug #frontend\""
    echo "  worklog.sh done \"Deployed v2.0 to production\""
    echo "  worklog.sh blocker \"Waiting on API access #backend\""
    echo "  worklog.sh goal \"Finish code review #review\""
    echo "  worklog.sh project frontend"
    echo "  worklog.sh export json 30 > backup.json"
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
    complete)
        complete_goal "$2"
        ;;
    edit)
        shift
        edit_entry "$@"
        ;;
    delete|rm)
        delete_entry "$2" "$3"
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
    stats|statistics)
        show_stats
        ;;
    projects|tags)
        show_projects
        ;;
    project|tag)
        filter_by_project "$2"
        ;;
    export)
        export_log "$2" "$3"
        ;;
    archive)
        archive_logs "$2"
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
