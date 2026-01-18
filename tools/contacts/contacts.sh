#!/bin/bash
#
# Contacts - Professional networking and relationship manager
#
# Track professional contacts, record interactions, set follow-up reminders,
# and manage your professional network effectively.
#
# Usage:
#   contacts.sh add "Name" ["email"] ["company"] ["role"]  - Add a new contact
#   contacts.sh list [--tag TAG] [--company COMPANY]       - List all contacts
#   contacts.sh show "Name"                                - Show contact details
#   contacts.sh edit "Name"                                - Edit contact in editor
#   contacts.sh log "Name" "Note about interaction"        - Log an interaction
#   contacts.sh tag "Name" "tag1,tag2"                     - Add tags to contact
#   contacts.sh followup "Name" "YYYY-MM-DD" ["reason"]    - Set follow-up reminder
#   contacts.sh due                                        - Show overdue/upcoming follow-ups
#   contacts.sh search "query"                             - Search contacts
#   contacts.sh stats                                      - Show networking statistics
#   contacts.sh export [--format csv|json]                 - Export contacts
#   contacts.sh remove "Name"                              - Remove a contact
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CONTACTS_FILE="$DATA_DIR/contacts.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize contacts file if it doesn't exist
if [[ ! -f "$CONTACTS_FILE" ]]; then
    echo '{"contacts":[],"next_id":1}' > "$CONTACTS_FILE"
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

# Helper: Normalize name for comparison (lowercase, trim)
normalize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Helper: Find contact by name (case-insensitive)
find_contact_id() {
    local search_name=$(normalize_name "$1")
    jq -r --arg name "$search_name" '
        .contacts[] |
        select((.name | ascii_downcase) == $name) |
        .id
    ' "$CONTACTS_FILE" | head -1
}

# Helper: Format date for display
format_date() {
    local date="$1"
    if [[ -n "$date" ]] && [[ "$date" != "null" ]]; then
        date -d "$date" "+%b %d, %Y" 2>/dev/null || echo "$date"
    fi
}

# Helper: Calculate days since/until
days_diff() {
    local target_date="$1"
    local target_epoch=$(date -d "$target_date" +%s 2>/dev/null)
    local today_epoch=$(date +%s)
    if [[ -n "$target_epoch" ]]; then
        echo $(( (target_epoch - today_epoch) / 86400 ))
    else
        echo "0"
    fi
}

add_contact() {
    local name="$1"
    local email="${2:-}"
    local company="${3:-}"
    local role="${4:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: contacts.sh add \"Name\" [\"email\"] [\"company\"] [\"role\"]"
        exit 1
    fi

    # Check if contact already exists
    local existing=$(find_contact_id "$name")
    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Contact '$name' already exists.${NC}"
        echo "Use 'contacts.sh edit \"$name\"' to modify."
        exit 1
    fi

    local next_id=$(jq -r '.next_id' "$CONTACTS_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --arg name "$name" \
       --arg email "$email" \
       --arg company "$company" \
       --arg role "$role" \
       --arg created "$timestamp" \
       --argjson id "$next_id" '
        .contacts += [{
            "id": $id,
            "name": $name,
            "email": $email,
            "company": $company,
            "role": $role,
            "phone": "",
            "linkedin": "",
            "notes": "",
            "tags": [],
            "interactions": [],
            "followup_date": null,
            "followup_reason": "",
            "created": $created,
            "last_contact": null
        }] |
        .next_id = ($id + 1)
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    echo -e "${GREEN}Added contact:${NC} $name"
    [[ -n "$email" ]] && echo -e "  ${CYAN}Email:${NC} $email"
    [[ -n "$company" ]] && echo -e "  ${CYAN}Company:${NC} $company"
    [[ -n "$role" ]] && echo -e "  ${CYAN}Role:${NC} $role"
}

list_contacts() {
    local filter_tag=""
    local filter_company=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag|-t)
                filter_tag="$2"
                shift 2
                ;;
            --company|-c)
                filter_company="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local count=$(jq '.contacts | length' "$CONTACTS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No contacts yet."
        echo "Add one with: contacts.sh add \"John Doe\" \"john@example.com\" \"Acme Inc\" \"Engineer\""
        exit 0
    fi

    echo -e "${BLUE}=== Contacts ===${NC}"
    echo ""

    # Build jq filter
    local jq_filter='.contacts | sort_by(.name | ascii_downcase)'

    if [[ -n "$filter_tag" ]]; then
        jq_filter="$jq_filter | map(select(.tags | index(\"$filter_tag\")))"
    fi

    if [[ -n "$filter_company" ]]; then
        local lower_company=$(echo "$filter_company" | tr '[:upper:]' '[:lower:]')
        jq_filter="$jq_filter | map(select(.company | ascii_downcase | contains(\"$lower_company\")))"
    fi

    jq -r "$jq_filter | .[] | \"\(.name)|\(.company)|\(.role)|\(.last_contact // \"never\")|\(.tags | join(\",\"))\"" "$CONTACTS_FILE" | \
    while IFS='|' read -r name company role last_contact tags; do
        echo -ne "  ${GREEN}$name${NC}"

        if [[ -n "$role" ]] && [[ -n "$company" ]]; then
            echo -ne " ${GRAY}- $role at $company${NC}"
        elif [[ -n "$company" ]]; then
            echo -ne " ${GRAY}- $company${NC}"
        elif [[ -n "$role" ]]; then
            echo -ne " ${GRAY}- $role${NC}"
        fi

        if [[ -n "$tags" ]]; then
            echo -ne " ${CYAN}[$tags]${NC}"
        fi

        if [[ "$last_contact" != "never" ]] && [[ -n "$last_contact" ]]; then
            local days=$(days_diff "$last_contact")
            days=$((days * -1))
            if [[ $days -gt 90 ]]; then
                echo -ne " ${YELLOW}(${days}d ago)${NC}"
            fi
        fi

        echo ""
    done

    local filtered_count=$(jq -r "$jq_filter | length" "$CONTACTS_FILE")
    echo ""
    echo -e "${GRAY}Total: $filtered_count contact(s)${NC}"
}

show_contact() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: contacts.sh show \"Name\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    local contact=$(jq --argjson id "$contact_id" '.contacts[] | select(.id == $id)' "$CONTACTS_FILE")

    local c_name=$(echo "$contact" | jq -r '.name')
    local c_email=$(echo "$contact" | jq -r '.email // ""')
    local c_company=$(echo "$contact" | jq -r '.company // ""')
    local c_role=$(echo "$contact" | jq -r '.role // ""')
    local c_phone=$(echo "$contact" | jq -r '.phone // ""')
    local c_linkedin=$(echo "$contact" | jq -r '.linkedin // ""')
    local c_notes=$(echo "$contact" | jq -r '.notes // ""')
    local c_tags=$(echo "$contact" | jq -r '.tags | join(", ")')
    local c_created=$(echo "$contact" | jq -r '.created')
    local c_last=$(echo "$contact" | jq -r '.last_contact // "Never"')
    local c_followup=$(echo "$contact" | jq -r '.followup_date // ""')
    local c_followup_reason=$(echo "$contact" | jq -r '.followup_reason // ""')

    echo -e "${BLUE}=== Contact: ${BOLD}$c_name${NC}${BLUE} ===${NC}"
    echo ""

    [[ -n "$c_email" ]] && echo -e "  ${CYAN}Email:${NC}    $c_email"
    [[ -n "$c_company" ]] && echo -e "  ${CYAN}Company:${NC}  $c_company"
    [[ -n "$c_role" ]] && echo -e "  ${CYAN}Role:${NC}     $c_role"
    [[ -n "$c_phone" ]] && echo -e "  ${CYAN}Phone:${NC}    $c_phone"
    [[ -n "$c_linkedin" ]] && echo -e "  ${CYAN}LinkedIn:${NC} $c_linkedin"
    [[ -n "$c_tags" ]] && echo -e "  ${CYAN}Tags:${NC}     $c_tags"
    echo ""
    echo -e "  ${GRAY}Added:${NC}        $(format_date "$c_created")"
    echo -e "  ${GRAY}Last contact:${NC} $(format_date "$c_last")"

    if [[ -n "$c_followup" ]] && [[ "$c_followup" != "null" ]]; then
        local days=$(days_diff "$c_followup")
        if [[ $days -lt 0 ]]; then
            echo -e "  ${RED}Follow-up:${NC}    $(format_date "$c_followup") (${days#-} days overdue)"
        elif [[ $days -eq 0 ]]; then
            echo -e "  ${YELLOW}Follow-up:${NC}    Today!"
        else
            echo -e "  ${GREEN}Follow-up:${NC}    $(format_date "$c_followup") (in $days days)"
        fi
        [[ -n "$c_followup_reason" ]] && echo -e "                ${GRAY}$c_followup_reason${NC}"
    fi

    if [[ -n "$c_notes" ]]; then
        echo ""
        echo -e "  ${CYAN}Notes:${NC}"
        echo "$c_notes" | sed 's/^/    /'
    fi

    # Show recent interactions
    local interactions=$(echo "$contact" | jq -r '.interactions | reverse | .[0:5]')
    local int_count=$(echo "$interactions" | jq 'length')

    if [[ "$int_count" -gt 0 ]]; then
        echo ""
        echo -e "  ${CYAN}Recent Interactions:${NC}"
        echo "$interactions" | jq -r '.[] | "    \(.date): \(.note)"'
    fi
}

edit_contact() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: contacts.sh edit \"Name\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    # Create temp file with contact data for editing
    local tmpfile=$(mktemp /tmp/contact.XXXXXX.json)
    jq --argjson id "$contact_id" '.contacts[] | select(.id == $id) | del(.interactions) | del(.id) | del(.created)' "$CONTACTS_FILE" > "$tmpfile"

    local editor="${EDITOR:-nano}"
    $editor "$tmpfile"

    # Validate JSON
    if ! jq empty "$tmpfile" 2>/dev/null; then
        echo -e "${RED}Invalid JSON. Changes not saved.${NC}"
        rm "$tmpfile"
        exit 1
    fi

    # Update contact
    local updated=$(cat "$tmpfile")
    jq --argjson id "$contact_id" --argjson updated "$updated" '
        .contacts = [.contacts[] | if .id == $id then . + $updated else . end]
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    rm "$tmpfile"
    echo -e "${GREEN}Contact updated.${NC}"
}

log_interaction() {
    local name="$1"
    local note="$2"

    if [[ -z "$name" ]] || [[ -z "$note" ]]; then
        echo "Usage: contacts.sh log \"Name\" \"Note about interaction\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d')

    jq --argjson id "$contact_id" --arg note "$note" --arg date "$timestamp" '
        .contacts = [.contacts[] |
            if .id == $id then
                .interactions += [{"date": $date, "note": $note}] |
                .last_contact = $date
            else .
            end
        ]
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    echo -e "${GREEN}Logged interaction with $(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .name' "$CONTACTS_FILE")${NC}"
    echo -e "  ${GRAY}$note${NC}"
}

add_tags() {
    local name="$1"
    local tags_str="$2"

    if [[ -z "$name" ]] || [[ -z "$tags_str" ]]; then
        echo "Usage: contacts.sh tag \"Name\" \"tag1,tag2\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    # Convert comma-separated tags to JSON array
    local tags_json=$(echo "$tags_str" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)

    jq --argjson id "$contact_id" --argjson newtags "$tags_json" '
        .contacts = [.contacts[] |
            if .id == $id then
                .tags = (.tags + $newtags | unique)
            else .
            end
        ]
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    local c_name=$(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .name' "$CONTACTS_FILE")
    local all_tags=$(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .tags | join(", ")' "$CONTACTS_FILE")

    echo -e "${GREEN}Updated tags for $c_name:${NC} $all_tags"
}

set_followup() {
    local name="$1"
    local date="$2"
    local reason="${3:-}"

    if [[ -z "$name" ]] || [[ -z "$date" ]]; then
        echo "Usage: contacts.sh followup \"Name\" \"YYYY-MM-DD\" [\"reason\"]"
        exit 1
    fi

    # Validate date
    if ! date -d "$date" &>/dev/null; then
        echo -e "${RED}Invalid date format. Use YYYY-MM-DD${NC}"
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    jq --argjson id "$contact_id" --arg date "$date" --arg reason "$reason" '
        .contacts = [.contacts[] |
            if .id == $id then
                .followup_date = $date |
                .followup_reason = $reason
            else .
            end
        ]
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    local c_name=$(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .name' "$CONTACTS_FILE")
    echo -e "${GREEN}Set follow-up for $c_name:${NC} $(format_date "$date")"
    [[ -n "$reason" ]] && echo -e "  ${GRAY}Reason: $reason${NC}"
}

show_due() {
    echo -e "${BLUE}=== Follow-ups ===${NC}"
    echo ""

    # Get overdue
    local overdue=$(jq -r --arg today "$TODAY" '
        .contacts |
        map(select(.followup_date != null and .followup_date < $today)) |
        sort_by(.followup_date) |
        .[] |
        "\(.name)|\(.followup_date)|\(.followup_reason)"
    ' "$CONTACTS_FILE")

    if [[ -n "$overdue" ]]; then
        echo -e "${RED}Overdue:${NC}"
        echo "$overdue" | while IFS='|' read -r name fdate reason; do
            local days=$(days_diff "$fdate")
            days=$((days * -1))
            echo -e "  ${RED}$name${NC} - $(format_date "$fdate") (${days}d overdue)"
            [[ -n "$reason" ]] && echo -e "    ${GRAY}$reason${NC}"
        done
        echo ""
    fi

    # Get due today
    local today_due=$(jq -r --arg today "$TODAY" '
        .contacts |
        map(select(.followup_date == $today)) |
        .[] |
        "\(.name)|\(.followup_reason)"
    ' "$CONTACTS_FILE")

    if [[ -n "$today_due" ]]; then
        echo -e "${YELLOW}Due Today:${NC}"
        echo "$today_due" | while IFS='|' read -r name reason; do
            echo -e "  ${YELLOW}$name${NC}"
            [[ -n "$reason" ]] && echo -e "    ${GRAY}$reason${NC}"
        done
        echo ""
    fi

    # Get upcoming (next 14 days)
    local future=$(date -d "+14 days" +%Y-%m-%d 2>/dev/null || date -v+14d +%Y-%m-%d 2>/dev/null)
    local upcoming=$(jq -r --arg today "$TODAY" --arg future "$future" '
        .contacts |
        map(select(.followup_date != null and .followup_date > $today and .followup_date <= $future)) |
        sort_by(.followup_date) |
        .[] |
        "\(.name)|\(.followup_date)|\(.followup_reason)"
    ' "$CONTACTS_FILE")

    if [[ -n "$upcoming" ]]; then
        echo -e "${GREEN}Upcoming (next 14 days):${NC}"
        echo "$upcoming" | while IFS='|' read -r name fdate reason; do
            local days=$(days_diff "$fdate")
            echo -e "  ${GREEN}$name${NC} - $(format_date "$fdate") (in ${days}d)"
            [[ -n "$reason" ]] && echo -e "    ${GRAY}$reason${NC}"
        done
        echo ""
    fi

    # Check for stale contacts (not contacted in 90+ days)
    local stale=$(jq -r --arg cutoff "$(date -d "-90 days" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d 2>/dev/null)" '
        .contacts |
        map(select(.last_contact != null and .last_contact < $cutoff and .followup_date == null)) |
        sort_by(.last_contact) |
        .[0:5] |
        .[] |
        "\(.name)|\(.last_contact)"
    ' "$CONTACTS_FILE")

    if [[ -n "$stale" ]]; then
        echo -e "${MAGENTA}Stale Contacts (90+ days, no follow-up set):${NC}"
        echo "$stale" | while IFS='|' read -r name last; do
            local days=$(days_diff "$last")
            days=$((days * -1))
            echo -e "  ${GRAY}$name${NC} - last contact ${days}d ago"
        done
    fi
}

search_contacts() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: contacts.sh search \"query\""
        exit 1
    fi

    local lower_query=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$lower_query" '
        .contacts |
        map(select(
            (.name | ascii_downcase | contains($q)) or
            (.email | ascii_downcase | contains($q)) or
            (.company | ascii_downcase | contains($q)) or
            (.role | ascii_downcase | contains($q)) or
            (.notes | ascii_downcase | contains($q)) or
            (.tags | join(" ") | ascii_downcase | contains($q))
        )) |
        .[] |
        "\(.name)|\(.company)|\(.role)"
    ' "$CONTACTS_FILE")

    if [[ -z "$results" ]]; then
        echo "No contacts found matching \"$query\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r name company role; do
        echo -ne "  ${GREEN}$name${NC}"
        [[ -n "$company" ]] && echo -ne " ${GRAY}at $company${NC}"
        [[ -n "$role" ]] && echo -ne " ${GRAY}($role)${NC}"
        echo ""
    done
}

show_stats() {
    echo -e "${BLUE}=== Networking Statistics ===${NC}"
    echo ""

    local total=$(jq '.contacts | length' "$CONTACTS_FILE")
    echo -e "  ${CYAN}Total contacts:${NC}          $total"

    local with_followup=$(jq '[.contacts[] | select(.followup_date != null)] | length' "$CONTACTS_FILE")
    echo -e "  ${CYAN}With follow-up set:${NC}      $with_followup"

    local contacted_30d=$(jq --arg cutoff "$(date -d "-30 days" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null)" \
        '[.contacts[] | select(.last_contact != null and .last_contact >= $cutoff)] | length' "$CONTACTS_FILE")
    echo -e "  ${CYAN}Contacted (last 30d):${NC}    $contacted_30d"

    local interactions_30d=$(jq --arg cutoff "$(date -d "-30 days" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null)" \
        '[.contacts[].interactions[] | select(.date >= $cutoff)] | length' "$CONTACTS_FILE")
    echo -e "  ${CYAN}Interactions (last 30d):${NC} $interactions_30d"

    echo ""
    echo -e "${CYAN}Top Tags:${NC}"
    jq -r '.contacts[].tags[]' "$CONTACTS_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | \
    while read count tag; do
        echo "  $tag: $count"
    done

    echo ""
    echo -e "${CYAN}Top Companies:${NC}"
    jq -r '.contacts[] | select(.company != "") | .company' "$CONTACTS_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | \
    while read count company; do
        echo "  $company: $count"
    done
}

export_contacts() {
    local format="${1:-json}"

    case "$format" in
        --format)
            format="${2:-json}"
            ;;
    esac

    case "$format" in
        csv)
            echo "name,email,company,role,phone,tags,last_contact,followup_date"
            jq -r '.contacts[] | [.name, .email, .company, .role, .phone, (.tags | join(";")), .last_contact // "", .followup_date // ""] | @csv' "$CONTACTS_FILE"
            ;;
        json|*)
            jq '.contacts' "$CONTACTS_FILE"
            ;;
    esac
}

remove_contact() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: contacts.sh remove \"Name\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    local c_name=$(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .name' "$CONTACTS_FILE")

    jq --argjson id "$contact_id" '.contacts = [.contacts[] | select(.id != $id)]' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    echo -e "${RED}Removed contact:${NC} $c_name"
}

clear_followup() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: contacts.sh clear-followup \"Name\""
        exit 1
    fi

    local contact_id=$(find_contact_id "$name")

    if [[ -z "$contact_id" ]]; then
        echo -e "${RED}Contact '$name' not found.${NC}"
        exit 1
    fi

    jq --argjson id "$contact_id" '
        .contacts = [.contacts[] |
            if .id == $id then
                .followup_date = null |
                .followup_reason = ""
            else .
            end
        ]
    ' "$CONTACTS_FILE" > "$CONTACTS_FILE.tmp" && mv "$CONTACTS_FILE.tmp" "$CONTACTS_FILE"

    local c_name=$(jq -r --argjson id "$contact_id" '.contacts[] | select(.id == $id) | .name' "$CONTACTS_FILE")
    echo -e "${GREEN}Cleared follow-up for $c_name${NC}"
}

show_help() {
    echo "Contacts - Professional networking and relationship manager"
    echo ""
    echo "Usage:"
    echo "  contacts.sh add \"Name\" [email] [company] [role]  Add a new contact"
    echo "  contacts.sh list [--tag TAG] [--company COMPANY]  List contacts"
    echo "  contacts.sh show \"Name\"                          Show contact details"
    echo "  contacts.sh edit \"Name\"                          Edit contact in editor"
    echo "  contacts.sh log \"Name\" \"note\"                    Log an interaction"
    echo "  contacts.sh tag \"Name\" \"tag1,tag2\"               Add tags to contact"
    echo "  contacts.sh followup \"Name\" \"YYYY-MM-DD\" [reason] Set follow-up reminder"
    echo "  contacts.sh clear-followup \"Name\"                Clear follow-up"
    echo "  contacts.sh due                                   Show due follow-ups"
    echo "  contacts.sh search \"query\"                        Search contacts"
    echo "  contacts.sh stats                                 Show statistics"
    echo "  contacts.sh export [--format csv|json]            Export contacts"
    echo "  contacts.sh remove \"Name\"                         Remove a contact"
    echo "  contacts.sh help                                  Show this help"
    echo ""
    echo "Examples:"
    echo "  contacts.sh add \"Jane Smith\" \"jane@corp.com\" \"TechCorp\" \"CTO\""
    echo "  contacts.sh log \"Jane Smith\" \"Met at conference, discussed partnership\""
    echo "  contacts.sh tag \"Jane Smith\" \"vip,partner,tech\""
    echo "  contacts.sh followup \"Jane Smith\" \"2026-02-01\" \"Send proposal\""
    echo "  contacts.sh list --tag vip"
    echo "  contacts.sh list --company TechCorp"
}

case "$1" in
    add)
        shift
        add_contact "$@"
        ;;
    list|ls)
        shift
        list_contacts "$@"
        ;;
    show|view|info)
        shift
        show_contact "$@"
        ;;
    edit)
        shift
        edit_contact "$@"
        ;;
    log|note|interaction)
        shift
        log_interaction "$@"
        ;;
    tag|tags)
        shift
        add_tags "$@"
        ;;
    followup|follow-up|fu)
        shift
        set_followup "$@"
        ;;
    clear-followup|clear-fu)
        shift
        clear_followup "$@"
        ;;
    due|reminders|pending)
        show_due
        ;;
    search|find)
        shift
        search_contacts "$@"
        ;;
    stats|statistics)
        show_stats
        ;;
    export)
        shift
        export_contacts "$@"
        ;;
    remove|rm|delete)
        shift
        remove_contact "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_due
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'contacts.sh help' for usage"
        exit 1
        ;;
esac
