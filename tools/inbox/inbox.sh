#!/bin/bash
#
# Inbox - Capture and process incoming items (GTD-style inbox)
#
# A quick-capture tool for collecting all incoming items that need processing.
# Helps ensure nothing falls through the cracks by providing a central collection
# point and processing workflow.
#
# Usage:
#   inbox.sh add "item"              - Quickly capture an item
#   inbox.sh list                    - Show all inbox items
#   inbox.sh process <id>            - Process an item (move/delete/defer)
#   inbox.sh done <id>               - Mark as processed and remove
#   inbox.sh defer <id> [date]       - Defer item until later
#   inbox.sh priority <id> <1-3>     - Set priority (1=high, 2=medium, 3=low)
#   inbox.sh tag <id> "tag"          - Add a tag to an item
#   inbox.sh search "query"          - Search items
#   inbox.sh stats                   - Show inbox statistics
#   inbox.sh clear-done              - Remove all processed items
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
INBOX_FILE="$DATA_DIR/inbox.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$DATA_DIR"

# Initialize inbox file if it doesn't exist
if [[ ! -f "$INBOX_FILE" ]]; then
    echo '{"items":[],"next_id":1,"processed_count":0}' > "$INBOX_FILE"
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

# Check for jq (except for help command)
if [[ "$1" != "help" ]] && [[ "$1" != "--help" ]] && [[ "$1" != "-h" ]]; then
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required. Install with: sudo apt install jq"
        exit 1
    fi
fi

# Priority symbols
priority_symbol() {
    case "$1" in
        1) echo -e "${RED}!!!${NC}" ;;
        2) echo -e "${YELLOW}!! ${NC}" ;;
        3) echo -e "${GRAY}!  ${NC}" ;;
        *) echo "   " ;;
    esac
}

add_item() {
    local content="$*"

    if [[ -z "$content" ]]; then
        echo "Usage: inbox.sh add \"item description\""
        exit 1
    fi

    local next_id=$(jq -r '.next_id' "$INBOX_FILE")

    jq --arg content "$content" --arg ts "$NOW" --arg date "$TODAY" --argjson id "$next_id" '
        .items += [{
            "id": $id,
            "content": $content,
            "created": $ts,
            "created_date": $date,
            "priority": null,
            "tags": [],
            "deferred_until": null,
            "processed": false,
            "processed_at": null,
            "source": "manual"
        }] |
        .next_id = ($id + 1)
    ' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    echo -e "${GREEN}+${NC} Captured #$next_id: $content"

    # Show current inbox count
    local count=$(jq '[.items[] | select(.processed == false and (.deferred_until == null or .deferred_until <= "'"$TODAY"'"))] | length' "$INBOX_FILE")
    echo -e "${GRAY}Inbox: $count item(s) to process${NC}"
}

list_items() {
    local show_all=${1:-false}
    local show_deferred=${2:-false}

    # Get counts
    local active=$(jq '[.items[] | select(.processed == false and (.deferred_until == null or .deferred_until <= "'"$TODAY"'"))] | length' "$INBOX_FILE")
    local deferred=$(jq '[.items[] | select(.processed == false and .deferred_until != null and .deferred_until > "'"$TODAY"'")] | length' "$INBOX_FILE")
    local processed=$(jq '[.items[] | select(.processed == true)] | length' "$INBOX_FILE")

    echo -e "${BLUE}=== Inbox ===${NC}"
    echo ""

    if [[ "$active" -eq 0 ]] && [[ "$show_all" != "true" ]]; then
        echo -e "${GREEN}✓ Inbox zero! Nothing to process.${NC}"
        if [[ "$deferred" -gt 0 ]]; then
            echo -e "${GRAY}  ($deferred item(s) deferred for later)${NC}"
        fi
        exit 0
    fi

    # Show active items (not processed, not deferred or deferred until today/past)
    if [[ "$active" -gt 0 ]]; then
        echo -e "${YELLOW}To Process ($active):${NC}"
        echo ""

        jq -r --arg today "$TODAY" '
            .items
            | map(select(.processed == false and (.deferred_until == null or .deferred_until <= $today)))
            | sort_by(.priority // 4, .created)
            | .[]
            | "\(.id)|\(.priority // "")|\(.content)|\(.tags | join(","))|\(.created)"
        ' "$INBOX_FILE" | while IFS='|' read -r id priority content tags created; do
            local pri_sym=$(priority_symbol "$priority")
            local tag_str=""
            if [[ -n "$tags" ]]; then
                tag_str=" ${CYAN}[$tags]${NC}"
            fi
            echo -e "  ${pri_sym}${GRAY}#${id}${NC} $content$tag_str"
        done
        echo ""
    fi

    # Show deferred items if requested
    if [[ "$show_deferred" == "true" ]] && [[ "$deferred" -gt 0 ]]; then
        echo -e "${MAGENTA}Deferred ($deferred):${NC}"
        echo ""

        jq -r --arg today "$TODAY" '
            .items
            | map(select(.processed == false and .deferred_until != null and .deferred_until > $today))
            | sort_by(.deferred_until)
            | .[]
            | "\(.id)|\(.content)|\(.deferred_until)"
        ' "$INBOX_FILE" | while IFS='|' read -r id content deferred_date; do
            echo -e "  ${GRAY}#${id}${NC} $content ${MAGENTA}(until $deferred_date)${NC}"
        done
        echo ""
    fi

    # Show summary
    echo -e "${GRAY}─────────────────────────────────────${NC}"
    echo -e "${GRAY}Active: $active | Deferred: $deferred | Processed: $processed${NC}"

    if [[ "$active" -gt 0 ]]; then
        echo ""
        echo -e "${GRAY}Tip: Use 'inbox.sh process <id>' to handle an item${NC}"
    fi
}

process_item() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: inbox.sh process <id>"
        exit 1
    fi

    # Check if item exists
    local item=$(jq -r --argjson id "$id" '.items[] | select(.id == $id)' "$INBOX_FILE")

    if [[ -z "$item" ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local content=$(echo "$item" | jq -r '.content')
    local processed=$(echo "$item" | jq -r '.processed')

    if [[ "$processed" == "true" ]]; then
        echo -e "${YELLOW}Item #$id is already processed${NC}"
        exit 0
    fi

    echo -e "${BLUE}=== Processing Item #$id ===${NC}"
    echo ""
    echo -e "${BOLD}$content${NC}"
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  [d] Done - Mark as processed and remove"
    echo "  [t] Task - Convert to task (copies to tasks tool)"
    echo "  [n] Note - Save as note (copies to quicknotes)"
    echo "  [f] Defer - Defer until later date"
    echo "  [p] Priority - Set priority level"
    echo "  [s] Skip - Leave in inbox for now"
    echo "  [x] Delete - Remove without processing"
    echo ""
    read -p "Choice: " -n 1 choice
    echo ""

    case "$choice" in
        d|D)
            mark_done "$id"
            ;;
        t|T)
            convert_to_task "$id" "$content"
            ;;
        n|N)
            convert_to_note "$id" "$content"
            ;;
        f|F)
            echo ""
            read -p "Defer until (YYYY-MM-DD or +N days): " defer_input
            defer_item "$id" "$defer_input"
            ;;
        p|P)
            echo ""
            read -p "Priority (1=high, 2=medium, 3=low): " -n 1 pri
            echo ""
            set_priority "$id" "$pri"
            ;;
        s|S)
            echo -e "${GRAY}Skipped. Item remains in inbox.${NC}"
            ;;
        x|X)
            delete_item "$id"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Item remains in inbox.${NC}"
            ;;
    esac
}

mark_done() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: inbox.sh done <id>"
        exit 1
    fi

    # Check if item exists
    local exists=$(jq --argjson id "$id" '[.items[] | select(.id == $id)] | length' "$INBOX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg ts "$NOW" '
        .items = [.items[] | if .id == $id then .processed = true | .processed_at = $ts else . end] |
        .processed_count += 1
    ' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    local content=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .content' "$INBOX_FILE")
    echo -e "${GREEN}✓${NC} Processed: $content"
}

defer_item() {
    local id=$1
    local date_input=$2

    if [[ -z "$id" ]]; then
        echo "Usage: inbox.sh defer <id> [date|+N]"
        exit 1
    fi

    # Parse date input
    local defer_date
    if [[ -z "$date_input" ]]; then
        # Default to tomorrow
        defer_date=$(date -d "tomorrow" +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d 2>/dev/null)
    elif [[ "$date_input" =~ ^\+([0-9]+)$ ]]; then
        # Relative days
        local days=${BASH_REMATCH[1]}
        defer_date=$(date -d "+$days days" +%Y-%m-%d 2>/dev/null || date -v+${days}d +%Y-%m-%d 2>/dev/null)
    else
        # Absolute date
        defer_date="$date_input"
    fi

    # Validate date
    if ! date -d "$defer_date" &>/dev/null 2>&1; then
        echo -e "${RED}Invalid date: $date_input${NC}"
        echo "Use YYYY-MM-DD or +N (e.g., +3 for 3 days from now)"
        exit 1
    fi

    # Check if item exists
    local exists=$(jq --argjson id "$id" '[.items[] | select(.id == $id)] | length' "$INBOX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg date "$defer_date" '
        .items = [.items[] | if .id == $id then .deferred_until = $date else . end]
    ' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    local content=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .content' "$INBOX_FILE")
    echo -e "${MAGENTA}⏰${NC} Deferred until $defer_date: $content"
}

set_priority() {
    local id=$1
    local priority=$2

    if [[ -z "$id" ]] || [[ -z "$priority" ]]; then
        echo "Usage: inbox.sh priority <id> <1-3>"
        exit 1
    fi

    if [[ ! "$priority" =~ ^[1-3]$ ]]; then
        echo -e "${RED}Priority must be 1, 2, or 3${NC}"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '[.items[] | select(.id == $id)] | length' "$INBOX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --argjson pri "$priority" '
        .items = [.items[] | if .id == $id then .priority = $pri else . end]
    ' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    local pri_label
    case "$priority" in
        1) pri_label="high" ;;
        2) pri_label="medium" ;;
        3) pri_label="low" ;;
    esac

    echo -e "$(priority_symbol $priority) Set priority to $pri_label for item #$id"
}

add_tag() {
    local id=$1
    local tag=$2

    if [[ -z "$id" ]] || [[ -z "$tag" ]]; then
        echo "Usage: inbox.sh tag <id> \"tag\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '[.items[] | select(.id == $id)] | length' "$INBOX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --arg tag "$tag" '
        .items = [.items[] | if .id == $id then .tags += [$tag] | .tags |= unique else . end]
    ' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    echo -e "${CYAN}Tagged item #$id with: $tag${NC}"
}

search_items() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: inbox.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$query" '
        .items
        | map(select(.content | ascii_downcase | contains($q | ascii_downcase)))
        | .[]
        | "\(.id)|\(.processed)|\(.content)"
    ' "$INBOX_FILE")

    if [[ -z "$results" ]]; then
        echo "No items found matching \"$query\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id processed content; do
        if [[ "$processed" == "true" ]]; then
            echo -e "  ${GRAY}#${id} [done]${NC} $content"
        else
            echo -e "  ${GRAY}#${id}${NC} $content"
        fi
    done
}

delete_item() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: inbox.sh delete <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '[.items[] | select(.id == $id)] | length' "$INBOX_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Item #$id not found${NC}"
        exit 1
    fi

    local content=$(jq -r --argjson id "$id" '.items[] | select(.id == $id) | .content' "$INBOX_FILE")

    jq --argjson id "$id" '.items = [.items[] | select(.id != $id)]' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    echo -e "${RED}✗${NC} Deleted: $content"
}

convert_to_task() {
    local id=$1
    local content=$2

    local tasks_script="$SCRIPT_DIR/../tasks/tasks.sh"

    if [[ -x "$tasks_script" ]]; then
        "$tasks_script" add "$content"
        mark_done "$id"
    else
        echo -e "${YELLOW}Tasks tool not found. Item remains in inbox.${NC}"
        echo "You can manually add this as a task."
    fi
}

convert_to_note() {
    local id=$1
    local content=$2

    local notes_script="$SCRIPT_DIR/../quicknotes/quicknotes.sh"

    if [[ -x "$notes_script" ]]; then
        "$notes_script" add "$content"
        mark_done "$id"
    else
        echo -e "${YELLOW}Quicknotes tool not found. Item remains in inbox.${NC}"
        echo "You can manually add this as a note."
    fi
}

show_stats() {
    echo -e "${BLUE}=== Inbox Statistics ===${NC}"
    echo ""

    local total=$(jq '.items | length' "$INBOX_FILE")
    local active=$(jq '[.items[] | select(.processed == false and (.deferred_until == null or .deferred_until <= "'"$TODAY"'"))] | length' "$INBOX_FILE")
    local deferred=$(jq '[.items[] | select(.processed == false and .deferred_until != null and .deferred_until > "'"$TODAY"'")] | length' "$INBOX_FILE")
    local processed=$(jq '[.items[] | select(.processed == true)] | length' "$INBOX_FILE")
    local total_processed=$(jq '.processed_count' "$INBOX_FILE")

    local high=$(jq '[.items[] | select(.processed == false and .priority == 1)] | length' "$INBOX_FILE")
    local medium=$(jq '[.items[] | select(.processed == false and .priority == 2)] | length' "$INBOX_FILE")
    local low=$(jq '[.items[] | select(.processed == false and .priority == 3)] | length' "$INBOX_FILE")

    echo -e "${YELLOW}Current Inbox:${NC}"
    echo -e "  Active items:     $active"
    echo -e "  Deferred items:   $deferred"
    echo -e "  Processed items:  $processed"
    echo ""

    echo -e "${YELLOW}By Priority:${NC}"
    echo -e "  ${RED}High (!!!):${NC}   $high"
    echo -e "  ${YELLOW}Medium (!!):${NC}  $medium"
    echo -e "  ${GRAY}Low (!):${NC}      $low"
    echo ""

    echo -e "${YELLOW}All Time:${NC}"
    echo -e "  Total processed:  $total_processed"
    echo ""

    # Calculate items by age
    echo -e "${YELLOW}Inbox Age:${NC}"

    local today_items=$(jq --arg date "$TODAY" '[.items[] | select(.processed == false and .created_date == $date)] | length' "$INBOX_FILE")
    local week_items=$(jq --arg date "$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" '[.items[] | select(.processed == false and .created_date >= $date)] | length' "$INBOX_FILE")
    local old_items=$(jq --arg date "$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" '[.items[] | select(.processed == false and .created_date < $date)] | length' "$INBOX_FILE")

    echo -e "  Added today:      $today_items"
    echo -e "  This week:        $week_items"
    echo -e "  Older than 7d:    ${RED}$old_items${NC}"

    if [[ "$old_items" -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Tip:${NC} You have $old_items old items. Consider processing them!"
    fi

    if [[ "$active" -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ Congratulations! You've achieved inbox zero!${NC}"
    fi
}

clear_done() {
    local count=$(jq '[.items[] | select(.processed == true)] | length' "$INBOX_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No processed items to clear."
        exit 0
    fi

    jq '.items = [.items[] | select(.processed == false)]' "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"

    echo -e "${GREEN}Cleared $count processed item(s)${NC}"
}

show_help() {
    echo "Inbox - Capture and process incoming items (GTD-style inbox)"
    echo ""
    echo "The inbox is a collection point for all incoming items that need"
    echo "processing. Capture quickly, process later."
    echo ""
    echo "Usage:"
    echo "  inbox.sh add \"item\"         Quickly capture an item"
    echo "  inbox.sh list               Show all active inbox items"
    echo "  inbox.sh list --all         Show all items including deferred"
    echo "  inbox.sh process <id>       Interactively process an item"
    echo "  inbox.sh done <id>          Mark item as processed"
    echo "  inbox.sh defer <id> [date]  Defer until later (+N or YYYY-MM-DD)"
    echo "  inbox.sh priority <id> <n>  Set priority (1=high, 2=med, 3=low)"
    echo "  inbox.sh tag <id> \"tag\"     Add a tag to an item"
    echo "  inbox.sh search \"query\"     Search items by content"
    echo "  inbox.sh delete <id>        Remove an item"
    echo "  inbox.sh stats              Show inbox statistics"
    echo "  inbox.sh clear-done         Remove all processed items"
    echo "  inbox.sh help               Show this help"
    echo ""
    echo "Quick capture (pipe input):"
    echo "  echo \"idea\" | inbox.sh add"
    echo ""
    echo "Examples:"
    echo "  inbox.sh add \"Review budget proposal\""
    echo "  inbox.sh add \"Call mom about birthday\""
    echo "  inbox.sh priority 5 1        # Set high priority"
    echo "  inbox.sh defer 3 +7          # Defer 7 days"
    echo "  inbox.sh defer 3 2026-02-01  # Defer to specific date"
    echo "  inbox.sh process 5           # Interactively handle item"
}

# Handle piped input
if [[ ! -t 0 ]] && [[ "$1" == "add" ]]; then
    item=$(cat)
    add_item "$item"
    exit 0
fi

case "$1" in
    add|a|+)
        shift
        add_item "$@"
        ;;
    list|ls|l)
        if [[ "$2" == "--all" ]] || [[ "$2" == "-a" ]]; then
            list_items "true" "true"
        elif [[ "$2" == "--deferred" ]] || [[ "$2" == "-d" ]]; then
            list_items "false" "true"
        else
            list_items
        fi
        ;;
    process|p)
        process_item "$2"
        ;;
    done|d)
        mark_done "$2"
        ;;
    defer|f)
        defer_item "$2" "$3"
        ;;
    priority|pri)
        set_priority "$2" "$3"
        ;;
    tag|t)
        add_tag "$2" "$3"
        ;;
    search|s)
        shift
        search_items "$@"
        ;;
    delete|del|rm)
        delete_item "$2"
        ;;
    stats|st)
        show_stats
        ;;
    clear-done|clean)
        clear_done
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_items
        ;;
    *)
        # Treat as quick add if it looks like content
        if [[ "$1" =~ ^[^-] ]]; then
            add_item "$@"
        else
            echo "Unknown command: $1"
            echo "Run 'inbox.sh help' for usage"
            exit 1
        fi
        ;;
esac
