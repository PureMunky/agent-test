#!/bin/bash
#
# Readlist - Reading list and learning content tracker
#
# Track articles, books, videos, tutorials, and other learning content
# with status, priority, progress, and notes.
#
# Usage:
#   readlist.sh add <url/title> [options]    - Add item to reading list
#   readlist.sh list [status] [--type TYPE]  - List items (filter by status/type)
#   readlist.sh view <id>                    - View item details
#   readlist.sh start <id>                   - Mark item as in-progress
#   readlist.sh progress <id> <progress>     - Update progress (e.g., "50%", "chapter 5")
#   readlist.sh done <id>                    - Mark item as completed
#   readlist.sh abandon <id>                 - Mark item as abandoned
#   readlist.sh note <id> "note text"        - Add a note/takeaway to an item
#   readlist.sh priority <id> <1-5>          - Set priority (1=highest)
#   readlist.sh search "query"               - Search reading list
#   readlist.sh stats                        - Show reading statistics
#   readlist.sh remove <id>                  - Remove an item
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
READLIST_FILE="$DATA_DIR/readlist.json"

mkdir -p "$DATA_DIR"

# Initialize readlist file if it doesn't exist
if [[ ! -f "$READLIST_FILE" ]]; then
    echo '{"items":[],"next_id":1,"stats":{"completed_count":0,"total_time_spent":0}}' > "$READLIST_FILE"
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

# Content type icons (fallback to text)
declare -A TYPE_ICONS=(
    ["article"]="[ART]"
    ["book"]="[BOOK]"
    ["video"]="[VID]"
    ["tutorial"]="[TUT]"
    ["podcast"]="[POD]"
    ["course"]="[CRS]"
    ["paper"]="[PAP]"
    ["other"]="[---]"
)

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Validate URL format
is_url() {
    [[ "$1" =~ ^https?:// ]]
}

# Parse time estimate to minutes
parse_time() {
    local time="$1"
    local minutes=0

    if [[ "$time" =~ ^([0-9]+)h$ ]]; then
        minutes=$((${BASH_REMATCH[1]} * 60))
    elif [[ "$time" =~ ^([0-9]+)m$ ]]; then
        minutes=${BASH_REMATCH[1]}
    elif [[ "$time" =~ ^([0-9]+)$ ]]; then
        minutes=$1
    else
        minutes=0
    fi

    echo "$minutes"
}

# Format minutes to human readable
format_time() {
    local minutes=$1
    if [[ $minutes -ge 60 ]]; then
        local hours=$((minutes / 60))
        local mins=$((minutes % 60))
        if [[ $mins -eq 0 ]]; then
            echo "${hours}h"
        else
            echo "${hours}h ${mins}m"
        fi
    else
        echo "${minutes}m"
    fi
}

add_item() {
    local title=""
    local url=""
    local content_type="article"
    local priority=3
    local time_estimate=0
    local tags=()
    local author=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--type)
                content_type="$2"
                shift 2
                ;;
            -p|--priority)
                priority="$2"
                shift 2
                ;;
            -e|--estimate)
                time_estimate=$(parse_time "$2")
                shift 2
                ;;
            --tags)
                IFS=',' read -ra tags <<< "$2"
                shift 2
                ;;
            -a|--author)
                author="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                exit 1
                ;;
            *)
                if is_url "$1"; then
                    url="$1"
                else
                    title="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$title" ]] && [[ -z "$url" ]]; then
        echo "Usage: readlist.sh add <url or title> [options]"
        echo ""
        echo "Options:"
        echo "  -t, --type TYPE      Content type: article, book, video, tutorial, podcast, course, paper"
        echo "  -p, --priority N     Priority 1-5 (1=highest, default: 3)"
        echo "  -e, --estimate TIME  Estimated time (e.g., 30m, 2h)"
        echo "  -a, --author NAME    Author/creator name"
        echo "  --tags TAGS          Comma-separated tags"
        echo ""
        echo "Examples:"
        echo "  readlist.sh add \"Clean Code\" -t book -a \"Robert Martin\" -e 10h"
        echo "  readlist.sh add https://example.com/article -t article -e 15m"
        echo "  readlist.sh add \"Rust Tutorial\" -t tutorial --tags rust,programming -p 2"
        exit 1
    fi

    # If we have URL but no title, use URL as title
    if [[ -z "$title" ]]; then
        title="$url"
    fi

    # Validate content type
    local valid_types="article book video tutorial podcast course paper other"
    if [[ ! " $valid_types " =~ " $content_type " ]]; then
        echo -e "${YELLOW}Warning: Unknown type '$content_type', using 'other'${NC}"
        content_type="other"
    fi

    # Validate priority
    if [[ ! "$priority" =~ ^[1-5]$ ]]; then
        echo -e "${YELLOW}Warning: Invalid priority, using 3${NC}"
        priority=3
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local next_id=$(jq -r '.next_id' "$READLIST_FILE")

    # Build tags JSON
    local tags_json="[]"
    if [[ ${#tags[@]} -gt 0 ]]; then
        tags_json=$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)
    fi

    jq --arg title "$title" \
       --arg url "$url" \
       --arg type "$content_type" \
       --argjson priority "$priority" \
       --argjson time "$time_estimate" \
       --arg author "$author" \
       --argjson tags "$tags_json" \
       --arg ts "$timestamp" \
       --argjson id "$next_id" '
        .items += [{
            "id": $id,
            "title": $title,
            "url": $url,
            "type": $type,
            "status": "unread",
            "priority": $priority,
            "time_estimate": $time,
            "time_spent": 0,
            "author": $author,
            "tags": $tags,
            "progress": "",
            "notes": [],
            "created": $ts,
            "started": null,
            "completed": null
        }] |
        .next_id = ($id + 1)
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    echo -e "${GREEN}Added to reading list (#$next_id):${NC}"
    echo -e "  ${BOLD}$title${NC}"
    echo -e "  ${GRAY}Type: $content_type | Priority: $priority${NC}"
    if [[ -n "$url" ]] && [[ "$url" != "$title" ]]; then
        echo -e "  ${GRAY}URL: $url${NC}"
    fi
    if [[ $time_estimate -gt 0 ]]; then
        echo -e "  ${GRAY}Est. time: $(format_time $time_estimate)${NC}"
    fi
}

list_items() {
    local filter_status=""
    local filter_type=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                filter_type="$2"
                shift 2
                ;;
            unread|in-progress|completed|abandoned)
                filter_status="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    local count=$(jq '.items | length' "$READLIST_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "Reading list is empty."
        echo "Add something with: readlist.sh add <title or url>"
        exit 0
    fi

    # Build filter query
    local filter_query=".items"
    local title_suffix=""

    if [[ -n "$filter_status" ]]; then
        filter_query="$filter_query | map(select(.status == \"$filter_status\"))"
        title_suffix=" ($filter_status)"
    fi

    if [[ -n "$filter_type" ]]; then
        filter_query="$filter_query | map(select(.type == \"$filter_type\"))"
        title_suffix="$title_suffix [$filter_type]"
    fi

    local filtered_count=$(jq -r "$filter_query | length" "$READLIST_FILE")

    echo -e "${BLUE}=== Reading List$title_suffix ($filtered_count items) ===${NC}"
    echo ""

    if [[ "$filtered_count" -eq 0 ]]; then
        echo "No items match the filter."
        exit 0
    fi

    # Sort by priority (ascending) then by created (descending)
    jq -r "$filter_query | sort_by(.priority, .created) | .[] | \"\(.id)|\(.title)|\(.type)|\(.status)|\(.priority)|\(.progress)\"" "$READLIST_FILE" | \
    while IFS='|' read -r id title type status priority progress; do
        local icon="${TYPE_ICONS[$type]:-[---]}"
        local priority_color=""

        # Priority coloring
        case "$priority" in
            1) priority_color="${RED}P1${NC}" ;;
            2) priority_color="${YELLOW}P2${NC}" ;;
            3) priority_color="${NC}P3${NC}" ;;
            4) priority_color="${GRAY}P4${NC}" ;;
            5) priority_color="${GRAY}P5${NC}" ;;
        esac

        # Status coloring
        local status_indicator=""
        case "$status" in
            unread)      status_indicator="${GRAY}[ ]${NC}" ;;
            in-progress) status_indicator="${YELLOW}[~]${NC}" ;;
            completed)   status_indicator="${GREEN}[x]${NC}" ;;
            abandoned)   status_indicator="${RED}[-]${NC}" ;;
        esac

        # Truncate title if too long
        local display_title="$title"
        if [[ ${#display_title} -gt 50 ]]; then
            display_title="${display_title:0:47}..."
        fi

        printf "  %s ${CYAN}%s${NC} $priority_color ${BOLD}%s${NC}" "$status_indicator" "$icon" "$display_title"

        # Show progress if in-progress
        if [[ "$status" == "in-progress" ]] && [[ -n "$progress" ]]; then
            printf " ${MAGENTA}(%s)${NC}" "$progress"
        fi

        printf " ${GRAY}#%d${NC}\n" "$id"
    done

    echo ""
}

view_item() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh view <id>"
        exit 1
    fi

    local item=$(jq -r --argjson id "$id" '.items[] | select(.id == $id)' "$READLIST_FILE")

    if [[ -z "$item" ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local title=$(echo "$item" | jq -r '.title')
    local url=$(echo "$item" | jq -r '.url // ""')
    local type=$(echo "$item" | jq -r '.type')
    local status=$(echo "$item" | jq -r '.status')
    local priority=$(echo "$item" | jq -r '.priority')
    local time_estimate=$(echo "$item" | jq -r '.time_estimate')
    local time_spent=$(echo "$item" | jq -r '.time_spent')
    local author=$(echo "$item" | jq -r '.author // ""')
    local progress=$(echo "$item" | jq -r '.progress // ""')
    local created=$(echo "$item" | jq -r '.created')
    local started=$(echo "$item" | jq -r '.started // ""')
    local completed=$(echo "$item" | jq -r '.completed // ""')
    local tags=$(echo "$item" | jq -r '.tags | join(", ")')
    local notes_count=$(echo "$item" | jq '.notes | length')

    echo -e "${BLUE}=== Reading List Item #$id ===${NC}"
    echo ""
    echo -e "${BOLD}$title${NC}"
    echo ""
    echo -e "  ${CYAN}Type:${NC}     $type"
    echo -e "  ${CYAN}Status:${NC}   $status"
    echo -e "  ${CYAN}Priority:${NC} $priority"

    if [[ -n "$author" ]]; then
        echo -e "  ${CYAN}Author:${NC}   $author"
    fi

    if [[ -n "$url" ]]; then
        echo -e "  ${CYAN}URL:${NC}      $url"
    fi

    if [[ $time_estimate -gt 0 ]]; then
        echo -e "  ${CYAN}Est. Time:${NC} $(format_time $time_estimate)"
    fi

    if [[ $time_spent -gt 0 ]]; then
        echo -e "  ${CYAN}Time Spent:${NC} $(format_time $time_spent)"
    fi

    if [[ -n "$progress" ]]; then
        echo -e "  ${CYAN}Progress:${NC} $progress"
    fi

    if [[ -n "$tags" ]]; then
        echo -e "  ${CYAN}Tags:${NC}     $tags"
    fi

    echo ""
    echo -e "  ${GRAY}Added: $created${NC}"
    if [[ -n "$started" ]] && [[ "$started" != "null" ]]; then
        echo -e "  ${GRAY}Started: $started${NC}"
    fi
    if [[ -n "$completed" ]] && [[ "$completed" != "null" ]]; then
        echo -e "  ${GRAY}Completed: $completed${NC}"
    fi

    # Show notes if any
    if [[ $notes_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Notes ($notes_count):${NC}"
        echo "$item" | jq -r '.notes[] | "  - \(.text) (\(.date))"'
    fi
}

start_item() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh start <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --argjson id "$id" --arg ts "$timestamp" '
        .items = [.items[] | if .id == $id then .status = "in-progress" | .started = $ts else . end]
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${YELLOW}Started:${NC} $title"
}

update_progress() {
    local id="$1"
    local progress="$2"

    if [[ -z "$id" ]] || [[ -z "$progress" ]]; then
        echo "Usage: readlist.sh progress <id> <progress>"
        echo ""
        echo "Examples:"
        echo "  readlist.sh progress 1 \"50%\""
        echo "  readlist.sh progress 2 \"Chapter 5\""
        echo "  readlist.sh progress 3 \"Page 120/350\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg progress "$progress" '
        .items = [.items[] | if .id == $id then .progress = $progress | .status = "in-progress" else . end]
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${GREEN}Updated progress:${NC} $title -> $progress"
}

complete_item() {
    local id="$1"
    local time_spent="$2"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh done <id> [time_spent]"
        echo ""
        echo "Examples:"
        echo "  readlist.sh done 1"
        echo "  readlist.sh done 2 2h"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local time_mins=0

    if [[ -n "$time_spent" ]]; then
        time_mins=$(parse_time "$time_spent")
    fi

    jq --argjson id "$id" --arg ts "$timestamp" --argjson time "$time_mins" '
        .items = [.items[] | if .id == $id then .status = "completed" | .completed = $ts | .time_spent = ($time + .time_spent) else . end] |
        .stats.completed_count += 1 |
        .stats.total_time_spent += $time
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${GREEN}Completed:${NC} $title"

    if [[ $time_mins -gt 0 ]]; then
        echo -e "${GRAY}Time logged: $(format_time $time_mins)${NC}"
    fi
}

abandon_item() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh abandon <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" '
        .items = [.items[] | if .id == $id then .status = "abandoned" else . end]
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${RED}Abandoned:${NC} $title"
}

add_note() {
    local id="$1"
    shift
    local note="$*"

    if [[ -z "$id" ]] || [[ -z "$note" ]]; then
        echo "Usage: readlist.sh note <id> \"note text\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d')

    jq --argjson id "$id" --arg note "$note" --arg date "$timestamp" '
        .items = [.items[] | if .id == $id then .notes += [{"text": $note, "date": $date}] else . end]
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${GREEN}Note added to:${NC} $title"
}

set_priority() {
    local id="$1"
    local priority="$2"

    if [[ -z "$id" ]] || [[ -z "$priority" ]]; then
        echo "Usage: readlist.sh priority <id> <1-5>"
        exit 1
    fi

    if [[ ! "$priority" =~ ^[1-5]$ ]]; then
        echo -e "${RED}Priority must be 1-5 (1=highest)${NC}"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --argjson priority "$priority" '
        .items = [.items[] | if .id == $id then .priority = $priority else . end]
    ' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")
    echo -e "${GREEN}Priority set:${NC} $title -> P$priority"
}

search_items() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: readlist.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$query" '
        .items | map(select(
            (.title | ascii_downcase | contains($q | ascii_downcase)) or
            (.author | ascii_downcase | contains($q | ascii_downcase)) or
            (.tags | map(ascii_downcase) | any(contains($q | ascii_downcase)))
        )) | .[] | "\(.id)|\(.title)|\(.type)|\(.status)"
    ' "$READLIST_FILE")

    if [[ -z "$results" ]]; then
        echo "No items found matching \"$query\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id title type status; do
        local icon="${TYPE_ICONS[$type]:-[---]}"
        echo -e "  ${CYAN}$icon${NC} ${BOLD}$title${NC} ${GRAY}($status)${NC} #$id"
    done
}

show_stats() {
    echo -e "${BLUE}=== Reading List Statistics ===${NC}"
    echo ""

    local total=$(jq '.items | length' "$READLIST_FILE")
    local unread=$(jq '.items | map(select(.status == "unread")) | length' "$READLIST_FILE")
    local in_progress=$(jq '.items | map(select(.status == "in-progress")) | length' "$READLIST_FILE")
    local completed=$(jq '.items | map(select(.status == "completed")) | length' "$READLIST_FILE")
    local abandoned=$(jq '.items | map(select(.status == "abandoned")) | length' "$READLIST_FILE")
    local total_time=$(jq '.stats.total_time_spent // 0' "$READLIST_FILE")

    echo -e "${BOLD}Status Breakdown:${NC}"
    echo -e "  ${GRAY}[ ]${NC} Unread:      $unread"
    echo -e "  ${YELLOW}[~]${NC} In Progress: $in_progress"
    echo -e "  ${GREEN}[x]${NC} Completed:   $completed"
    echo -e "  ${RED}[-]${NC} Abandoned:   $abandoned"
    echo -e "  ${NC}    Total:       $total"
    echo ""

    # Content type breakdown
    echo -e "${BOLD}By Content Type:${NC}"
    jq -r '.items | group_by(.type) | map({type: .[0].type, count: length}) | sort_by(.count) | reverse | .[] | "  \(.type): \(.count)"' "$READLIST_FILE"
    echo ""

    # Time stats
    if [[ $total_time -gt 0 ]]; then
        echo -e "${BOLD}Time:${NC}"
        echo -e "  Total time logged: $(format_time $total_time)"
        if [[ $completed -gt 0 ]]; then
            local avg=$((total_time / completed))
            echo -e "  Avg. per completed: $(format_time $avg)"
        fi
        echo ""
    fi

    # High priority items
    local high_priority=$(jq '.items | map(select(.status != "completed" and .status != "abandoned" and .priority <= 2)) | length' "$READLIST_FILE")
    if [[ $high_priority -gt 0 ]]; then
        echo -e "${YELLOW}High priority items pending: $high_priority${NC}"
    fi
}

remove_item() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh remove <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.items | map(select(.id == $id)) | length' "$READLIST_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local title=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .title' "$READLIST_FILE")

    jq --argjson id "$id" '.items = [.items[] | select(.id != $id)]' "$READLIST_FILE" > "$READLIST_FILE.tmp" && mv "$READLIST_FILE.tmp" "$READLIST_FILE"

    echo -e "${RED}Removed:${NC} $title"
}

open_item() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: readlist.sh open <id>"
        exit 1
    fi

    local item=$(jq -r --argjson id "$id" '.items[] | select(.id == $id)' "$READLIST_FILE")

    if [[ -z "$item" ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local url=$(echo "$item" | jq -r '.url // ""')
    local title=$(echo "$item" | jq -r '.title')

    if [[ -z "$url" ]]; then
        echo -e "${YELLOW}No URL for:${NC} $title"
        exit 1
    fi

    echo -e "${GREEN}Opening:${NC} $title"
    echo -e "${GRAY}$url${NC}"

    # Try to open in browser
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "$url" 2>/dev/null &
    else
        echo ""
        echo -e "${YELLOW}Could not auto-open. Copy the URL above.${NC}"
    fi
}

show_help() {
    echo "Readlist - Reading list and learning content tracker"
    echo ""
    echo "Usage:"
    echo "  readlist.sh add <title/url> [options]   Add item to reading list"
    echo "  readlist.sh list [status] [-t TYPE]     List items (filter by status/type)"
    echo "  readlist.sh view <id>                   View item details"
    echo "  readlist.sh open <id>                   Open URL in browser"
    echo "  readlist.sh start <id>                  Mark as in-progress"
    echo "  readlist.sh progress <id> <text>        Update progress"
    echo "  readlist.sh done <id> [time]            Mark as completed"
    echo "  readlist.sh abandon <id>                Mark as abandoned"
    echo "  readlist.sh note <id> \"text\"            Add a note/takeaway"
    echo "  readlist.sh priority <id> <1-5>         Set priority"
    echo "  readlist.sh search \"query\"              Search items"
    echo "  readlist.sh stats                       Show statistics"
    echo "  readlist.sh remove <id>                 Remove an item"
    echo "  readlist.sh help                        Show this help"
    echo ""
    echo "Add Options:"
    echo "  -t, --type TYPE       article|book|video|tutorial|podcast|course|paper"
    echo "  -p, --priority N      1=highest to 5=lowest (default: 3)"
    echo "  -e, --estimate TIME   Estimated time (e.g., 30m, 2h)"
    echo "  -a, --author NAME     Author or creator"
    echo "  --tags TAG1,TAG2      Comma-separated tags"
    echo ""
    echo "Examples:"
    echo "  readlist.sh add \"Clean Code\" -t book -a \"Robert Martin\" -e 10h"
    echo "  readlist.sh add https://blog.example.com/article -t article -p 2"
    echo "  readlist.sh list unread -t book"
    echo "  readlist.sh progress 1 \"Chapter 5/12\""
    echo "  readlist.sh done 2 45m"
}

case "$1" in
    add)
        shift
        add_item "$@"
        ;;
    list|ls)
        shift
        list_items "$@"
        ;;
    view|show)
        view_item "$2"
        ;;
    open|go)
        open_item "$2"
        ;;
    start|begin)
        start_item "$2"
        ;;
    progress|update)
        shift
        update_progress "$@"
        ;;
    done|complete|finish)
        complete_item "$2" "$3"
        ;;
    abandon|drop)
        abandon_item "$2"
        ;;
    note|notes)
        shift
        add_note "$@"
        ;;
    priority|prio)
        set_priority "$2" "$3"
        ;;
    search|find)
        shift
        search_items "$@"
        ;;
    stats|statistics)
        show_stats
        ;;
    remove|rm|delete)
        remove_item "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_items
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'readlist.sh help' for usage"
        exit 1
        ;;
esac
