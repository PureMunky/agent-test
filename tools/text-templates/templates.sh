#!/bin/bash
#
# Text Templates - Reusable text templates with variable substitution
#
# A tool for managing and using text templates for emails, documentation,
# commit messages, and any other repetitive text with customizable placeholders.
#
# Usage:
#   templates.sh new <name>                    Create a new template
#   templates.sh edit <name>                   Edit an existing template
#   templates.sh use <name> [var=value ...]    Generate text from template
#   templates.sh list                          List all templates
#   templates.sh show <name>                   Show template content
#   templates.sh delete <name>                 Delete a template
#   templates.sh vars <name>                   Show variables in a template
#   templates.sh copy <name>                   Copy generated text to clipboard
#   templates.sh search <term>                 Search templates by name/content
#   templates.sh export <name> [file]          Export template to file
#   templates.sh import <file> [name]          Import template from file
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TEMPLATES_DIR="$DATA_DIR/templates"
INDEX_FILE="$DATA_DIR/index.json"

mkdir -p "$TEMPLATES_DIR"

# Initialize index file if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"templates":[]}' > "$INDEX_FILE"
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
    echo -e "${RED}Error: jq is required. Install with: sudo apt install jq${NC}"
    exit 1
fi

# Get template file path
template_path() {
    local name="$1"
    echo "$TEMPLATES_DIR/${name}.tpl"
}

# Sanitize template name
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Extract variables from template (format: {{variable_name}} or {{variable_name:default}})
extract_vars() {
    local template_file="$1"
    grep -oE '\{\{[a-zA-Z_][a-zA-Z0-9_]*(:[^}]*)?\}\}' "$template_file" 2>/dev/null | \
        sed 's/{{//' | sed 's/}}//' | cut -d: -f1 | sort -u
}

# Create new template
new_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo -e "${YELLOW}Enter template name:${NC}"
        read -r name
    fi

    name=$(sanitize_name "$name")

    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Template name cannot be empty${NC}"
        exit 1
    fi

    local tpl_file=$(template_path "$name")

    if [[ -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' already exists${NC}"
        echo "Use 'templates.sh edit $name' to modify it"
        exit 1
    fi

    # Ask for description
    echo -e "${YELLOW}Enter description (optional):${NC}"
    read -r description

    # Ask for category
    echo -e "${YELLOW}Enter category (email/code/docs/commit/other):${NC}"
    read -r category
    category=${category:-other}

    # Create template file with example
    cat > "$tpl_file" << 'EOF'
# Template: {{_name_}}
# Use variables with {{variable_name}} or {{variable_name:default_value}}
#
# Example variables:
#   {{name}}           - Required variable
#   {{date:today}}     - Variable with default
#   {{greeting:Hello}} - Variable with default
#
# Delete these comments and write your template below:

EOF

    # Open in editor
    local editor="${EDITOR:-nano}"
    if command -v "$editor" &> /dev/null; then
        "$editor" "$tpl_file"
    else
        echo -e "${YELLOW}No editor found. Template created at: $tpl_file${NC}"
        echo "Edit it manually and then run the command again."
    fi

    # Check if template has content (more than just comments)
    local content_lines=$(grep -v '^#' "$tpl_file" | grep -v '^$' | wc -l)

    if [[ $content_lines -eq 0 ]]; then
        echo -e "${YELLOW}Template is empty. Keeping file for later editing.${NC}"
    fi

    # Add to index
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    jq --arg name "$name" --arg desc "$description" --arg cat "$category" --arg ts "$timestamp" '
        .templates += [{
            "name": $name,
            "description": $desc,
            "category": $cat,
            "created": $ts,
            "modified": $ts,
            "uses": 0
        }]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Template '$name' created${NC}"

    # Show variables
    local vars=$(extract_vars "$tpl_file")
    if [[ -n "$vars" ]]; then
        echo -e "${CYAN}Variables found:${NC}"
        echo "$vars" | while read var; do
            echo "  - $var"
        done
    fi
}

# Edit existing template
edit_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh edit <name>"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        list_templates
        exit 1
    fi

    local editor="${EDITOR:-nano}"
    if command -v "$editor" &> /dev/null; then
        "$editor" "$tpl_file"

        # Update modified timestamp
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        jq --arg name "$name" --arg ts "$timestamp" '
            .templates = [.templates[] | if .name == $name then .modified = $ts else . end]
        ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

        echo -e "${GREEN}Template '$name' updated${NC}"
    else
        echo -e "${YELLOW}No editor found. Edit manually: $tpl_file${NC}"
    fi
}

# Use template with variable substitution
use_template() {
    local name="$1"
    shift

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh use <name> [var=value ...]"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        list_templates
        exit 1
    fi

    # Get template content (skip comment lines starting with #)
    local content=$(grep -v '^#' "$tpl_file")

    # Parse provided variables
    declare -A vars
    for arg in "$@"; do
        if [[ "$arg" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
            vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        fi
    done

    # Add built-in variables
    vars["_date_"]=$(date '+%Y-%m-%d')
    vars["_time_"]=$(date '+%H:%M')
    vars["_datetime_"]=$(date '+%Y-%m-%d %H:%M')
    vars["_year_"]=$(date '+%Y')
    vars["_month_"]=$(date '+%m')
    vars["_day_"]=$(date '+%d')
    vars["_user_"]="${USER:-unknown}"
    vars["_name_"]="$name"

    # Find all variables in template
    local template_vars=$(echo "$content" | grep -oE '\{\{[a-zA-Z_][a-zA-Z0-9_]*(:[^}]*)?\}\}' | sort -u)

    # Check for missing required variables and prompt for them
    local missing_vars=()
    for var_match in $template_vars; do
        local var_name=$(echo "$var_match" | sed 's/{{//' | sed 's/}}//' | cut -d: -f1)
        local default_val=$(echo "$var_match" | sed 's/{{//' | sed 's/}}//' | grep ':' | cut -d: -f2-)

        # Skip built-in variables
        if [[ "$var_name" =~ ^_ ]]; then
            continue
        fi

        if [[ -z "${vars[$var_name]}" ]] && [[ -z "$default_val" ]]; then
            missing_vars+=("$var_name")
        fi
    done

    # Prompt for missing variables
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Please provide values for the following variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -ne "${CYAN}$var: ${NC}"
            read -r value
            vars["$var"]="$value"
        done
        echo ""
    fi

    # Perform substitution
    local result="$content"

    # First, substitute variables with provided values
    for var_name in "${!vars[@]}"; do
        local var_value="${vars[$var_name]}"
        # Escape special characters for sed
        var_value=$(echo "$var_value" | sed 's/[&/\]/\\&/g')
        # Replace {{var}} and {{var:default}}
        result=$(echo "$result" | sed "s/{{${var_name}\(:[^}]*\)\?}}/${var_value}/g")
    done

    # Then, apply defaults for remaining variables
    result=$(echo "$result" | sed 's/{{\([a-zA-Z_][a-zA-Z0-9_]*\):\([^}]*\)}}/\2/g')

    # Check for any remaining unsubstituted variables
    local remaining=$(echo "$result" | grep -oE '\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}' | head -1)
    if [[ -n "$remaining" ]]; then
        echo -e "${RED}Warning: Unsubstituted variable found: $remaining${NC}" >&2
    fi

    # Update usage count
    jq --arg name "$name" '
        .templates = [.templates[] | if .name == $name then .uses = (.uses + 1) else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    # Output result
    echo "$result"
}

# List all templates
list_templates() {
    echo -e "${BLUE}=== Text Templates ===${NC}"
    echo ""

    local count=$(jq '.templates | length' "$INDEX_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No templates yet."
        echo "Create one with: templates.sh new <name>"
        exit 0
    fi

    # Group by category
    local categories=$(jq -r '.templates[].category' "$INDEX_FILE" | sort -u)

    for cat in $categories; do
        echo -e "${YELLOW}[$cat]${NC}"
        jq -r --arg cat "$cat" '.templates[] | select(.category == $cat) | "  \(.name) - \(.description // "No description") (used: \(.uses)x)"' "$INDEX_FILE"
        echo ""
    done

    echo -e "${GRAY}Total: $count template(s)${NC}"
}

# Show template content
show_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh show <name>"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        exit 1
    fi

    # Get metadata
    local info=$(jq -r --arg name "$name" '.templates[] | select(.name == $name) | "Category: \(.category)\nCreated: \(.created)\nModified: \(.modified)\nUses: \(.uses)"' "$INDEX_FILE")

    echo -e "${BLUE}=== Template: $name ===${NC}"
    echo -e "${GRAY}$info${NC}"
    echo ""
    echo -e "${YELLOW}Content:${NC}"
    echo "----------------------------------------"
    cat "$tpl_file"
    echo "----------------------------------------"

    # Show variables
    local vars=$(extract_vars "$tpl_file")
    if [[ -n "$vars" ]]; then
        echo ""
        echo -e "${CYAN}Variables:${NC}"
        echo "$vars" | while read var; do
            # Check if it has a default
            local default=$(grep -oE "\{\{${var}:[^}]*\}\}" "$tpl_file" | head -1 | sed 's/{{[^:]*://' | sed 's/}}//')
            if [[ -n "$default" ]]; then
                echo "  - $var (default: $default)"
            else
                echo "  - $var (required)"
            fi
        done
    fi
}

# Show variables in a template
show_vars() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh vars <name>"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}Variables in template '$name':${NC}"
    echo ""

    local vars=$(extract_vars "$tpl_file")

    if [[ -z "$vars" ]]; then
        echo "No variables found in this template."
        exit 0
    fi

    echo -e "${YELLOW}Custom Variables:${NC}"
    echo "$vars" | while read var; do
        if [[ ! "$var" =~ ^_ ]]; then
            local default=$(grep -oE "\{\{${var}:[^}]*\}\}" "$tpl_file" | head -1 | sed 's/{{[^:]*://' | sed 's/}}//')
            if [[ -n "$default" ]]; then
                echo "  {{$var}} - default: '$default'"
            else
                echo "  {{$var}} - required"
            fi
        fi
    done

    echo ""
    echo -e "${YELLOW}Built-in Variables:${NC}"
    echo "  {{_date_}}     - Current date (YYYY-MM-DD)"
    echo "  {{_time_}}     - Current time (HH:MM)"
    echo "  {{_datetime_}} - Current date and time"
    echo "  {{_year_}}     - Current year"
    echo "  {{_month_}}    - Current month"
    echo "  {{_day_}}      - Current day"
    echo "  {{_user_}}     - Current username"
    echo "  {{_name_}}     - Template name"
}

# Delete template
delete_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh delete <name>"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Are you sure you want to delete template '$name'? (y/N)${NC}"
    read -r -n 1 confirm
    echo ""

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm "$tpl_file"
        jq --arg name "$name" '.templates = [.templates[] | select(.name != $name)]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
        echo -e "${GREEN}Template '$name' deleted${NC}"
    else
        echo "Cancelled."
    fi
}

# Copy generated template to clipboard
copy_template() {
    local name="$1"
    shift

    local result=$(use_template "$name" "$@")

    if [[ -n "$result" ]]; then
        if command -v xclip &> /dev/null; then
            echo "$result" | xclip -selection clipboard
            echo -e "${GREEN}Copied to clipboard!${NC}"
        elif command -v xsel &> /dev/null; then
            echo "$result" | xsel --clipboard --input
            echo -e "${GREEN}Copied to clipboard!${NC}"
        elif command -v pbcopy &> /dev/null; then
            echo "$result" | pbcopy
            echo -e "${GREEN}Copied to clipboard!${NC}"
        else
            echo -e "${YELLOW}No clipboard tool found. Output:${NC}"
            echo "$result"
        fi
    fi
}

# Search templates
search_templates() {
    local term="$1"

    if [[ -z "$term" ]]; then
        echo "Usage: templates.sh search <term>"
        exit 1
    fi

    echo -e "${BLUE}=== Search Results for '$term' ===${NC}"
    echo ""

    local found=0

    # Search in names and descriptions
    local name_matches=$(jq -r --arg term "$term" '.templates[] | select(.name | test($term; "i")) | .name' "$INDEX_FILE")
    local desc_matches=$(jq -r --arg term "$term" '.templates[] | select(.description | test($term; "i")) | .name' "$INDEX_FILE")

    # Search in template content
    local content_matches=""
    for tpl_file in "$TEMPLATES_DIR"/*.tpl; do
        if [[ -f "$tpl_file" ]]; then
            if grep -qi "$term" "$tpl_file"; then
                local tpl_name=$(basename "$tpl_file" .tpl)
                content_matches="$content_matches $tpl_name"
            fi
        fi
    done

    # Combine and deduplicate
    local all_matches=$(echo "$name_matches $desc_matches $content_matches" | tr ' ' '\n' | sort -u | grep -v '^$')

    if [[ -z "$all_matches" ]]; then
        echo "No templates found matching '$term'"
        exit 0
    fi

    for name in $all_matches; do
        local info=$(jq -r --arg name "$name" '.templates[] | select(.name == $name) | "\(.name) [\(.category)] - \(.description // "No description")"' "$INDEX_FILE")
        echo -e "  ${GREEN}$info${NC}"
        ((found++))
    done

    echo ""
    echo -e "${GRAY}Found: $found template(s)${NC}"
}

# Export template
export_template() {
    local name="$1"
    local outfile="$2"

    if [[ -z "$name" ]]; then
        echo "Usage: templates.sh export <name> [file]"
        exit 1
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ ! -f "$tpl_file" ]]; then
        echo -e "${RED}Error: Template '$name' not found${NC}"
        exit 1
    fi

    outfile=${outfile:-"${name}.tpl"}

    # Export with metadata header
    local meta=$(jq --arg name "$name" '.templates[] | select(.name == $name)' "$INDEX_FILE")

    {
        echo "# Exported from text-templates"
        echo "# Name: $name"
        echo "# Category: $(echo "$meta" | jq -r '.category')"
        echo "# Description: $(echo "$meta" | jq -r '.description')"
        echo "# Exported: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "#"
        cat "$tpl_file"
    } > "$outfile"

    echo -e "${GREEN}Exported to: $outfile${NC}"
}

# Import template
import_template() {
    local infile="$1"
    local name="$2"

    if [[ -z "$infile" ]]; then
        echo "Usage: templates.sh import <file> [name]"
        exit 1
    fi

    if [[ ! -f "$infile" ]]; then
        echo -e "${RED}Error: File '$infile' not found${NC}"
        exit 1
    fi

    # Try to extract name from file header or filename
    if [[ -z "$name" ]]; then
        name=$(grep '^# Name:' "$infile" | head -1 | sed 's/^# Name: *//')
        if [[ -z "$name" ]]; then
            name=$(basename "$infile" .tpl)
        fi
    fi

    name=$(sanitize_name "$name")
    local tpl_file=$(template_path "$name")

    if [[ -f "$tpl_file" ]]; then
        echo -e "${YELLOW}Template '$name' already exists. Overwrite? (y/N)${NC}"
        read -r -n 1 confirm
        echo ""
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    # Extract metadata from header if present
    local category=$(grep '^# Category:' "$infile" | head -1 | sed 's/^# Category: *//')
    local description=$(grep '^# Description:' "$infile" | head -1 | sed 's/^# Description: *//')
    category=${category:-other}
    description=${description:-"Imported template"}

    # Copy content (skip export header lines)
    grep -v '^# Exported from text-templates' "$infile" | \
    grep -v '^# Name:' | \
    grep -v '^# Category:' | \
    grep -v '^# Description:' | \
    grep -v '^# Exported:' > "$tpl_file"

    # Add to index
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Remove existing entry if overwriting
    jq --arg name "$name" '.templates = [.templates[] | select(.name != $name)]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    jq --arg name "$name" --arg desc "$description" --arg cat "$category" --arg ts "$timestamp" '
        .templates += [{
            "name": $name,
            "description": $desc,
            "category": $cat,
            "created": $ts,
            "modified": $ts,
            "uses": 0
        }]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Imported template '$name'${NC}"
}

# Show help
show_help() {
    echo "Text Templates - Reusable text with variable substitution"
    echo ""
    echo "Usage:"
    echo "  templates.sh new <name>              Create a new template"
    echo "  templates.sh edit <name>             Edit an existing template"
    echo "  templates.sh use <name> [var=val]    Generate text from template"
    echo "  templates.sh list                    List all templates"
    echo "  templates.sh show <name>             Show template content"
    echo "  templates.sh delete <name>           Delete a template"
    echo "  templates.sh vars <name>             Show template variables"
    echo "  templates.sh copy <name> [var=val]   Copy generated text to clipboard"
    echo "  templates.sh search <term>           Search templates"
    echo "  templates.sh export <name> [file]    Export template to file"
    echo "  templates.sh import <file> [name]    Import template from file"
    echo "  templates.sh help                    Show this help"
    echo ""
    echo "Variable Syntax:"
    echo "  {{variable}}          Required variable"
    echo "  {{variable:default}}  Variable with default value"
    echo ""
    echo "Built-in Variables:"
    echo "  {{_date_}}            Current date (YYYY-MM-DD)"
    echo "  {{_time_}}            Current time (HH:MM)"
    echo "  {{_datetime_}}        Current date and time"
    echo "  {{_user_}}            Current username"
    echo ""
    echo "Examples:"
    echo "  templates.sh new email-reply"
    echo "  templates.sh use email-reply name=\"John\" topic=\"meeting\""
    echo "  templates.sh copy commit-msg type=\"feat\" scope=\"auth\""
}

# Main
case "$1" in
    new|create|add)
        new_template "$2"
        ;;
    edit|modify)
        edit_template "$2"
        ;;
    use|gen|generate|fill)
        shift
        use_template "$@"
        ;;
    list|ls)
        list_templates
        ;;
    show|view|cat)
        show_template "$2"
        ;;
    delete|rm|remove)
        delete_template "$2"
        ;;
    vars|variables)
        show_vars "$2"
        ;;
    copy|cp|clip)
        shift
        copy_template "$@"
        ;;
    search|find)
        search_templates "$2"
        ;;
    export)
        export_template "$2" "$3"
        ;;
    import)
        import_template "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_templates
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'templates.sh help' for usage"
        exit 1
        ;;
esac
