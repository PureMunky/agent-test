#!/bin/bash
#
# Decisions - Decision log for tracking important choices
#
# Usage:
#   decisions.sh add "Title"                - Start recording a new decision
#   decisions.sh list [n]                   - Show recent decisions (default: 10)
#   decisions.sh show <id>                  - Show full decision details
#   decisions.sh search "keyword"           - Search decisions
#   decisions.sh update <id>                - Update decision outcome/status
#   decisions.sh tags                       - List all tags
#   decisions.sh by-tag "tag"               - Show decisions by tag
#   decisions.sh pending                    - Show decisions awaiting outcomes
#   decisions.sh stats                      - Show decision statistics
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
DECISIONS_FILE="$DATA_DIR/decisions.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize decisions file if it doesn't exist
if [[ ! -f "$DECISIONS_FILE" ]]; then
    echo '{"decisions":[],"next_id":1}' > "$DECISIONS_FILE"
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

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local required="${3:-false}"
    local multiline="${4:-false}"

    if [[ "$multiline" == "true" ]]; then
        echo -e "${CYAN}$prompt${NC} (Enter empty line to finish):"
        local lines=""
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            if [[ -n "$lines" ]]; then
                lines="$lines\n$line"
            else
                lines="$line"
            fi
        done
        eval "$var_name=\"\$lines\""
    else
        echo -ne "${CYAN}$prompt:${NC} "
        read -r input
        eval "$var_name=\"\$input\""
    fi

    if [[ "$required" == "true" ]] && [[ -z "${!var_name}" ]]; then
        echo -e "${RED}This field is required.${NC}"
        prompt_input "$prompt" "$var_name" "$required" "$multiline"
    fi
}

add_decision() {
    local title="$*"

    if [[ -z "$title" ]]; then
        echo -e "${RED}Usage: decisions.sh add \"Decision title\"${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Recording Decision ===${NC}"
    echo -e "${BOLD}Title:${NC} $title"
    echo ""

    # Gather decision details
    prompt_input "Context (what led to this decision)" context false true
    prompt_input "Decision made" decision true true
    prompt_input "Alternatives considered" alternatives false true
    prompt_input "Rationale (why this choice)" rationale false true
    prompt_input "Tags (comma-separated, e.g., tech,architecture)" tags false false
    prompt_input "Expected outcome" expected_outcome false true
    prompt_input "Review date (YYYY-MM-DD, leave empty for none)" review_date false false

    # Validate review date if provided
    if [[ -n "$review_date" ]]; then
        if ! date -d "$review_date" &>/dev/null 2>&1; then
            echo -e "${YELLOW}Invalid date format, skipping review date.${NC}"
            review_date=""
        fi
    fi

    local next_id=$(jq -r '.next_id' "$DECISIONS_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    # Process tags into array
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
    fi

    # Escape newlines for JSON
    local context_escaped=$(echo -e "$context" | jq -Rs .)
    local decision_escaped=$(echo -e "$decision" | jq -Rs .)
    local alternatives_escaped=$(echo -e "$alternatives" | jq -Rs .)
    local rationale_escaped=$(echo -e "$rationale" | jq -Rs .)
    local expected_outcome_escaped=$(echo -e "$expected_outcome" | jq -Rs .)

    jq --arg title "$title" \
       --arg timestamp "$timestamp" \
       --argjson id "$next_id" \
       --argjson context "$context_escaped" \
       --argjson decision "$decision_escaped" \
       --argjson alternatives "$alternatives_escaped" \
       --argjson rationale "$rationale_escaped" \
       --argjson tags "$tags_json" \
       --argjson expected_outcome "$expected_outcome_escaped" \
       --arg review_date "$review_date" \
       '
        .decisions += [{
            "id": $id,
            "title": $title,
            "context": $context,
            "decision": $decision,
            "alternatives": $alternatives,
            "rationale": $rationale,
            "tags": $tags,
            "expected_outcome": $expected_outcome,
            "actual_outcome": "",
            "status": "active",
            "review_date": $review_date,
            "created": $timestamp,
            "updated": $timestamp
        }] |
        .next_id = ($id + 1)
    ' "$DECISIONS_FILE" > "$DECISIONS_FILE.tmp" && mv "$DECISIONS_FILE.tmp" "$DECISIONS_FILE"

    echo ""
    echo -e "${GREEN}Decision #$next_id recorded:${NC} $title"
}

list_decisions() {
    local count=${1:-10}

    echo -e "${BLUE}=== Recent Decisions ===${NC}"
    echo ""

    local total=$(jq '.decisions | length' "$DECISIONS_FILE")

    if [[ "$total" -eq 0 ]]; then
        echo "No decisions recorded yet."
        echo "Add one with: decisions.sh add \"Your decision title\""
        exit 0
    fi

    jq -r --argjson count "$count" '
        .decisions | reverse | .[:$count] | .[] |
        "\(.id)|\(.status)|\(.created)|\(.title)|\(.tags | join(","))"
    ' "$DECISIONS_FILE" | while IFS='|' read -r id status created title tags; do
        local status_color="$GREEN"
        local status_icon="+"
        case "$status" in
            "reversed") status_color="$RED"; status_icon="x" ;;
            "superseded") status_color="$YELLOW"; status_icon="~" ;;
            "pending") status_color="$CYAN"; status_icon="?" ;;
        esac

        echo -e "  ${status_color}[$status_icon]${NC} ${BOLD}#$id${NC} $title"
        echo -e "      ${GRAY}$created${NC}"
        if [[ -n "$tags" ]]; then
            echo -e "      ${MAGENTA}$tags${NC}"
        fi
        echo ""
    done

    echo -e "${GRAY}Showing $count of $total decisions${NC}"
}

show_decision() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: decisions.sh show <id>"
        exit 1
    fi

    local decision=$(jq --argjson id "$id" '.decisions[] | select(.id == $id)' "$DECISIONS_FILE")

    if [[ -z "$decision" ]] || [[ "$decision" == "null" ]]; then
        echo -e "${RED}Decision #$id not found.${NC}"
        exit 1
    fi

    local title=$(echo "$decision" | jq -r '.title')
    local status=$(echo "$decision" | jq -r '.status')
    local created=$(echo "$decision" | jq -r '.created')
    local updated=$(echo "$decision" | jq -r '.updated')
    local context=$(echo "$decision" | jq -r '.context')
    local dec=$(echo "$decision" | jq -r '.decision')
    local alternatives=$(echo "$decision" | jq -r '.alternatives')
    local rationale=$(echo "$decision" | jq -r '.rationale')
    local tags=$(echo "$decision" | jq -r '.tags | join(", ")')
    local expected=$(echo "$decision" | jq -r '.expected_outcome')
    local actual=$(echo "$decision" | jq -r '.actual_outcome')
    local review_date=$(echo "$decision" | jq -r '.review_date')

    local status_color="$GREEN"
    case "$status" in
        "reversed") status_color="$RED" ;;
        "superseded") status_color="$YELLOW" ;;
        "pending") status_color="$CYAN" ;;
    esac

    echo -e "${BLUE}=== Decision #$id ===${NC}"
    echo ""
    echo -e "${BOLD}$title${NC}"
    echo -e "${GRAY}Created: $created | Updated: $updated${NC}"
    echo -e "Status: ${status_color}$status${NC}"
    if [[ -n "$tags" ]]; then
        echo -e "Tags: ${MAGENTA}$tags${NC}"
    fi
    if [[ -n "$review_date" ]] && [[ "$review_date" != "null" ]] && [[ "$review_date" != "" ]]; then
        echo -e "Review date: ${YELLOW}$review_date${NC}"
    fi
    echo ""

    if [[ -n "$context" ]] && [[ "$context" != "null" ]] && [[ "$context" != "" ]]; then
        echo -e "${CYAN}Context:${NC}"
        echo -e "$context" | sed 's/^/  /'
        echo ""
    fi

    echo -e "${CYAN}Decision:${NC}"
    echo -e "$dec" | sed 's/^/  /'
    echo ""

    if [[ -n "$alternatives" ]] && [[ "$alternatives" != "null" ]] && [[ "$alternatives" != "" ]]; then
        echo -e "${CYAN}Alternatives Considered:${NC}"
        echo -e "$alternatives" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$rationale" ]] && [[ "$rationale" != "null" ]] && [[ "$rationale" != "" ]]; then
        echo -e "${CYAN}Rationale:${NC}"
        echo -e "$rationale" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$expected" ]] && [[ "$expected" != "null" ]] && [[ "$expected" != "" ]]; then
        echo -e "${CYAN}Expected Outcome:${NC}"
        echo -e "$expected" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$actual" ]] && [[ "$actual" != "null" ]] && [[ "$actual" != "" ]]; then
        echo -e "${CYAN}Actual Outcome:${NC}"
        echo -e "$actual" | sed 's/^/  /'
        echo ""
    fi
}

update_decision() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: decisions.sh update <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.decisions | map(select(.id == $id)) | length' "$DECISIONS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Decision #$id not found.${NC}"
        exit 1
    fi

    show_decision "$id"
    echo ""
    echo -e "${BLUE}=== Update Decision ===${NC}"
    echo ""

    echo -e "What would you like to update?"
    echo "  1) Record actual outcome"
    echo "  2) Change status (active/reversed/superseded/pending)"
    echo "  3) Add to rationale"
    echo "  4) Set review date"
    echo ""
    echo -ne "${CYAN}Choice (1-4):${NC} "
    read -r choice

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    case "$choice" in
        1)
            prompt_input "Actual outcome" actual_outcome false true
            local actual_escaped=$(echo -e "$actual_outcome" | jq -Rs .)
            jq --argjson id "$id" --argjson actual "$actual_escaped" --arg ts "$timestamp" '
                .decisions = [.decisions[] | if .id == $id then .actual_outcome = $actual | .updated = $ts else . end]
            ' "$DECISIONS_FILE" > "$DECISIONS_FILE.tmp" && mv "$DECISIONS_FILE.tmp" "$DECISIONS_FILE"
            echo -e "${GREEN}Outcome recorded.${NC}"
            ;;
        2)
            echo -ne "${CYAN}New status (active/reversed/superseded/pending):${NC} "
            read -r new_status
            if [[ "$new_status" =~ ^(active|reversed|superseded|pending)$ ]]; then
                jq --argjson id "$id" --arg status "$new_status" --arg ts "$timestamp" '
                    .decisions = [.decisions[] | if .id == $id then .status = $status | .updated = $ts else . end]
                ' "$DECISIONS_FILE" > "$DECISIONS_FILE.tmp" && mv "$DECISIONS_FILE.tmp" "$DECISIONS_FILE"
                echo -e "${GREEN}Status updated to: $new_status${NC}"
            else
                echo -e "${RED}Invalid status. Use: active, reversed, superseded, or pending${NC}"
            fi
            ;;
        3)
            prompt_input "Additional rationale" add_rationale false true
            local add_escaped=$(echo -e "$add_rationale" | jq -Rs .)
            jq --argjson id "$id" --argjson add "$add_escaped" --arg ts "$timestamp" '
                .decisions = [.decisions[] | if .id == $id then .rationale = (.rationale + "\n\n[" + $ts + "]\n" + $add) | .updated = $ts else . end]
            ' "$DECISIONS_FILE" > "$DECISIONS_FILE.tmp" && mv "$DECISIONS_FILE.tmp" "$DECISIONS_FILE"
            echo -e "${GREEN}Rationale updated.${NC}"
            ;;
        4)
            echo -ne "${CYAN}Review date (YYYY-MM-DD):${NC} "
            read -r review_date
            if date -d "$review_date" &>/dev/null 2>&1; then
                jq --argjson id "$id" --arg rd "$review_date" --arg ts "$timestamp" '
                    .decisions = [.decisions[] | if .id == $id then .review_date = $rd | .updated = $ts else . end]
                ' "$DECISIONS_FILE" > "$DECISIONS_FILE.tmp" && mv "$DECISIONS_FILE.tmp" "$DECISIONS_FILE"
                echo -e "${GREEN}Review date set to: $review_date${NC}"
            else
                echo -e "${RED}Invalid date format.${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Cancelled.${NC}"
            ;;
    esac
}

search_decisions() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: decisions.sh search \"keyword\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$query" '
        .decisions[] | select(
            (.title | ascii_downcase | contains($q | ascii_downcase)) or
            (.decision | ascii_downcase | contains($q | ascii_downcase)) or
            (.context | ascii_downcase | contains($q | ascii_downcase)) or
            (.rationale | ascii_downcase | contains($q | ascii_downcase))
        ) |
        "\(.id)|\(.status)|\(.created)|\(.title)"
    ' "$DECISIONS_FILE")

    if [[ -z "$results" ]]; then
        echo "No decisions found matching \"$query\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id status created title; do
        local status_color="$GREEN"
        case "$status" in
            "reversed") status_color="$RED" ;;
            "superseded") status_color="$YELLOW" ;;
            "pending") status_color="$CYAN" ;;
        esac

        echo -e "  ${status_color}[$status]${NC} ${BOLD}#$id${NC} $title"
        echo -e "      ${GRAY}$created${NC}"
    done
}

list_tags() {
    echo -e "${BLUE}=== Decision Tags ===${NC}"
    echo ""

    local tags=$(jq -r '.decisions[].tags[]' "$DECISIONS_FILE" 2>/dev/null | sort | uniq -c | sort -rn)

    if [[ -z "$tags" ]]; then
        echo "No tags used yet."
        exit 0
    fi

    echo "$tags" | while read -r count tag; do
        echo -e "  ${MAGENTA}$tag${NC} ($count)"
    done
}

by_tag() {
    local tag="$*"

    if [[ -z "$tag" ]]; then
        echo "Usage: decisions.sh by-tag \"tag\""
        exit 1
    fi

    echo -e "${BLUE}=== Decisions tagged: $tag ===${NC}"
    echo ""

    local results=$(jq -r --arg tag "$tag" '
        .decisions[] | select(.tags | index($tag)) |
        "\(.id)|\(.status)|\(.created)|\(.title)"
    ' "$DECISIONS_FILE")

    if [[ -z "$results" ]]; then
        echo "No decisions found with tag \"$tag\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id status created title; do
        local status_color="$GREEN"
        case "$status" in
            "reversed") status_color="$RED" ;;
            "superseded") status_color="$YELLOW" ;;
            "pending") status_color="$CYAN" ;;
        esac

        echo -e "  ${status_color}[$status]${NC} ${BOLD}#$id${NC} $title"
        echo -e "      ${GRAY}$created${NC}"
    done
}

show_pending() {
    echo -e "${BLUE}=== Decisions Pending Review ===${NC}"
    echo ""

    # Show decisions with status=pending or with review_date in the past
    local results=$(jq -r --arg today "$TODAY" '
        .decisions[] | select(
            .status == "pending" or
            (.review_date != "" and .review_date != null and .review_date <= $today)
        ) |
        "\(.id)|\(.status)|\(.review_date)|\(.title)"
    ' "$DECISIONS_FILE")

    if [[ -z "$results" ]]; then
        echo "No decisions pending review."
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id status review_date title; do
        local note=""
        if [[ "$status" == "pending" ]]; then
            note="${CYAN}[pending]${NC}"
        elif [[ -n "$review_date" ]] && [[ "$review_date" != "null" ]]; then
            note="${YELLOW}[review: $review_date]${NC}"
        fi

        echo -e "  ${BOLD}#$id${NC} $title $note"
    done

    echo ""
    echo -e "${GRAY}Use 'decisions.sh update <id>' to update these decisions${NC}"
}

show_stats() {
    echo -e "${BLUE}=== Decision Statistics ===${NC}"
    echo ""

    local total=$(jq '.decisions | length' "$DECISIONS_FILE")
    local active=$(jq '.decisions | map(select(.status == "active")) | length' "$DECISIONS_FILE")
    local reversed=$(jq '.decisions | map(select(.status == "reversed")) | length' "$DECISIONS_FILE")
    local superseded=$(jq '.decisions | map(select(.status == "superseded")) | length' "$DECISIONS_FILE")
    local pending=$(jq '.decisions | map(select(.status == "pending")) | length' "$DECISIONS_FILE")
    local with_outcome=$(jq '.decisions | map(select(.actual_outcome != "" and .actual_outcome != null)) | length' "$DECISIONS_FILE")

    echo -e "Total decisions: ${BOLD}$total${NC}"
    echo ""
    echo -e "${CYAN}By Status:${NC}"
    echo -e "  ${GREEN}Active:${NC}     $active"
    echo -e "  ${RED}Reversed:${NC}   $reversed"
    echo -e "  ${YELLOW}Superseded:${NC} $superseded"
    echo -e "  ${CYAN}Pending:${NC}    $pending"
    echo ""
    echo -e "${CYAN}Outcomes recorded:${NC} $with_outcome / $total"

    # Most used tags
    echo ""
    echo -e "${CYAN}Top Tags:${NC}"
    jq -r '.decisions[].tags[]' "$DECISIONS_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | while read -r count tag; do
        echo -e "  ${MAGENTA}$tag${NC} ($count)"
    done
}

show_help() {
    echo "Decisions - Decision log for tracking important choices"
    echo ""
    echo "Usage:"
    echo "  decisions.sh add \"title\"      Record a new decision"
    echo "  decisions.sh list [n]         Show recent decisions (default: 10)"
    echo "  decisions.sh show <id>        Show full decision details"
    echo "  decisions.sh search \"query\"   Search decisions"
    echo "  decisions.sh update <id>      Update a decision"
    echo "  decisions.sh tags             List all tags"
    echo "  decisions.sh by-tag \"tag\"     Filter by tag"
    echo "  decisions.sh pending          Show decisions needing review"
    echo "  decisions.sh stats            Show statistics"
    echo "  decisions.sh help             Show this help"
    echo ""
    echo "Decision Status:"
    echo "  active     - Decision is in effect"
    echo "  pending    - Awaiting implementation/review"
    echo "  reversed   - Decision was rolled back"
    echo "  superseded - Replaced by a newer decision"
    echo ""
    echo "Examples:"
    echo "  decisions.sh add \"Use PostgreSQL for user data\""
    echo "  decisions.sh update 1"
    echo "  decisions.sh search \"database\""
    echo "  decisions.sh by-tag \"architecture\""
}

case "$1" in
    add|new|record)
        shift
        add_decision "$@"
        ;;
    list|ls)
        list_decisions "$2"
        ;;
    show|view|get)
        show_decision "$2"
        ;;
    search|find)
        shift
        search_decisions "$@"
        ;;
    update|edit)
        update_decision "$2"
        ;;
    tags)
        list_tags
        ;;
    by-tag|tag|filter)
        shift
        by_tag "$@"
        ;;
    pending|review)
        show_pending
        ;;
    stats|statistics)
        show_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_decisions 5
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'decisions.sh help' for usage"
        exit 1
        ;;
esac
