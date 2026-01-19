#!/bin/bash
#
# Checklist - Reusable checklist manager for common workflows
#
# Unlike tasks (one-off items) or habits (daily recurring), checklists are
# reusable templates that can be checked off and reset for repetitive workflows
# like code reviews, deployments, travel packing, or morning routines.
#
# Usage:
#   checklist.sh new "name" [-d "description"]   Create a new checklist
#   checklist.sh add "name" "item"               Add item to checklist
#   checklist.sh remove "name" <n>               Remove item from checklist
#   checklist.sh check "name" <n>                Check/uncheck item
#   checklist.sh show "name"                     Show checklist with status
#   checklist.sh reset "name"                    Uncheck all items
#   checklist.sh list                            List all checklists
#   checklist.sh run "name"                      Interactive run through checklist
#   checklist.sh copy "source" "dest"            Copy checklist as new template
#   checklist.sh delete "name"                   Delete a checklist
#   checklist.sh history "name"                  Show completion history
#   checklist.sh export "name" [file]            Export checklist to markdown
#   checklist.sh import <file>                   Import checklist from markdown
#   checklist.sh templates                       Show built-in templates
#   checklist.sh use-template "template"         Create from built-in template
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CHECKLISTS_DIR="$DATA_DIR/checklists"
HISTORY_FILE="$DATA_DIR/history.json"

mkdir -p "$CHECKLISTS_DIR"

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

# Initialize history file
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"completions":[]}' > "$HISTORY_FILE"
fi

# Sanitize checklist name for filename
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Get checklist file path
get_checklist_file() {
    local name="$1"
    local sanitized=$(sanitize_name "$name")
    echo "$CHECKLISTS_DIR/$sanitized.json"
}

# Find checklist by name (partial match)
find_checklist() {
    local search="$1"
    local sanitized=$(sanitize_name "$search")

    # Try exact match first
    if [[ -f "$CHECKLISTS_DIR/$sanitized.json" ]]; then
        echo "$CHECKLISTS_DIR/$sanitized.json"
        return 0
    fi

    # Try partial match
    local matches=()
    for file in "$CHECKLISTS_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file" .json)
            if [[ "$basename" == *"$sanitized"* ]]; then
                matches+=("$file")
            fi
        fi
    done

    if [[ ${#matches[@]} -eq 1 ]]; then
        echo "${matches[0]}"
        return 0
    elif [[ ${#matches[@]} -gt 1 ]]; then
        echo -e "${YELLOW}Multiple matches found:${NC}" >&2
        for m in "${matches[@]}"; do
            echo "  - $(jq -r '.name' "$m")" >&2
        done
        return 1
    fi

    return 1
}

# Create new checklist
create_checklist() {
    local name=""
    local description=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--description)
                description="$2"
                shift 2
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh new \"Checklist Name\" [-d \"Description\"]"
        exit 1
    fi

    local file=$(get_checklist_file "$name")

    if [[ -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' already exists${NC}"
        exit 1
    fi

    local created=$(date '+%Y-%m-%d %H:%M:%S')

    jq -n --arg name "$name" --arg desc "$description" --arg created "$created" '{
        name: $name,
        description: $desc,
        created: $created,
        items: [],
        completion_count: 0,
        last_completed: null
    }' > "$file"

    echo -e "${GREEN}Created checklist:${NC} $name"
    if [[ -n "$description" ]]; then
        echo -e "${GRAY}$description${NC}"
    fi
    echo ""
    echo "Add items with: checklist.sh add \"$name\" \"Item description\""
}

# Add item to checklist
add_item() {
    local name="$1"
    local item="$2"

    if [[ -z "$name" ]] || [[ -z "$item" ]]; then
        echo "Usage: checklist.sh add \"checklist\" \"Item to add\""
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    jq --arg item "$item" '.items += [{text: $item, checked: false}]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    local checklist_name=$(jq -r '.name' "$file")
    local count=$(jq '.items | length' "$file")
    echo -e "${GREEN}Added to $checklist_name:${NC} $item (item #$count)"
}

# Remove item from checklist
remove_item() {
    local name="$1"
    local index="$2"

    if [[ -z "$name" ]] || [[ -z "$index" ]]; then
        echo "Usage: checklist.sh remove \"checklist\" <item_number>"
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local idx=$((index - 1))
    local exists=$(jq --argjson idx "$idx" '.items[$idx] != null' "$file")

    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Item #$index not found${NC}"
        exit 1
    fi

    local item_text=$(jq -r --argjson idx "$idx" '.items[$idx].text' "$file")

    jq --argjson idx "$idx" 'del(.items[$idx])' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    echo -e "${RED}Removed:${NC} $item_text"
}

# Check/uncheck item
check_item() {
    local name="$1"
    local index="$2"

    if [[ -z "$name" ]] || [[ -z "$index" ]]; then
        echo "Usage: checklist.sh check \"checklist\" <item_number>"
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local idx=$((index - 1))
    local exists=$(jq --argjson idx "$idx" '.items[$idx] != null' "$file")

    if [[ "$exists" != "true" ]]; then
        echo -e "${RED}Item #$index not found${NC}"
        exit 1
    fi

    # Toggle checked state
    local current=$(jq -r --argjson idx "$idx" '.items[$idx].checked' "$file")
    local new_state="true"
    [[ "$current" == "true" ]] && new_state="false"

    jq --argjson idx "$idx" --argjson state "$new_state" '.items[$idx].checked = $state' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    local item_text=$(jq -r --argjson idx "$idx" '.items[$idx].text' "$file")

    if [[ "$new_state" == "true" ]]; then
        echo -e "${GREEN}[x]${NC} $item_text"
    else
        echo -e "${GRAY}[ ]${NC} $item_text"
    fi

    # Check if all items are now checked
    local all_checked=$(jq '[.items[].checked] | all' "$file")
    local item_count=$(jq '.items | length' "$file")

    if [[ "$all_checked" == "true" ]] && [[ "$item_count" -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}${BOLD}All items checked!${NC}"
        record_completion "$file"
    fi
}

# Show checklist
show_checklist() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh show \"checklist\""
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local checklist_name=$(jq -r '.name' "$file")
    local description=$(jq -r '.description // ""' "$file")
    local item_count=$(jq '.items | length' "$file")
    local checked_count=$(jq '[.items[] | select(.checked == true)] | length' "$file")
    local completion_count=$(jq '.completion_count' "$file")

    echo -e "${BLUE}${BOLD}=== $checklist_name ===${NC}"
    if [[ -n "$description" && "$description" != "null" ]]; then
        echo -e "${GRAY}$description${NC}"
    fi
    echo ""

    if [[ "$item_count" -eq 0 ]]; then
        echo "No items in this checklist."
        echo "Add items with: checklist.sh add \"$checklist_name\" \"Item\""
        exit 0
    fi

    # Progress bar
    local progress=0
    if [[ "$item_count" -gt 0 ]]; then
        progress=$((checked_count * 100 / item_count))
    fi

    local bar_width=20
    local filled=$((progress * bar_width / 100))
    local empty=$((bar_width - filled))

    printf "${CYAN}Progress:${NC} ["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)\n" "$progress" "$checked_count" "$item_count"
    echo ""

    # Show items
    local i=1
    jq -r '.items[] | "\(.checked)|\(.text)"' "$file" | while IFS='|' read -r checked text; do
        if [[ "$checked" == "true" ]]; then
            echo -e "  ${GREEN}$i. [x]${NC} ${GRAY}$text${NC}"
        else
            echo -e "  ${YELLOW}$i. [ ]${NC} $text"
        fi
        ((i++))
    done

    echo ""
    if [[ "$completion_count" -gt 0 ]]; then
        echo -e "${GRAY}Completed $completion_count time(s)${NC}"
    fi
}

# Reset checklist (uncheck all)
reset_checklist() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh reset \"checklist\""
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    jq '.items = [.items[] | .checked = false]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    local checklist_name=$(jq -r '.name' "$file")
    echo -e "${CYAN}Reset:${NC} $checklist_name"
    echo "All items unchecked."
}

# List all checklists
list_checklists() {
    echo -e "${BLUE}${BOLD}=== Your Checklists ===${NC}"
    echo ""

    local count=0

    for file in "$CHECKLISTS_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local name=$(jq -r '.name' "$file")
            local description=$(jq -r '.description // ""' "$file")
            local item_count=$(jq '.items | length' "$file")
            local checked_count=$(jq '[.items[] | select(.checked == true)] | length' "$file")
            local completion_count=$(jq '.completion_count' "$file")

            # Progress indicator
            local status=""
            if [[ "$item_count" -eq 0 ]]; then
                status="${GRAY}(empty)${NC}"
            elif [[ "$checked_count" -eq "$item_count" ]]; then
                status="${GREEN}(complete)${NC}"
            elif [[ "$checked_count" -gt 0 ]]; then
                status="${YELLOW}($checked_count/$item_count)${NC}"
            else
                status="${GRAY}($item_count items)${NC}"
            fi

            echo -e "  ${CYAN}$name${NC} $status"
            if [[ -n "$description" && "$description" != "null" ]]; then
                echo -e "    ${GRAY}$description${NC}"
            fi

            ((count++))
        fi
    done

    if [[ "$count" -eq 0 ]]; then
        echo "No checklists yet."
        echo ""
        echo "Create one with: checklist.sh new \"Checklist Name\""
        echo "Or use a template: checklist.sh templates"
    else
        echo ""
        echo -e "${GRAY}Total: $count checklist(s)${NC}"
    fi
}

# Interactive run through checklist
run_checklist() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh run \"checklist\""
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local checklist_name=$(jq -r '.name' "$file")
    local item_count=$(jq '.items | length' "$file")

    if [[ "$item_count" -eq 0 ]]; then
        echo "Checklist is empty."
        exit 0
    fi

    echo -e "${BLUE}${BOLD}=== Running: $checklist_name ===${NC}"
    echo -e "${GRAY}Press Enter to check, 's' to skip, 'q' to quit${NC}"
    echo ""

    local i=0
    while [[ $i -lt $item_count ]]; do
        local text=$(jq -r --argjson i "$i" '.items[$i].text' "$file")
        local checked=$(jq -r --argjson i "$i" '.items[$i].checked' "$file")

        local idx=$((i + 1))

        if [[ "$checked" == "true" ]]; then
            echo -e "${GREEN}$idx. [x]${NC} $text (already checked)"
            ((i++))
            continue
        fi

        echo -ne "${YELLOW}$idx. [ ]${NC} $text "
        read -n 1 -r response
        echo ""

        case "$response" in
            q|Q)
                echo ""
                echo "Stopped."
                exit 0
                ;;
            s|S)
                echo -e "  ${GRAY}Skipped${NC}"
                ;;
            *)
                jq --argjson i "$i" '.items[$i].checked = true' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
                echo -e "  ${GREEN}Checked!${NC}"
                ;;
        esac

        ((i++))
    done

    echo ""

    # Check if all done
    local all_checked=$(jq '[.items[].checked] | all' "$file")
    if [[ "$all_checked" == "true" ]]; then
        echo -e "${GREEN}${BOLD}Checklist complete!${NC}"
        record_completion "$file"
    else
        local checked_count=$(jq '[.items[] | select(.checked == true)] | length' "$file")
        echo -e "${CYAN}Progress: $checked_count/$item_count checked${NC}"
    fi
}

# Record completion in history
record_completion() {
    local file="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local checklist_name=$(jq -r '.name' "$file")

    # Update checklist stats
    jq --arg ts "$timestamp" '.completion_count += 1 | .last_completed = $ts' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    # Add to global history
    jq --arg name "$checklist_name" --arg ts "$timestamp" '
        .completions += [{
            checklist: $name,
            completed_at: $ts
        }]
    ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Copy checklist
copy_checklist() {
    local source="$1"
    local dest="$2"

    if [[ -z "$source" ]] || [[ -z "$dest" ]]; then
        echo "Usage: checklist.sh copy \"source\" \"destination\""
        exit 1
    fi

    local source_file=$(find_checklist "$source")

    if [[ -z "$source_file" ]] || [[ ! -f "$source_file" ]]; then
        echo -e "${RED}Source checklist '$source' not found${NC}"
        exit 1
    fi

    local dest_file=$(get_checklist_file "$dest")

    if [[ -f "$dest_file" ]]; then
        echo -e "${RED}Destination checklist '$dest' already exists${NC}"
        exit 1
    fi

    local created=$(date '+%Y-%m-%d %H:%M:%S')

    jq --arg name "$dest" --arg created "$created" '
        .name = $name |
        .created = $created |
        .items = [.items[] | .checked = false] |
        .completion_count = 0 |
        .last_completed = null
    ' "$source_file" > "$dest_file"

    echo -e "${GREEN}Created:${NC} $dest (copied from $(jq -r '.name' "$source_file"))"
}

# Delete checklist
delete_checklist() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh delete \"checklist\""
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local checklist_name=$(jq -r '.name' "$file")

    read -p "Delete '$checklist_name'? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    rm "$file"
    echo -e "${RED}Deleted:${NC} $checklist_name"
}

# Show completion history
show_history() {
    local name="$1"

    if [[ -n "$name" ]]; then
        local file=$(find_checklist "$name")
        if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
            echo -e "${RED}Checklist '$name' not found${NC}"
            exit 1
        fi

        local checklist_name=$(jq -r '.name' "$file")
        echo -e "${BLUE}=== History: $checklist_name ===${NC}"
        echo ""

        jq -r --arg name "$checklist_name" '
            .completions | map(select(.checklist == $name)) | reverse | .[0:20] | .[] |
            "  \(.completed_at)"
        ' "$HISTORY_FILE"

        local count=$(jq -r --arg name "$checklist_name" '[.completions[] | select(.checklist == $name)] | length' "$HISTORY_FILE")
        echo ""
        echo -e "${GRAY}Total completions: $count${NC}"
    else
        echo -e "${BLUE}=== Recent Completions ===${NC}"
        echo ""

        jq -r '.completions | reverse | .[0:20] | .[] | "  \(.completed_at) - \(.checklist)"' "$HISTORY_FILE"
    fi
}

# Export to markdown
export_checklist() {
    local name="$1"
    local output="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: checklist.sh export \"checklist\" [output.md]"
        exit 1
    fi

    local file=$(find_checklist "$name")

    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' not found${NC}"
        exit 1
    fi

    local markdown=$(jq -r '
        "# " + .name + "\n\n" +
        (if .description != "" and .description != null then .description + "\n\n" else "" end) +
        (.items | map("- [ ] " + .text) | join("\n"))
    ' "$file")

    if [[ -n "$output" ]]; then
        echo "$markdown" > "$output"
        echo -e "${GREEN}Exported to:${NC} $output"
    else
        echo "$markdown"
    fi
}

# Import from markdown
import_checklist() {
    local input="$1"

    if [[ -z "$input" ]]; then
        echo "Usage: checklist.sh import <file.md>"
        exit 1
    fi

    if [[ ! -f "$input" ]]; then
        echo -e "${RED}File not found:${NC} $input"
        exit 1
    fi

    # Parse markdown
    local name=$(head -1 "$input" | sed 's/^#* *//')

    if [[ -z "$name" ]]; then
        echo -e "${RED}Could not parse checklist name from file${NC}"
        exit 1
    fi

    local file=$(get_checklist_file "$name")

    if [[ -f "$file" ]]; then
        echo -e "${YELLOW}Checklist '$name' already exists${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    local created=$(date '+%Y-%m-%d %H:%M:%S')

    # Extract items (lines starting with - [ ] or - [x])
    local items_json="[]"
    while IFS= read -r line; do
        if [[ "$line" =~ ^-[[:space:]]*\[[[:space:]xX]?\][[:space:]]*(.*) ]]; then
            local item_text="${BASH_REMATCH[1]}"
            items_json=$(echo "$items_json" | jq --arg t "$item_text" '. + [{text: $t, checked: false}]')
        fi
    done < "$input"

    jq -n --arg name "$name" --arg created "$created" --argjson items "$items_json" '{
        name: $name,
        description: "",
        created: $created,
        items: $items,
        completion_count: 0,
        last_completed: null
    }' > "$file"

    local count=$(echo "$items_json" | jq 'length')
    echo -e "${GREEN}Imported:${NC} $name ($count items)"
}

# Show built-in templates
show_templates() {
    echo -e "${BLUE}${BOLD}=== Built-in Templates ===${NC}"
    echo ""
    echo -e "  ${CYAN}code-review${NC}"
    echo -e "    ${GRAY}Standard code review checklist${NC}"
    echo ""
    echo -e "  ${CYAN}deployment${NC}"
    echo -e "    ${GRAY}Pre-deployment verification checklist${NC}"
    echo ""
    echo -e "  ${CYAN}pr-checklist${NC}"
    echo -e "    ${GRAY}Pull request submission checklist${NC}"
    echo ""
    echo -e "  ${CYAN}morning-routine${NC}"
    echo -e "    ${GRAY}Daily morning startup routine${NC}"
    echo ""
    echo -e "  ${CYAN}project-setup${NC}"
    echo -e "    ${GRAY}New project initialization checklist${NC}"
    echo ""
    echo -e "  ${CYAN}meeting-prep${NC}"
    echo -e "    ${GRAY}Meeting preparation checklist${NC}"
    echo ""
    echo "Use with: checklist.sh use-template <template-name>"
}

# Create from built-in template
use_template() {
    local template="$1"
    local custom_name="$2"

    if [[ -z "$template" ]]; then
        echo "Usage: checklist.sh use-template <template-name> [custom-name]"
        show_templates
        exit 1
    fi

    local name="${custom_name:-$template}"
    local file=$(get_checklist_file "$name")

    if [[ -f "$file" ]]; then
        echo -e "${RED}Checklist '$name' already exists${NC}"
        exit 1
    fi

    local created=$(date '+%Y-%m-%d %H:%M:%S')
    local items_json=""
    local description=""

    case "$template" in
        code-review)
            description="Standard code review checklist"
            items_json='[
                {"text": "Code compiles without errors", "checked": false},
                {"text": "All tests pass", "checked": false},
                {"text": "No hardcoded secrets or credentials", "checked": false},
                {"text": "Error handling is appropriate", "checked": false},
                {"text": "Code follows style guidelines", "checked": false},
                {"text": "No obvious security vulnerabilities", "checked": false},
                {"text": "Documentation updated if needed", "checked": false},
                {"text": "No unnecessary console.log/print statements", "checked": false},
                {"text": "Edge cases considered", "checked": false},
                {"text": "Performance impact reviewed", "checked": false}
            ]'
            ;;
        deployment)
            description="Pre-deployment verification checklist"
            items_json='[
                {"text": "All tests passing in CI", "checked": false},
                {"text": "Code reviewed and approved", "checked": false},
                {"text": "Database migrations ready", "checked": false},
                {"text": "Environment variables configured", "checked": false},
                {"text": "Rollback plan prepared", "checked": false},
                {"text": "Monitoring/alerts configured", "checked": false},
                {"text": "Stakeholders notified", "checked": false},
                {"text": "Deployment window confirmed", "checked": false},
                {"text": "Post-deployment verification steps ready", "checked": false}
            ]'
            ;;
        pr-checklist)
            description="Pull request submission checklist"
            items_json='[
                {"text": "Branch is up to date with base", "checked": false},
                {"text": "Self-reviewed the diff", "checked": false},
                {"text": "Tests added/updated", "checked": false},
                {"text": "Documentation updated", "checked": false},
                {"text": "Commit messages are clear", "checked": false},
                {"text": "PR description explains the why", "checked": false},
                {"text": "Screenshots added if UI changes", "checked": false},
                {"text": "Linked to issue/ticket", "checked": false}
            ]'
            ;;
        morning-routine)
            description="Daily morning startup routine"
            items_json='[
                {"text": "Check calendar for today", "checked": false},
                {"text": "Review priority tasks", "checked": false},
                {"text": "Check and process email", "checked": false},
                {"text": "Review Slack/Teams messages", "checked": false},
                {"text": "Update task status", "checked": false},
                {"text": "Identify top 3 priorities for today", "checked": false},
                {"text": "Block focus time if needed", "checked": false}
            ]'
            ;;
        project-setup)
            description="New project initialization checklist"
            items_json='[
                {"text": "Create repository", "checked": false},
                {"text": "Initialize with appropriate template", "checked": false},
                {"text": "Set up README", "checked": false},
                {"text": "Configure linting/formatting", "checked": false},
                {"text": "Set up CI/CD pipeline", "checked": false},
                {"text": "Configure environment variables", "checked": false},
                {"text": "Set up development environment docs", "checked": false},
                {"text": "Add .gitignore", "checked": false},
                {"text": "Configure issue templates", "checked": false},
                {"text": "Set up branch protection rules", "checked": false}
            ]'
            ;;
        meeting-prep)
            description="Meeting preparation checklist"
            items_json='[
                {"text": "Review meeting agenda", "checked": false},
                {"text": "Prepare talking points", "checked": false},
                {"text": "Gather relevant documents/data", "checked": false},
                {"text": "Test audio/video if remote", "checked": false},
                {"text": "Prepare questions to ask", "checked": false},
                {"text": "Block time for follow-up actions", "checked": false}
            ]'
            ;;
        *)
            echo -e "${RED}Unknown template:${NC} $template"
            echo ""
            show_templates
            exit 1
            ;;
    esac

    jq -n --arg name "$name" --arg desc "$description" --arg created "$created" --argjson items "$items_json" '{
        name: $name,
        description: $desc,
        created: $created,
        items: $items,
        completion_count: 0,
        last_completed: null
    }' > "$file"

    local count=$(echo "$items_json" | jq 'length')
    echo -e "${GREEN}Created from template:${NC} $name ($count items)"
    echo ""
    echo "Run with: checklist.sh run \"$name\""
}

# Show help
show_help() {
    echo "Checklist - Reusable checklist manager for workflows"
    echo ""
    echo "Usage:"
    echo "  checklist.sh new \"name\" [-d \"desc\"]    Create a new checklist"
    echo "  checklist.sh add \"name\" \"item\"         Add item to checklist"
    echo "  checklist.sh remove \"name\" <n>         Remove item #n"
    echo "  checklist.sh check \"name\" <n>          Toggle check on item #n"
    echo "  checklist.sh show \"name\"               Show checklist status"
    echo "  checklist.sh reset \"name\"              Uncheck all items"
    echo "  checklist.sh list                      List all checklists"
    echo "  checklist.sh run \"name\"                Interactive walkthrough"
    echo "  checklist.sh copy \"src\" \"dest\"         Copy as new checklist"
    echo "  checklist.sh delete \"name\"             Delete a checklist"
    echo "  checklist.sh history [name]            Show completion history"
    echo "  checklist.sh export \"name\" [file]      Export to markdown"
    echo "  checklist.sh import <file>             Import from markdown"
    echo "  checklist.sh templates                 Show built-in templates"
    echo "  checklist.sh use-template <name>       Create from template"
    echo "  checklist.sh help                      Show this help"
    echo ""
    echo "Examples:"
    echo "  checklist.sh new \"Code Review\" -d \"Standard review process\""
    echo "  checklist.sh add \"Code Review\" \"Tests pass\""
    echo "  checklist.sh run \"Code Review\""
    echo "  checklist.sh use-template deployment"
    echo "  checklist.sh check \"Code Review\" 1"
    echo "  checklist.sh reset \"Code Review\""
}

# Main command handler
case "$1" in
    new|create)
        shift
        create_checklist "$@"
        ;;
    add)
        add_item "$2" "$3"
        ;;
    remove|rm)
        remove_item "$2" "$3"
        ;;
    check|toggle|x)
        check_item "$2" "$3"
        ;;
    show|view)
        show_checklist "$2"
        ;;
    reset|clear)
        reset_checklist "$2"
        ;;
    list|ls)
        list_checklists
        ;;
    run|start)
        run_checklist "$2"
        ;;
    copy|clone|duplicate)
        copy_checklist "$2" "$3"
        ;;
    delete|del)
        delete_checklist "$2"
        ;;
    history|hist)
        show_history "$2"
        ;;
    export)
        export_checklist "$2" "$3"
        ;;
    import)
        import_checklist "$2"
        ;;
    templates|template)
        show_templates
        ;;
    use-template|from-template)
        use_template "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_checklists
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'checklist.sh help' for usage"
        exit 1
        ;;
esac
