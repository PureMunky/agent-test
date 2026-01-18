#!/bin/bash
#
# Snippets - Command and code snippet manager
#
# Usage:
#   snippets.sh add "name" "content" [-t tags]  - Save a new snippet
#   snippets.sh get "name"                      - Get snippet content (copies to clipboard)
#   snippets.sh run "name"                      - Execute snippet as command
#   snippets.sh list [tag]                      - List all snippets or filter by tag
#   snippets.sh search "query"                  - Search snippets by name/content/tags
#   snippets.sh edit "name"                     - Edit snippet in editor
#   snippets.sh remove "name"                   - Delete a snippet
#   snippets.sh tags                            - List all tags
#   snippets.sh export [file]                   - Export snippets to JSON
#   snippets.sh import <file>                   - Import snippets from JSON
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
SNIPPETS_FILE="$DATA_DIR/snippets.json"

mkdir -p "$DATA_DIR"

# Initialize snippets file if it doesn't exist
if [[ ! -f "$SNIPPETS_FILE" ]]; then
    echo '{"snippets":[]}' > "$SNIPPETS_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

copy_to_clipboard() {
    local content="$1"

    # Try various clipboard commands
    if command -v xclip &> /dev/null; then
        echo -n "$content" | xclip -selection clipboard
        return 0
    elif command -v xsel &> /dev/null; then
        echo -n "$content" | xsel --clipboard --input
        return 0
    elif command -v pbcopy &> /dev/null; then
        echo -n "$content" | pbcopy
        return 0
    elif command -v wl-copy &> /dev/null; then
        echo -n "$content" | wl-copy
        return 0
    fi

    return 1
}

add_snippet() {
    local name=""
    local content=""
    local tags=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--tags)
                tags="$2"
                shift 2
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                elif [[ -z "$content" ]]; then
                    content="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh add \"name\" \"content\" [-t \"tag1,tag2\"]"
        exit 1
    fi

    # If no content provided, read from stdin or prompt
    if [[ -z "$content" ]]; then
        if [[ ! -t 0 ]]; then
            # Read from stdin (piped input)
            content=$(cat)
        else
            echo "Enter snippet content (Ctrl+D when done):"
            content=$(cat)
        fi
    fi

    if [[ -z "$content" ]]; then
        echo -e "${RED}Error: No content provided${NC}"
        exit 1
    fi

    # Check if snippet already exists
    local exists=$(jq -r --arg name "$name" '.snippets | map(select(.name == $name)) | length' "$SNIPPETS_FILE")

    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Snippet '$name' already exists.${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
        # Remove existing snippet
        jq --arg name "$name" '.snippets = [.snippets[] | select(.name != $name)]' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Convert tags string to array
    local tags_json="[]"
    if [[ -n "$tags" ]]; then
        tags_json=$(echo "$tags" | tr ',' '\n' | jq -R . | jq -s .)
    fi

    # Add the snippet
    jq --arg name "$name" \
       --arg content "$content" \
       --argjson tags "$tags_json" \
       --arg created "$timestamp" '
        .snippets += [{
            "name": $name,
            "content": $content,
            "tags": $tags,
            "created": $created,
            "last_used": null,
            "use_count": 0
        }]
    ' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    echo -e "${GREEN}Snippet added:${NC} $name"
    if [[ -n "$tags" ]]; then
        echo -e "${CYAN}Tags:${NC} $tags"
    fi
}

get_snippet() {
    local name="$1"
    local no_copy="${2:-false}"

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh get \"name\""
        exit 1
    fi

    # Find the snippet
    local content=$(jq -r --arg name "$name" '.snippets[] | select(.name == $name) | .content' "$SNIPPETS_FILE")

    if [[ -z "$content" || "$content" == "null" ]]; then
        echo -e "${RED}Snippet '$name' not found.${NC}"
        exit 1
    fi

    # Update usage stats
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    jq --arg name "$name" --arg ts "$timestamp" '
        .snippets = [.snippets[] |
            if .name == $name then
                .last_used = $ts | .use_count = (.use_count + 1)
            else
                .
            end
        ]
    ' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    # Output the content
    echo "$content"

    # Try to copy to clipboard
    if [[ "$no_copy" != "true" ]]; then
        if copy_to_clipboard "$content"; then
            echo -e "${GRAY}(copied to clipboard)${NC}" >&2
        fi
    fi
}

run_snippet() {
    local name="$1"
    shift
    local extra_args="$@"

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh run \"name\" [args...]"
        exit 1
    fi

    # Find the snippet
    local content=$(jq -r --arg name "$name" '.snippets[] | select(.name == $name) | .content' "$SNIPPETS_FILE")

    if [[ -z "$content" || "$content" == "null" ]]; then
        echo -e "${RED}Snippet '$name' not found.${NC}"
        exit 1
    fi

    # Update usage stats
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    jq --arg name "$name" --arg ts "$timestamp" '
        .snippets = [.snippets[] |
            if .name == $name then
                .last_used = $ts | .use_count = (.use_count + 1)
            else
                .
            end
        ]
    ' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    echo -e "${CYAN}Running:${NC} $content $extra_args"
    echo ""

    # Execute the command
    eval "$content $extra_args"
}

list_snippets() {
    local filter_tag="$1"

    local count=$(jq '.snippets | length' "$SNIPPETS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No snippets saved yet."
        echo "Add one with: snippets.sh add \"name\" \"content\""
        exit 0
    fi

    if [[ -n "$filter_tag" ]]; then
        echo -e "${BLUE}=== Snippets tagged '$filter_tag' ===${NC}"
    else
        echo -e "${BLUE}=== All Snippets ($count) ===${NC}"
    fi
    echo ""

    local query='.snippets | sort_by(.name)'
    if [[ -n "$filter_tag" ]]; then
        query=".snippets | map(select(.tags | index(\"$filter_tag\"))) | sort_by(.name)"
    fi

    jq -r "$query | .[] | \"\(.name)|\(.tags | join(\",\"))|\(.content | split(\"\n\")[0][:50])|\(.use_count)\"" "$SNIPPETS_FILE" | while IFS='|' read -r name tags preview use_count; do
        # Truncate preview if needed
        if [[ ${#preview} -ge 50 ]]; then
            preview="${preview}..."
        fi

        echo -e "${GREEN}$name${NC}"
        if [[ -n "$tags" ]]; then
            echo -e "  ${MAGENTA}[$tags]${NC}"
        fi
        echo -e "  ${GRAY}$preview${NC}"
        if [[ "$use_count" -gt 0 ]]; then
            echo -e "  ${CYAN}Used: $use_count times${NC}"
        fi
        echo ""
    done
}

search_snippets() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: snippets.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    local results=$(jq -r --arg q "$query_lower" '
        .snippets | map(
            select(
                (.name | ascii_downcase | contains($q)) or
                (.content | ascii_downcase | contains($q)) or
                (.tags | map(ascii_downcase) | any(contains($q)))
            )
        )
    ' "$SNIPPETS_FILE")

    local count=$(echo "$results" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo "No snippets found matching \"$query\""
        exit 0
    fi

    echo -e "${CYAN}Found $count result(s):${NC}"
    echo ""

    echo "$results" | jq -r '.[] | "\(.name)|\(.tags | join(","))|\(.content | split("\n")[0][:60])"' | while IFS='|' read -r name tags preview; do
        echo -e "${GREEN}$name${NC}"
        if [[ -n "$tags" ]]; then
            echo -e "  ${MAGENTA}[$tags]${NC}"
        fi
        echo -e "  ${GRAY}$preview${NC}"
        echo ""
    done
}

edit_snippet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh edit \"name\""
        exit 1
    fi

    # Check if snippet exists
    local exists=$(jq -r --arg name "$name" '.snippets | map(select(.name == $name)) | length' "$SNIPPETS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Snippet '$name' not found.${NC}"
        exit 1
    fi

    # Get current content
    local content=$(jq -r --arg name "$name" '.snippets[] | select(.name == $name) | .content' "$SNIPPETS_FILE")

    # Create temp file
    local tmpfile=$(mktemp)
    echo "$content" > "$tmpfile"

    # Open in editor
    local editor="${EDITOR:-nano}"
    $editor "$tmpfile"

    # Read new content
    local new_content=$(cat "$tmpfile")
    rm "$tmpfile"

    if [[ "$content" == "$new_content" ]]; then
        echo "No changes made."
        exit 0
    fi

    # Update snippet
    jq --arg name "$name" --arg content "$new_content" '
        .snippets = [.snippets[] |
            if .name == $name then
                .content = $content
            else
                .
            end
        ]
    ' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    echo -e "${GREEN}Snippet '$name' updated.${NC}"
}

remove_snippet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh remove \"name\""
        exit 1
    fi

    # Check if snippet exists
    local exists=$(jq -r --arg name "$name" '.snippets | map(select(.name == $name)) | length' "$SNIPPETS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Snippet '$name' not found.${NC}"
        exit 1
    fi

    jq --arg name "$name" '.snippets = [.snippets[] | select(.name != $name)]' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    echo -e "${GREEN}Removed snippet:${NC} $name"
}

list_tags() {
    echo -e "${BLUE}=== Tags ===${NC}"
    echo ""

    local tags=$(jq -r '.snippets | map(.tags) | flatten | unique | .[]' "$SNIPPETS_FILE" 2>/dev/null)

    if [[ -z "$tags" ]]; then
        echo "No tags yet."
        echo "Add tags when creating snippets: snippets.sh add \"name\" \"content\" -t \"tag1,tag2\""
        exit 0
    fi

    echo "$tags" | while read tag; do
        local count=$(jq -r --arg tag "$tag" '.snippets | map(select(.tags | index($tag))) | length' "$SNIPPETS_FILE")
        echo -e "  ${MAGENTA}$tag${NC} ($count snippets)"
    done
}

export_snippets() {
    local output_file="${1:-snippets_export.json}"

    # Get full path if relative
    if [[ ! "$output_file" = /* ]]; then
        output_file="$(pwd)/$output_file"
    fi

    jq '.' "$SNIPPETS_FILE" > "$output_file"

    echo -e "${GREEN}Exported to:${NC} $output_file"
}

import_snippets() {
    local input_file="$1"

    if [[ -z "$input_file" ]]; then
        echo "Usage: snippets.sh import <file>"
        exit 1
    fi

    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}File not found: $input_file${NC}"
        exit 1
    fi

    # Validate JSON
    if ! jq empty "$input_file" 2>/dev/null; then
        echo -e "${RED}Invalid JSON file${NC}"
        exit 1
    fi

    # Count snippets to import
    local import_count=$(jq '.snippets | length' "$input_file")

    if [[ "$import_count" -eq 0 ]]; then
        echo "No snippets to import."
        exit 0
    fi

    echo -e "${YELLOW}Import $import_count snippet(s)?${NC}"
    read -p "(y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Merge snippets (imported ones overwrite existing with same name)
    local existing=$(jq '.snippets | map(.name)' "$SNIPPETS_FILE")
    local imported=$(jq '.snippets' "$input_file")

    jq --argjson imported "$imported" '
        .snippets = (.snippets + $imported) |
        .snippets = (.snippets | group_by(.name) | map(last))
    ' "$SNIPPETS_FILE" > "$SNIPPETS_FILE.tmp" && mv "$SNIPPETS_FILE.tmp" "$SNIPPETS_FILE"

    echo -e "${GREEN}Imported $import_count snippet(s)${NC}"
}

show_snippet_detail() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: snippets.sh show \"name\""
        exit 1
    fi

    local snippet=$(jq --arg name "$name" '.snippets[] | select(.name == $name)' "$SNIPPETS_FILE")

    if [[ -z "$snippet" || "$snippet" == "null" ]]; then
        echo -e "${RED}Snippet '$name' not found.${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Snippet: $name ===${NC}"
    echo ""

    local tags=$(echo "$snippet" | jq -r '.tags | join(", ")')
    local created=$(echo "$snippet" | jq -r '.created')
    local last_used=$(echo "$snippet" | jq -r '.last_used // "never"')
    local use_count=$(echo "$snippet" | jq -r '.use_count')
    local content=$(echo "$snippet" | jq -r '.content')

    if [[ -n "$tags" && "$tags" != "null" ]]; then
        echo -e "${MAGENTA}Tags:${NC} $tags"
    fi
    echo -e "${CYAN}Created:${NC} $created"
    echo -e "${CYAN}Last used:${NC} $last_used"
    echo -e "${CYAN}Use count:${NC} $use_count"
    echo ""
    echo -e "${YELLOW}Content:${NC}"
    echo "----------------------------------------"
    echo "$content"
    echo "----------------------------------------"
}

show_help() {
    echo "Snippets - Command and code snippet manager"
    echo ""
    echo "Usage:"
    echo "  snippets.sh add \"name\" \"content\" [-t tags]  Save a new snippet"
    echo "  snippets.sh get \"name\"                       Get snippet (copies to clipboard)"
    echo "  snippets.sh run \"name\" [args]                Execute snippet as command"
    echo "  snippets.sh show \"name\"                      Show snippet details"
    echo "  snippets.sh list [tag]                       List snippets (optionally by tag)"
    echo "  snippets.sh search \"query\"                   Search snippets"
    echo "  snippets.sh edit \"name\"                      Edit snippet in editor"
    echo "  snippets.sh remove \"name\"                    Delete a snippet"
    echo "  snippets.sh tags                             List all tags"
    echo "  snippets.sh export [file]                    Export to JSON"
    echo "  snippets.sh import <file>                    Import from JSON"
    echo "  snippets.sh help                             Show this help"
    echo ""
    echo "Examples:"
    echo "  snippets.sh add \"git-log\" \"git log --oneline -10\" -t \"git,log\""
    echo "  snippets.sh add \"docker-ps\" \"docker ps -a --format 'table {{.Names}}\t{{.Status}}'\""
    echo "  snippets.sh run \"git-log\""
    echo "  snippets.sh get \"docker-ps\""
    echo "  snippets.sh list git"
    echo "  snippets.sh search docker"
    echo ""
    echo "Pipe content:"
    echo "  echo 'find . -name \"*.log\" -delete' | snippets.sh add \"clean-logs\" -t \"cleanup\""
    echo "  cat script.sh | snippets.sh add \"my-script\""
}

case "$1" in
    add|save|new)
        shift
        add_snippet "$@"
        ;;
    get|copy|cat)
        get_snippet "$2"
        ;;
    run|exec|execute)
        shift
        run_snippet "$@"
        ;;
    show|info|detail)
        show_snippet_detail "$2"
        ;;
    list|ls)
        list_snippets "$2"
        ;;
    search|find|grep)
        shift
        search_snippets "$@"
        ;;
    edit)
        edit_snippet "$2"
        ;;
    remove|rm|delete)
        remove_snippet "$2"
        ;;
    tags)
        list_tags
        ;;
    export)
        export_snippets "$2"
        ;;
    import)
        import_snippets "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_snippets
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'snippets.sh help' for usage"
        exit 1
        ;;
esac
