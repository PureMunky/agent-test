#!/bin/bash
#
# Retrospective - Project and periodic retrospective tool
#
# A structured tool for conducting retrospectives to reflect on work,
# identify improvements, and track action items over time.
#
# Usage:
#   retrospective.sh new [name]           - Start a new retrospective
#   retrospective.sh list                 - List all retrospectives
#   retrospective.sh view <id>            - View a specific retrospective
#   retrospective.sh actions              - Show pending action items
#   retrospective.sh complete <action_id> - Mark action item complete
#   retrospective.sh stats                - Show retrospective statistics
#   retrospective.sh export <id> [format] - Export retrospective (md/txt)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
RETROS_FILE="$DATA_DIR/retrospectives.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize retros file if it doesn't exist
if [[ ! -f "$RETROS_FILE" ]]; then
    echo '{"retrospectives":[],"next_id":1,"action_next_id":1}' > "$RETROS_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Helper: Read multi-line input
read_multiline() {
    local prompt="$1"
    local result=""

    echo -e "${CYAN}$prompt${NC}"
    echo -e "${GRAY}(Enter each item on a new line. Press Ctrl+D or enter an empty line when done)${NC}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        if [[ -n "$result" ]]; then
            result="$result\n$line"
        else
            result="$line"
        fi
    done

    echo "$result"
}

# Helper: Convert newline-separated text to JSON array
text_to_json_array() {
    local text="$1"
    if [[ -z "$text" ]]; then
        echo "[]"
    else
        echo -e "$text" | jq -R -s 'split("\n") | map(select(length > 0))'
    fi
}

new_retro() {
    local name="${1:-}"

    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}            ${WHITE}New Retrospective${NC}                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Get name if not provided
    if [[ -z "$name" ]]; then
        echo -e "${CYAN}Retrospective name/title:${NC}"
        read -r name
        if [[ -z "$name" ]]; then
            name="Retrospective $TODAY"
        fi
    fi

    echo ""
    echo -e "${GREEN}Starting retrospective:${NC} $name"
    echo -e "${GRAY}Date: $TODAY${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # What went well
    echo -e "${GREEN}🌟 WHAT WENT WELL${NC}"
    local went_well=$(read_multiline "What worked? What are you proud of?")
    echo ""

    # What didn't go well
    echo -e "${RED}⚡ WHAT DIDN'T GO WELL${NC}"
    local didnt_go_well=$(read_multiline "What was challenging? What could have been better?")
    echo ""

    # What did you learn
    echo -e "${CYAN}📚 WHAT DID YOU LEARN${NC}"
    local learned=$(read_multiline "New insights, skills, or knowledge gained?")
    echo ""

    # Action items
    echo -e "${MAGENTA}🎯 ACTION ITEMS${NC}"
    local actions=$(read_multiline "What specific improvements will you make?")
    echo ""

    # Optional: Rating
    echo -e "${CYAN}Rate this period (1-5, or press Enter to skip):${NC}"
    read -r rating
    if [[ -n "$rating" ]] && ! [[ "$rating" =~ ^[1-5]$ ]]; then
        rating=""
    fi

    # Optional: Notes
    echo -e "${CYAN}Any additional notes? (press Enter to skip):${NC}"
    read -r notes

    # Get next IDs
    local retro_id=$(jq -r '.next_id' "$RETROS_FILE")
    local action_id=$(jq -r '.action_next_id' "$RETROS_FILE")

    # Convert to JSON arrays
    local went_well_json=$(text_to_json_array "$went_well")
    local didnt_go_well_json=$(text_to_json_array "$didnt_go_well")
    local learned_json=$(text_to_json_array "$learned")
    local actions_json=$(text_to_json_array "$actions")

    # Build action items with IDs
    local action_items="[]"
    local actions_count=$(echo "$actions_json" | jq 'length')
    if [[ $actions_count -gt 0 ]]; then
        action_items=$(echo "$actions_json" | jq --argjson start_id "$action_id" '
            to_entries | map({
                id: ($start_id + .key),
                text: .value,
                completed: false,
                completed_at: null
            })
        ')
        action_id=$((action_id + actions_count))
    fi

    # Create the retrospective object
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --argjson id "$retro_id" \
       --arg name "$name" \
       --arg date "$TODAY" \
       --arg timestamp "$timestamp" \
       --argjson went_well "$went_well_json" \
       --argjson didnt_go_well "$didnt_go_well_json" \
       --argjson learned "$learned_json" \
       --argjson actions "$action_items" \
       --arg rating "${rating:-null}" \
       --arg notes "$notes" \
       --argjson next_action_id "$action_id" \
    '
        .retrospectives += [{
            id: $id,
            name: $name,
            date: $date,
            created_at: $timestamp,
            went_well: $went_well,
            didnt_go_well: $didnt_go_well,
            learned: $learned,
            action_items: $actions,
            rating: (if $rating == "null" then null else ($rating | tonumber) end),
            notes: $notes
        }] |
        .next_id = ($id + 1) |
        .action_next_id = $next_action_id
    ' "$RETROS_FILE" > "$RETROS_FILE.tmp" && mv "$RETROS_FILE.tmp" "$RETROS_FILE"

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✓ Retrospective #$retro_id saved!${NC}"
    echo ""

    # Summary
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  Went well:     $(echo "$went_well_json" | jq 'length') items"
    echo -e "  Challenges:    $(echo "$didnt_go_well_json" | jq 'length') items"
    echo -e "  Learnings:     $(echo "$learned_json" | jq 'length') items"
    echo -e "  Action items:  $actions_count items"

    if [[ $actions_count -gt 0 ]]; then
        echo ""
        echo -e "${GRAY}View action items with: retrospective.sh actions${NC}"
    fi
}

list_retros() {
    echo -e "${BLUE}=== Retrospectives ===${NC}"
    echo ""

    local count=$(jq '.retrospectives | length' "$RETROS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No retrospectives yet."
        echo "Start one with: retrospective.sh new"
        exit 0
    fi

    jq -r '.retrospectives | reverse | .[] |
        "[\(.id)] \(.date) - \(.name)" +
        (if .rating then " ★\(.rating)" else "" end) +
        " (\(.action_items | map(select(.completed == false)) | length) pending actions)"
    ' "$RETROS_FILE" | while read -r line; do
        echo -e "  ${NC}$line"
    done

    echo ""
    echo -e "${GRAY}View details: retrospective.sh view <id>${NC}"
}

view_retro() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: retrospective.sh view <id>"
        exit 1
    fi

    # Check if retrospective exists
    local exists=$(jq --argjson id "$id" '.retrospectives | map(select(.id == $id)) | length' "$RETROS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Retrospective #$id not found.${NC}"
        exit 1
    fi

    local retro=$(jq --argjson id "$id" '.retrospectives[] | select(.id == $id)' "$RETROS_FILE")

    local name=$(echo "$retro" | jq -r '.name')
    local date=$(echo "$retro" | jq -r '.date')
    local rating=$(echo "$retro" | jq -r '.rating // "N/A"')
    local notes=$(echo "$retro" | jq -r '.notes // ""')

    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${WHITE}#$id: $name${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Date: $date | Rating: $rating/5${NC}"
    echo ""

    # What went well
    echo -e "${GREEN}🌟 WHAT WENT WELL${NC}"
    echo "$retro" | jq -r '.went_well[]' 2>/dev/null | while read -r item; do
        echo -e "  ${GREEN}•${NC} $item"
    done
    echo ""

    # What didn't go well
    echo -e "${RED}⚡ WHAT DIDN'T GO WELL${NC}"
    echo "$retro" | jq -r '.didnt_go_well[]' 2>/dev/null | while read -r item; do
        echo -e "  ${RED}•${NC} $item"
    done
    echo ""

    # Learned
    echo -e "${CYAN}📚 WHAT DID YOU LEARN${NC}"
    echo "$retro" | jq -r '.learned[]' 2>/dev/null | while read -r item; do
        echo -e "  ${CYAN}•${NC} $item"
    done
    echo ""

    # Action items
    echo -e "${MAGENTA}🎯 ACTION ITEMS${NC}"
    echo "$retro" | jq -r '.action_items[] |
        if .completed then
            "[✓] #\(.id): \(.text) (done: \(.completed_at))"
        else
            "[ ] #\(.id): \(.text)"
        end
    ' 2>/dev/null | while read -r item; do
        if [[ "$item" == "[✓]"* ]]; then
            echo -e "  ${GRAY}$item${NC}"
        else
            echo -e "  ${YELLOW}$item${NC}"
        fi
    done

    if [[ -n "$notes" ]]; then
        echo ""
        echo -e "${GRAY}Notes: $notes${NC}"
    fi
}

show_actions() {
    echo -e "${BLUE}=== Pending Action Items ===${NC}"
    echo ""

    local pending=$(jq '[.retrospectives[].action_items[] | select(.completed == false)]' "$RETROS_FILE")
    local count=$(echo "$pending" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}No pending action items!${NC}"
        exit 0
    fi

    # Group by retrospective
    jq -r '.retrospectives[] |
        select(.action_items | map(select(.completed == false)) | length > 0) |
        "From: \(.name) (\(.date))",
        (.action_items[] | select(.completed == false) | "  [ ] #\(.id): \(.text)"),
        ""
    ' "$RETROS_FILE" | while read -r line; do
        if [[ "$line" == "From:"* ]]; then
            echo -e "${CYAN}$line${NC}"
        elif [[ -n "$line" ]]; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo ""
        fi
    done

    echo -e "${GRAY}Complete an action: retrospective.sh complete <id>${NC}"
}

complete_action() {
    local action_id="$1"

    if [[ -z "$action_id" ]]; then
        echo "Usage: retrospective.sh complete <action_id>"
        exit 1
    fi

    # Find the action item
    local found=$(jq --argjson id "$action_id" '
        [.retrospectives[].action_items[] | select(.id == $id)] | length
    ' "$RETROS_FILE")

    if [[ "$found" -eq 0 ]]; then
        echo -e "${RED}Action item #$action_id not found.${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    jq --argjson id "$action_id" --arg ts "$timestamp" '
        .retrospectives = [
            .retrospectives[] |
            .action_items = [
                .action_items[] |
                if .id == $id then
                    .completed = true | .completed_at = $ts
                else
                    .
                end
            ]
        ]
    ' "$RETROS_FILE" > "$RETROS_FILE.tmp" && mv "$RETROS_FILE.tmp" "$RETROS_FILE"

    local text=$(jq -r --argjson id "$action_id" '
        .retrospectives[].action_items[] | select(.id == $id) | .text
    ' "$RETROS_FILE")

    echo -e "${GREEN}✓ Completed:${NC} $text"
}

show_stats() {
    echo -e "${BLUE}=== Retrospective Statistics ===${NC}"
    echo ""

    local total=$(jq '.retrospectives | length' "$RETROS_FILE")

    if [[ "$total" -eq 0 ]]; then
        echo "No retrospectives yet."
        exit 0
    fi

    echo -e "${CYAN}Total retrospectives:${NC} $total"

    # Average rating
    local avg_rating=$(jq '[.retrospectives[].rating | select(. != null)] | if length > 0 then add/length else 0 end' "$RETROS_FILE")
    local rated_count=$(jq '[.retrospectives[].rating | select(. != null)] | length' "$RETROS_FILE")
    if [[ "$rated_count" -gt 0 ]]; then
        printf "${CYAN}Average rating:${NC} %.1f/5 (%d rated)\n" "$avg_rating" "$rated_count"
    fi

    # Action items stats
    local total_actions=$(jq '[.retrospectives[].action_items[]] | length' "$RETROS_FILE")
    local completed_actions=$(jq '[.retrospectives[].action_items[] | select(.completed == true)] | length' "$RETROS_FILE")
    local pending_actions=$((total_actions - completed_actions))

    echo ""
    echo -e "${CYAN}Action Items:${NC}"
    echo -e "  Total:     $total_actions"
    echo -e "  Completed: ${GREEN}$completed_actions${NC}"
    echo -e "  Pending:   ${YELLOW}$pending_actions${NC}"

    if [[ $total_actions -gt 0 ]]; then
        local completion_rate=$((completed_actions * 100 / total_actions))
        echo -e "  Rate:      $completion_rate%"
    fi

    # Common themes (most frequent words in challenges)
    echo ""
    echo -e "${CYAN}Recent retrospectives:${NC}"
    jq -r '.retrospectives | reverse | .[0:5] | .[] |
        "  \(.date): \(.name)" + (if .rating then " (★\(.rating))" else "" end)
    ' "$RETROS_FILE"
}

export_retro() {
    local id="$1"
    local format="${2:-md}"

    if [[ -z "$id" ]]; then
        echo "Usage: retrospective.sh export <id> [md|txt]"
        exit 1
    fi

    # Check if retrospective exists
    local exists=$(jq --argjson id "$id" '.retrospectives | map(select(.id == $id)) | length' "$RETROS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Retrospective #$id not found.${NC}"
        exit 1
    fi

    local retro=$(jq --argjson id "$id" '.retrospectives[] | select(.id == $id)' "$RETROS_FILE")
    local name=$(echo "$retro" | jq -r '.name')
    local date=$(echo "$retro" | jq -r '.date')
    local rating=$(echo "$retro" | jq -r '.rating // "N/A"')
    local notes=$(echo "$retro" | jq -r '.notes // ""')

    local filename="retrospective-${id}-${date}"

    if [[ "$format" == "md" ]]; then
        filename="$filename.md"
        {
            echo "# $name"
            echo ""
            echo "**Date:** $date"
            echo "**Rating:** $rating/5"
            echo ""
            echo "## 🌟 What Went Well"
            echo ""
            echo "$retro" | jq -r '.went_well[]' | sed 's/^/- /'
            echo ""
            echo "## ⚡ What Didn't Go Well"
            echo ""
            echo "$retro" | jq -r '.didnt_go_well[]' | sed 's/^/- /'
            echo ""
            echo "## 📚 What Did You Learn"
            echo ""
            echo "$retro" | jq -r '.learned[]' | sed 's/^/- /'
            echo ""
            echo "## 🎯 Action Items"
            echo ""
            echo "$retro" | jq -r '.action_items[] | "- [" + (if .completed then "x" else " " end) + "] " + .text'
            if [[ -n "$notes" ]]; then
                echo ""
                echo "## Notes"
                echo ""
                echo "$notes"
            fi
        } > "$filename"
    else
        filename="$filename.txt"
        {
            echo "RETROSPECTIVE: $name"
            echo "Date: $date | Rating: $rating/5"
            echo "========================================"
            echo ""
            echo "WHAT WENT WELL:"
            echo "$retro" | jq -r '.went_well[]' | sed 's/^/  * /'
            echo ""
            echo "WHAT DIDN'T GO WELL:"
            echo "$retro" | jq -r '.didnt_go_well[]' | sed 's/^/  * /'
            echo ""
            echo "WHAT DID YOU LEARN:"
            echo "$retro" | jq -r '.learned[]' | sed 's/^/  * /'
            echo ""
            echo "ACTION ITEMS:"
            echo "$retro" | jq -r '.action_items[] | "  [" + (if .completed then "X" else " " end) + "] " + .text'
            if [[ -n "$notes" ]]; then
                echo ""
                echo "NOTES:"
                echo "  $notes"
            fi
        } > "$filename"
    fi

    echo -e "${GREEN}Exported to:${NC} $filename"
}

show_help() {
    echo "Retrospective - Project and periodic retrospective tool"
    echo ""
    echo "A structured tool for conducting retrospectives to reflect on work,"
    echo "identify improvements, and track action items over time."
    echo ""
    echo "Usage:"
    echo "  retrospective.sh new [name]           Start a new retrospective"
    echo "  retrospective.sh list                 List all retrospectives"
    echo "  retrospective.sh view <id>            View a specific retrospective"
    echo "  retrospective.sh actions              Show pending action items"
    echo "  retrospective.sh complete <action_id> Mark action item complete"
    echo "  retrospective.sh stats                Show statistics"
    echo "  retrospective.sh export <id> [format] Export to md or txt"
    echo "  retrospective.sh help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  retrospective.sh new \"Sprint 42 Retro\""
    echo "  retrospective.sh new                  # Interactive mode"
    echo "  retrospective.sh view 1"
    echo "  retrospective.sh export 1 md"
    echo ""
    echo "The retrospective format includes:"
    echo "  - What went well (celebrate successes)"
    echo "  - What didn't go well (identify challenges)"
    echo "  - What did you learn (capture insights)"
    echo "  - Action items (concrete improvements)"
}

case "$1" in
    new|start|create)
        shift
        new_retro "$*"
        ;;
    list|ls)
        list_retros
        ;;
    view|show)
        view_retro "$2"
        ;;
    actions|action|pending)
        show_actions
        ;;
    complete|done|finish)
        complete_action "$2"
        ;;
    stats|statistics|summary)
        show_stats
        ;;
    export)
        export_retro "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_retros
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'retrospective.sh help' for usage"
        exit 1
        ;;
esac
