#!/bin/bash
#
# Expenses - Personal expense tracker and budget manager
#
# Usage:
#   expenses.sh add <amount> <category> [description]  - Add an expense
#   expenses.sh income <amount> [description]          - Add income
#   expenses.sh list [--today|--week|--month|--year]   - List expenses
#   expenses.sh summary [--week|--month|--year]        - Show spending summary
#   expenses.sh budget <category> <amount>             - Set budget for category
#   expenses.sh budgets                                - Show all budgets
#   expenses.sh categories                             - List categories with totals
#   expenses.sh search <query>                         - Search expenses
#   expenses.sh edit <id> <field> <value>              - Edit an expense
#   expenses.sh delete <id>                            - Delete an expense
#   expenses.sh export [--csv|--json]                  - Export expenses
#   expenses.sh report [--month|--year]                - Generate spending report
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
EXPENSES_FILE="$DATA_DIR/expenses.json"
BUDGETS_FILE="$DATA_DIR/budgets.json"
CONFIG_FILE="$DATA_DIR/config.json"
TODAY=$(date +%Y-%m-%d)
THIS_MONTH=$(date +%Y-%m)
THIS_YEAR=$(date +%Y)

mkdir -p "$DATA_DIR"

# Initialize files if they don't exist
if [[ ! -f "$EXPENSES_FILE" ]]; then
    echo '{"expenses":[],"next_id":1}' > "$EXPENSES_FILE"
fi

if [[ ! -f "$BUDGETS_FILE" ]]; then
    echo '{"budgets":{},"currency":"$"}' > "$BUDGETS_FILE"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"currency":"$","default_categories":["food","transport","shopping","entertainment","utilities","health","education","other"]}' > "$CONFIG_FILE"
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

# Get currency symbol
get_currency() {
    jq -r '.currency // "$"' "$BUDGETS_FILE"
}

CURRENCY=$(get_currency)

# Format currency amount
format_amount() {
    local amount="$1"
    printf "%s%.2f" "$CURRENCY" "$amount"
}

# Add expense
add_expense() {
    local amount="$1"
    local category="$2"
    shift 2
    local description="$*"

    if [[ -z "$amount" || -z "$category" ]]; then
        echo "Usage: expenses.sh add <amount> <category> [description]"
        echo ""
        echo "Categories: food, transport, shopping, entertainment, utilities, health, education, other"
        echo "Or use any custom category name"
        exit 1
    fi

    # Validate amount is a number
    if ! [[ "$amount" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Amount must be a positive number${NC}"
        exit 1
    fi

    # Normalize category to lowercase
    category=$(echo "$category" | tr '[:upper:]' '[:lower:]')

    local next_id=$(jq -r '.next_id' "$EXPENSES_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Extract tags from description
    local tags=$(echo "$description" | grep -oE '#[a-zA-Z0-9_]+' | tr '\n' ',' | sed 's/,$//')

    jq --arg amount "$amount" \
       --arg category "$category" \
       --arg desc "$description" \
       --arg date "$TODAY" \
       --arg timestamp "$timestamp" \
       --arg tags "$tags" \
       --argjson id "$next_id" '
        .expenses += [{
            "id": $id,
            "type": "expense",
            "amount": ($amount | tonumber),
            "category": $category,
            "description": $desc,
            "date": $date,
            "timestamp": $timestamp,
            "tags": $tags
        }] |
        .next_id = ($id + 1)
    ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"

    echo -e "${RED}-$(format_amount "$amount")${NC} ${GREEN}$category${NC}"
    [[ -n "$description" ]] && echo -e "  ${GRAY}$description${NC}"

    # Check budget warning
    check_budget_warning "$category"
}

# Add income
add_income() {
    local amount="$1"
    shift
    local description="$*"

    if [[ -z "$amount" ]]; then
        echo "Usage: expenses.sh income <amount> [description]"
        exit 1
    fi

    # Validate amount is a number
    if ! [[ "$amount" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Amount must be a positive number${NC}"
        exit 1
    fi

    local next_id=$(jq -r '.next_id' "$EXPENSES_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    jq --arg amount "$amount" \
       --arg desc "$description" \
       --arg date "$TODAY" \
       --arg timestamp "$timestamp" \
       --argjson id "$next_id" '
        .expenses += [{
            "id": $id,
            "type": "income",
            "amount": ($amount | tonumber),
            "category": "income",
            "description": $desc,
            "date": $date,
            "timestamp": $timestamp,
            "tags": ""
        }] |
        .next_id = ($id + 1)
    ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"

    echo -e "${GREEN}+$(format_amount "$amount")${NC} income"
    [[ -n "$description" ]] && echo -e "  ${GRAY}$description${NC}"
}

# Check budget warning
check_budget_warning() {
    local category="$1"

    local budget=$(jq -r --arg cat "$category" '.budgets[$cat] // 0' "$BUDGETS_FILE")

    if [[ "$budget" != "0" && "$budget" != "null" ]]; then
        # Get month's spending for this category
        local spent=$(jq -r --arg cat "$category" --arg month "$THIS_MONTH" '
            [.expenses[] | select(.type == "expense" and .category == $cat and (.date | startswith($month)))] | map(.amount) | add // 0
        ' "$EXPENSES_FILE")

        local percent=$(echo "scale=0; ($spent * 100) / $budget" | bc 2>/dev/null || echo "0")

        if [[ "$percent" -ge 100 ]]; then
            echo -e "${RED}  ! Budget exceeded: $(format_amount "$spent") / $(format_amount "$budget") ($percent%)${NC}"
        elif [[ "$percent" -ge 80 ]]; then
            echo -e "${YELLOW}  ! Budget warning: $(format_amount "$spent") / $(format_amount "$budget") ($percent%)${NC}"
        fi
    fi
}

# List expenses
list_expenses() {
    local filter="$1"
    local date_filter=""

    case "$filter" in
        --today|-t)
            date_filter="$TODAY"
            echo -e "${BLUE}=== Expenses for Today ($TODAY) ===${NC}"
            ;;
        --week|-w)
            # Get start of week (Monday)
            local week_start=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null || echo "$TODAY")
            date_filter="$week_start"
            echo -e "${BLUE}=== Expenses This Week ===${NC}"
            ;;
        --month|-m|"")
            date_filter="$THIS_MONTH"
            echo -e "${BLUE}=== Expenses for $(date +%B\ %Y) ===${NC}"
            ;;
        --year|-y)
            date_filter="$THIS_YEAR"
            echo -e "${BLUE}=== Expenses for $THIS_YEAR ===${NC}"
            ;;
        --all|-a)
            date_filter=""
            echo -e "${BLUE}=== All Expenses ===${NC}"
            ;;
    esac

    echo ""

    local query=""
    if [[ -z "$date_filter" ]]; then
        query='.expenses | sort_by(.date) | reverse'
    elif [[ ${#date_filter} -eq 10 ]]; then
        # Full date (today or week start)
        if [[ "$filter" == "--today" || "$filter" == "-t" ]]; then
            query=".expenses | map(select(.date == \"$date_filter\")) | sort_by(.timestamp) | reverse"
        else
            query=".expenses | map(select(.date >= \"$date_filter\")) | sort_by(.date) | reverse"
        fi
    elif [[ ${#date_filter} -eq 7 ]]; then
        # Month
        query=".expenses | map(select(.date | startswith(\"$date_filter\"))) | sort_by(.date) | reverse"
    else
        # Year
        query=".expenses | map(select(.date | startswith(\"$date_filter\"))) | sort_by(.date) | reverse"
    fi

    local total_expense=0
    local total_income=0
    local count=0

    jq -r "$query | .[] | \"\(.id)|\(.type)|\(.amount)|\(.category)|\(.description)|\(.date)\"" "$EXPENSES_FILE" | \
    while IFS='|' read -r id type amount category desc date; do
        if [[ "$type" == "income" ]]; then
            echo -e "${YELLOW}[$id]${NC} ${GREEN}+$(format_amount "$amount")${NC} ${CYAN}$category${NC} ${GRAY}$date${NC}"
        else
            echo -e "${YELLOW}[$id]${NC} ${RED}-$(format_amount "$amount")${NC} ${CYAN}$category${NC} ${GRAY}$date${NC}"
        fi
        [[ -n "$desc" ]] && echo -e "     ${GRAY}$desc${NC}"
    done

    # Calculate totals
    local totals=$(jq -r "$query | {
        expense: [.[] | select(.type == \"expense\")] | map(.amount) | add // 0,
        income: [.[] | select(.type == \"income\")] | map(.amount) | add // 0,
        count: length
    } | \"\(.expense)|\(.income)|\(.count)\"" "$EXPENSES_FILE")

    local total_expense=$(echo "$totals" | cut -d'|' -f1)
    local total_income=$(echo "$totals" | cut -d'|' -f2)
    local count=$(echo "$totals" | cut -d'|' -f3)
    local balance=$(echo "$total_income - $total_expense" | bc)

    echo ""
    echo -e "${GRAY}─────────────────────────────────${NC}"
    echo -e "Entries: ${BOLD}$count${NC}"
    echo -e "Income:  ${GREEN}+$(format_amount "$total_income")${NC}"
    echo -e "Expense: ${RED}-$(format_amount "$total_expense")${NC}"
    if (( $(echo "$balance >= 0" | bc -l) )); then
        echo -e "Balance: ${GREEN}$(format_amount "$balance")${NC}"
    else
        echo -e "Balance: ${RED}$(format_amount "$balance")${NC}"
    fi
}

# Show summary
show_summary() {
    local period="$1"
    local date_filter=""
    local period_name=""

    case "$period" in
        --week|-w)
            local week_start=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null || echo "$TODAY")
            date_filter="$week_start"
            period_name="This Week"
            ;;
        --month|-m|"")
            date_filter="$THIS_MONTH"
            period_name="$(date +%B\ %Y)"
            ;;
        --year|-y)
            date_filter="$THIS_YEAR"
            period_name="$THIS_YEAR"
            ;;
    esac

    echo -e "${BLUE}=== Spending Summary: $period_name ===${NC}"
    echo ""

    # Build filter
    local filter_query=""
    if [[ ${#date_filter} -eq 10 ]]; then
        filter_query="select(.date >= \"$date_filter\")"
    elif [[ ${#date_filter} -eq 7 ]]; then
        filter_query="select(.date | startswith(\"$date_filter\"))"
    else
        filter_query="select(.date | startswith(\"$date_filter\"))"
    fi

    # Get totals by category
    echo -e "${CYAN}By Category:${NC}"

    jq -r ".expenses | map(select(.type == \"expense\") | $filter_query) | group_by(.category) | map({
        category: .[0].category,
        total: (map(.amount) | add),
        count: length
    }) | sort_by(.total) | reverse | .[] | \"\(.category)|\(.total)|\(.count)\"" "$EXPENSES_FILE" | \
    while IFS='|' read -r category total count; do
        # Get budget for comparison
        local budget=$(jq -r --arg cat "$category" '.budgets[$cat] // 0' "$BUDGETS_FILE")

        printf "  ${GREEN}%-15s${NC} ${BOLD}$(format_amount "$total")${NC}" "$category"
        printf " ${GRAY}(%d items)${NC}" "$count"

        if [[ "$budget" != "0" && "$budget" != "null" ]]; then
            local percent=$(echo "scale=0; ($total * 100) / $budget" | bc 2>/dev/null || echo "0")
            if [[ "$percent" -ge 100 ]]; then
                printf " ${RED}[%d%% of budget]${NC}" "$percent"
            elif [[ "$percent" -ge 80 ]]; then
                printf " ${YELLOW}[%d%% of budget]${NC}" "$percent"
            else
                printf " ${GRAY}[%d%% of budget]${NC}" "$percent"
            fi
        fi
        echo ""
    done

    # Overall totals
    local totals=$(jq -r ".expenses | map($filter_query) | {
        expense: [.[] | select(.type == \"expense\")] | map(.amount) | add // 0,
        income: [.[] | select(.type == \"income\")] | map(.amount) | add // 0
    } | \"\(.expense)|\(.income)\"" "$EXPENSES_FILE")

    local total_expense=$(echo "$totals" | cut -d'|' -f1)
    local total_income=$(echo "$totals" | cut -d'|' -f2)
    local balance=$(echo "$total_income - $total_expense" | bc)

    echo ""
    echo -e "${GRAY}─────────────────────────────────${NC}"
    echo -e "Total Income:   ${GREEN}+$(format_amount "$total_income")${NC}"
    echo -e "Total Expenses: ${RED}-$(format_amount "$total_expense")${NC}"
    if (( $(echo "$balance >= 0" | bc -l) )); then
        echo -e "Net Balance:    ${GREEN}$(format_amount "$balance")${NC}"
    else
        echo -e "Net Balance:    ${RED}$(format_amount "$balance")${NC}"
    fi
}

# Set budget
set_budget() {
    local category="$1"
    local amount="$2"

    if [[ -z "$category" || -z "$amount" ]]; then
        echo "Usage: expenses.sh budget <category> <amount>"
        echo ""
        echo "Set monthly budget for a category"
        echo "Use 0 to remove a budget"
        exit 1
    fi

    # Validate amount
    if ! [[ "$amount" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Amount must be a positive number${NC}"
        exit 1
    fi

    category=$(echo "$category" | tr '[:upper:]' '[:lower:]')

    if [[ "$amount" == "0" ]]; then
        jq --arg cat "$category" 'del(.budgets[$cat])' "$BUDGETS_FILE" > "$BUDGETS_FILE.tmp" && mv "$BUDGETS_FILE.tmp" "$BUDGETS_FILE"
        echo -e "${YELLOW}Removed budget for $category${NC}"
    else
        jq --arg cat "$category" --argjson amount "$amount" '.budgets[$cat] = $amount' "$BUDGETS_FILE" > "$BUDGETS_FILE.tmp" && mv "$BUDGETS_FILE.tmp" "$BUDGETS_FILE"
        echo -e "${GREEN}Set budget for $category: $(format_amount "$amount")/month${NC}"
    fi
}

# Show budgets
show_budgets() {
    echo -e "${BLUE}=== Monthly Budgets ===${NC}"
    echo ""

    local has_budgets=$(jq '.budgets | length' "$BUDGETS_FILE")

    if [[ "$has_budgets" -eq 0 ]]; then
        echo "No budgets set."
        echo ""
        echo "Set a budget with: expenses.sh budget <category> <amount>"
        exit 0
    fi

    jq -r '.budgets | to_entries | sort_by(.key) | .[] | "\(.key)|\(.value)"' "$BUDGETS_FILE" | \
    while IFS='|' read -r category budget; do
        # Get this month's spending
        local spent=$(jq -r --arg cat "$category" --arg month "$THIS_MONTH" '
            [.expenses[] | select(.type == "expense" and .category == $cat and (.date | startswith($month)))] | map(.amount) | add // 0
        ' "$EXPENSES_FILE")

        local remaining=$(echo "$budget - $spent" | bc)
        local percent=$(echo "scale=0; ($spent * 100) / $budget" | bc 2>/dev/null || echo "0")

        printf "${GREEN}%-15s${NC} " "$category"
        printf "$(format_amount "$spent") / $(format_amount "$budget")"

        # Progress bar
        local bar_width=20
        local filled=$(echo "scale=0; ($percent * $bar_width) / 100" | bc 2>/dev/null || echo "0")
        [[ $filled -gt $bar_width ]] && filled=$bar_width

        printf " ["
        if [[ "$percent" -ge 100 ]]; then
            printf "${RED}"
        elif [[ "$percent" -ge 80 ]]; then
            printf "${YELLOW}"
        else
            printf "${GREEN}"
        fi

        for ((i=0; i<filled; i++)); do printf "█"; done
        for ((i=filled; i<bar_width; i++)); do printf "░"; done

        printf "${NC}] %d%%" "$percent"

        if (( $(echo "$remaining >= 0" | bc -l) )); then
            printf " ${GRAY}($(format_amount "$remaining") left)${NC}"
        else
            local over=$(echo "$remaining * -1" | bc)
            printf " ${RED}($(format_amount "$over") over)${NC}"
        fi
        echo ""
    done
}

# List categories
list_categories() {
    echo -e "${BLUE}=== Categories (This Month) ===${NC}"
    echo ""

    jq -r ".expenses | map(select(.type == \"expense\" and (.date | startswith(\"$THIS_MONTH\")))) | group_by(.category) | map({
        category: .[0].category,
        total: (map(.amount) | add),
        count: length
    }) | sort_by(.total) | reverse | .[] | \"\(.category)|\(.total)|\(.count)\"" "$EXPENSES_FILE" | \
    while IFS='|' read -r category total count; do
        printf "  ${GREEN}%-15s${NC} $(format_amount "$total") ${GRAY}(%d items)${NC}\n" "$category" "$count"
    done

    echo ""
    echo -e "${CYAN}Default categories:${NC}"
    jq -r '.default_categories | join(", ")' "$CONFIG_FILE"
}

# Search expenses
search_expenses() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: expenses.sh search <query>"
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local results=$(jq -r --arg q "$query" '
        .expenses | map(select(
            (.description | ascii_downcase | contains($q | ascii_downcase)) or
            (.category | ascii_downcase | contains($q | ascii_downcase)) or
            (.tags | ascii_downcase | contains($q | ascii_downcase))
        )) | sort_by(.date) | reverse | .[] | "\(.id)|\(.type)|\(.amount)|\(.category)|\(.description)|\(.date)"
    ' "$EXPENSES_FILE")

    if [[ -z "$results" ]]; then
        echo "No results found."
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id type amount category desc date; do
        if [[ "$type" == "income" ]]; then
            echo -e "${YELLOW}[$id]${NC} ${GREEN}+$(format_amount "$amount")${NC} ${CYAN}$category${NC} ${GRAY}$date${NC}"
        else
            echo -e "${YELLOW}[$id]${NC} ${RED}-$(format_amount "$amount")${NC} ${CYAN}$category${NC} ${GRAY}$date${NC}"
        fi
        [[ -n "$desc" ]] && echo -e "     ${GRAY}$desc${NC}"
    done
}

# Edit expense
edit_expense() {
    local id="$1"
    local field="$2"
    local value="$3"

    if [[ -z "$id" || -z "$field" || -z "$value" ]]; then
        echo "Usage: expenses.sh edit <id> <field> <value>"
        echo ""
        echo "Fields: amount, category, description, date"
        exit 1
    fi

    # Check if expense exists
    local exists=$(jq -r --argjson id "$id" '.expenses[] | select(.id == $id) | .id' "$EXPENSES_FILE")

    if [[ -z "$exists" ]]; then
        echo -e "${RED}Expense #$id not found${NC}"
        exit 1
    fi

    case "$field" in
        amount)
            if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                echo -e "${RED}Error: Amount must be a positive number${NC}"
                exit 1
            fi
            jq --argjson id "$id" --argjson val "$value" '
                .expenses = [.expenses[] | if .id == $id then .amount = $val else . end]
            ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"
            ;;
        category)
            value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
            jq --argjson id "$id" --arg val "$value" '
                .expenses = [.expenses[] | if .id == $id then .category = $val else . end]
            ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"
            ;;
        description|desc)
            jq --argjson id "$id" --arg val "$value" '
                .expenses = [.expenses[] | if .id == $id then .description = $val else . end]
            ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"
            ;;
        date)
            if ! [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                echo -e "${RED}Error: Date must be in YYYY-MM-DD format${NC}"
                exit 1
            fi
            jq --argjson id "$id" --arg val "$value" '
                .expenses = [.expenses[] | if .id == $id then .date = $val else . end]
            ' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"
            ;;
        *)
            echo -e "${RED}Unknown field: $field${NC}"
            echo "Valid fields: amount, category, description, date"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Updated expense #$id: $field = $value${NC}"
}

# Delete expense
delete_expense() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: expenses.sh delete <id>"
        exit 1
    fi

    # Get expense info for confirmation
    local expense=$(jq -r --argjson id "$id" '.expenses[] | select(.id == $id) | "\(.amount)|\(.category)|\(.description)"' "$EXPENSES_FILE")

    if [[ -z "$expense" ]]; then
        echo -e "${RED}Expense #$id not found${NC}"
        exit 1
    fi

    local amount=$(echo "$expense" | cut -d'|' -f1)
    local category=$(echo "$expense" | cut -d'|' -f2)
    local desc=$(echo "$expense" | cut -d'|' -f3)

    echo -e "${YELLOW}About to delete:${NC} $(format_amount "$amount") - $category"
    [[ -n "$desc" ]] && echo -e "  ${GRAY}$desc${NC}"

    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    jq --argjson id "$id" '.expenses = [.expenses[] | select(.id != $id)]' "$EXPENSES_FILE" > "$EXPENSES_FILE.tmp" && mv "$EXPENSES_FILE.tmp" "$EXPENSES_FILE"

    echo -e "${RED}Deleted expense #$id${NC}"
}

# Export expenses
export_expenses() {
    local format="${1:---csv}"
    local filename=""

    case "$format" in
        --csv|-c)
            filename="expenses_export_$(date +%Y%m%d_%H%M%S).csv"
            echo "id,type,date,amount,category,description,tags" > "$filename"
            jq -r '.expenses[] | [.id, .type, .date, .amount, .category, .description, .tags] | @csv' "$EXPENSES_FILE" >> "$filename"
            echo -e "${GREEN}Exported to $filename${NC}"
            ;;
        --json|-j)
            filename="expenses_export_$(date +%Y%m%d_%H%M%S).json"
            jq '.expenses' "$EXPENSES_FILE" > "$filename"
            echo -e "${GREEN}Exported to $filename${NC}"
            ;;
        *)
            echo "Usage: expenses.sh export [--csv|--json]"
            exit 1
            ;;
    esac
}

# Generate report
generate_report() {
    local period="$1"
    local date_filter=""
    local period_name=""

    case "$period" in
        --month|-m|"")
            date_filter="$THIS_MONTH"
            period_name="$(date +%B\ %Y)"
            ;;
        --year|-y)
            date_filter="$THIS_YEAR"
            period_name="$THIS_YEAR"
            ;;
    esac

    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║      EXPENSE REPORT: $period_name${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # Build filter
    local filter_query=""
    if [[ ${#date_filter} -eq 7 ]]; then
        filter_query="select(.date | startswith(\"$date_filter\"))"
    else
        filter_query="select(.date | startswith(\"$date_filter\"))"
    fi

    # Overall summary
    local totals=$(jq -r ".expenses | map($filter_query) | {
        expense: [.[] | select(.type == \"expense\")] | map(.amount) | add // 0,
        income: [.[] | select(.type == \"income\")] | map(.amount) | add // 0,
        count: length
    } | \"\(.expense)|\(.income)|\(.count)\"" "$EXPENSES_FILE")

    local total_expense=$(echo "$totals" | cut -d'|' -f1)
    local total_income=$(echo "$totals" | cut -d'|' -f2)
    local count=$(echo "$totals" | cut -d'|' -f3)
    local balance=$(echo "$total_income - $total_expense" | bc)

    echo -e "${CYAN}Summary${NC}"
    echo -e "  Total Transactions: $count"
    echo -e "  Income:  ${GREEN}+$(format_amount "$total_income")${NC}"
    echo -e "  Expenses: ${RED}-$(format_amount "$total_expense")${NC}"
    if (( $(echo "$balance >= 0" | bc -l) )); then
        echo -e "  Net:     ${GREEN}$(format_amount "$balance")${NC}"
    else
        echo -e "  Net:     ${RED}$(format_amount "$balance")${NC}"
    fi
    echo ""

    # Spending by category
    echo -e "${CYAN}Spending by Category${NC}"

    jq -r ".expenses | map(select(.type == \"expense\") | $filter_query) | group_by(.category) | map({
        category: .[0].category,
        total: (map(.amount) | add),
        count: length,
        avg: ((map(.amount) | add) / length)
    }) | sort_by(.total) | reverse | .[] | \"\(.category)|\(.total)|\(.count)|\(.avg)\"" "$EXPENSES_FILE" | \
    while IFS='|' read -r category total count avg; do
        local percent=$(echo "scale=0; ($total * 100) / $total_expense" | bc 2>/dev/null || echo "0")
        printf "  ${GREEN}%-12s${NC} $(format_amount "$total") (%2d%%) - %d items, avg $(format_amount "$avg")\n" "$category" "$percent" "$count"
    done

    echo ""

    # Top 5 expenses
    echo -e "${CYAN}Top 5 Expenses${NC}"
    jq -r ".expenses | map(select(.type == \"expense\") | $filter_query) | sort_by(.amount) | reverse | .[0:5] | .[] | \"\(.amount)|\(.category)|\(.description)|\(.date)\"" "$EXPENSES_FILE" | \
    while IFS='|' read -r amount category desc date; do
        echo -e "  $(format_amount "$amount") - $category ${GRAY}($date)${NC}"
        [[ -n "$desc" ]] && echo -e "    ${GRAY}$desc${NC}"
    done

    echo ""

    # Budget status
    local has_budgets=$(jq '.budgets | length' "$BUDGETS_FILE")
    if [[ "$has_budgets" -gt 0 ]]; then
        echo -e "${CYAN}Budget Status${NC}"
        jq -r '.budgets | to_entries | .[] | "\(.key)|\(.value)"' "$BUDGETS_FILE" | \
        while IFS='|' read -r category budget; do
            local spent=$(jq -r --arg cat "$category" --arg filter "$date_filter" '
                [.expenses[] | select(.type == "expense" and .category == $cat and (.date | startswith($filter)))] | map(.amount) | add // 0
            ' "$EXPENSES_FILE")

            local percent=$(echo "scale=0; ($spent * 100) / $budget" | bc 2>/dev/null || echo "0")
            local status="OK"
            local color="$GREEN"

            if [[ "$percent" -ge 100 ]]; then
                status="OVER"
                color="$RED"
            elif [[ "$percent" -ge 80 ]]; then
                status="WARNING"
                color="$YELLOW"
            fi

            printf "  %-12s $(format_amount "$spent") / $(format_amount "$budget") (%3d%%) ${color}[%s]${NC}\n" "$category" "$percent" "$status"
        done
    fi
}

# Set currency
set_currency() {
    local symbol="$1"

    if [[ -z "$symbol" ]]; then
        echo "Usage: expenses.sh currency <symbol>"
        echo "Example: expenses.sh currency €"
        exit 1
    fi

    jq --arg sym "$symbol" '.currency = $sym' "$BUDGETS_FILE" > "$BUDGETS_FILE.tmp" && mv "$BUDGETS_FILE.tmp" "$BUDGETS_FILE"
    echo -e "${GREEN}Currency set to: $symbol${NC}"
}

# Show help
show_help() {
    echo "Expenses - Personal expense tracker and budget manager"
    echo ""
    echo "Usage:"
    echo "  expenses.sh add <amount> <category> [desc]   Add an expense"
    echo "  expenses.sh income <amount> [desc]           Add income"
    echo "  expenses.sh list [--today|--week|--month]    List expenses"
    echo "  expenses.sh summary [--week|--month|--year]  Show spending summary"
    echo "  expenses.sh budget <category> <amount>       Set monthly budget"
    echo "  expenses.sh budgets                          Show all budgets"
    echo "  expenses.sh categories                       List categories"
    echo "  expenses.sh search <query>                   Search expenses"
    echo "  expenses.sh edit <id> <field> <value>        Edit an expense"
    echo "  expenses.sh delete <id>                      Delete an expense"
    echo "  expenses.sh export [--csv|--json]            Export expenses"
    echo "  expenses.sh report [--month|--year]          Generate report"
    echo "  expenses.sh currency <symbol>                Set currency symbol"
    echo "  expenses.sh help                             Show this help"
    echo ""
    echo "Categories: food, transport, shopping, entertainment, utilities, health, education, other"
    echo "(You can also use any custom category name)"
    echo ""
    echo "Examples:"
    echo "  expenses.sh add 12.50 food \"Lunch at cafe #work\""
    echo "  expenses.sh income 3000 \"Monthly salary\""
    echo "  expenses.sh budget food 500"
    echo "  expenses.sh list --today"
    echo "  expenses.sh report --month"
}

# Main command handler
case "$1" in
    add|a)
        shift
        add_expense "$@"
        ;;
    income|in|i)
        shift
        add_income "$@"
        ;;
    list|ls|l)
        list_expenses "$2"
        ;;
    summary|sum|s)
        show_summary "$2"
        ;;
    budget|b)
        shift
        set_budget "$@"
        ;;
    budgets|bs)
        show_budgets
        ;;
    categories|cats|cat)
        list_categories
        ;;
    search|find|f)
        shift
        search_expenses "$@"
        ;;
    edit|e)
        shift
        edit_expense "$@"
        ;;
    delete|del|rm)
        delete_expense "$2"
        ;;
    export|exp)
        export_expenses "$2"
        ;;
    report|rep|r)
        generate_report "$2"
        ;;
    currency|cur)
        set_currency "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_summary
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'expenses.sh help' for usage"
        exit 1
        ;;
esac
