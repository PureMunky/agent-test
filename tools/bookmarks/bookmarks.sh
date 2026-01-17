#!/bin/bash
#
# Bookmarks - Command-line bookmark manager for URLs and resources
#
# Usage:
#   bookmarks.sh add <url> ["title"] [tags...]   - Add a bookmark
#   bookmarks.sh list [tag]                      - List bookmarks (optionally filter by tag)
#   bookmarks.sh search "query"                  - Search bookmarks
#   bookmarks.sh tags                            - List all tags
#   bookmarks.sh open <id>                       - Open bookmark in browser
#   bookmarks.sh remove <id>                     - Remove a bookmark
#   bookmarks.sh edit <id>                       - Edit bookmark details
#   bookmarks.sh export [file]                   - Export bookmarks to JSON
#   bookmarks.sh import <file>                   - Import bookmarks from JSON
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
BOOKMARKS_FILE="$DATA_DIR/bookmarks.json"

mkdir -p "$DATA_DIR"

# Initialize bookmarks file if it doesn't exist
if [[ ! -f "$BOOKMARKS_FILE" ]]; then
    echo '{"bookmarks":[],"next_id":1}' > "$BOOKMARKS_FILE"
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

# Validate URL format (basic check)
validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]] || [[ "$url" =~ ^file:// ]] || [[ "$url" =~ ^ftp:// ]]; then
        return 0
    fi
    return 1
}

# Extract domain from URL for display
get_domain() {
    local url="$1"
    echo "$url" | sed -E 's|^[^:]+://([^/]+).*|\1|'
}

add_bookmark() {
    local url="$1"
    shift
    local title=""
    local tags=()

    if [[ -z "$url" ]]; then
        echo "Usage: bookmarks.sh add <url> [\"title\"] [tags...]"
        echo ""
        echo "Examples:"
        echo "  bookmarks.sh add https://example.com"
        echo "  bookmarks.sh add https://docs.python.org \"Python Docs\" python docs reference"
        exit 1
    fi

    # Validate URL
    if ! validate_url "$url"; then
        echo -e "${YELLOW}Warning: URL doesn't start with http://, https://, file://, or ftp://${NC}"
        read -p "Add anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Check for duplicate URL
    local exists=$(jq -r --arg url "$url" '.bookmarks | map(select(.url == $url)) | length' "$BOOKMARKS_FILE")
    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Bookmark already exists for this URL.${NC}"
        local existing_id=$(jq -r --arg url "$url" '.bookmarks[] | select(.url == $url) | .id' "$BOOKMARKS_FILE")
        echo "Existing bookmark ID: $existing_id"
        exit 1
    fi

    # Parse remaining arguments - first quoted arg is title, rest are tags
    if [[ $# -gt 0 ]]; then
        title="$1"
        shift
        tags=("$@")
    fi

    # If no title provided, use domain as title
    if [[ -z "$title" ]]; then
        title=$(get_domain "$url")
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local next_id=$(jq -r '.next_id' "$BOOKMARKS_FILE")

    # Build tags JSON array
    local tags_json="[]"
    if [[ ${#tags[@]} -gt 0 ]]; then
        tags_json=$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)
    fi

    jq --arg url "$url" \
       --arg title "$title" \
       --argjson tags "$tags_json" \
       --arg ts "$timestamp" \
       --argjson id "$next_id" '
        .bookmarks += [{
            "id": $id,
            "url": $url,
            "title": $title,
            "tags": $tags,
            "created": $ts,
            "accessed": null,
            "access_count": 0
        }] |
        .next_id = ($id + 1)
    ' "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp" && mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

    echo -e "${GREEN}Bookmark #$next_id added:${NC}"
    echo -e "  ${CYAN}Title:${NC} $title"
    echo -e "  ${CYAN}URL:${NC} $url"
    if [[ ${#tags[@]} -gt 0 ]]; then
        echo -e "  ${CYAN}Tags:${NC} ${tags[*]}"
    fi
}

list_bookmarks() {
    local filter_tag="$1"

    local count=$(jq '.bookmarks | length' "$BOOKMARKS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No bookmarks yet."
        echo "Add one with: bookmarks.sh add <url> [\"title\"] [tags...]"
        exit 0
    fi

    if [[ -n "$filter_tag" ]]; then
        echo -e "${BLUE}=== Bookmarks tagged '$filter_tag' ===${NC}"
        local filtered=$(jq -r --arg tag "$filter_tag" '
            .bookmarks | map(select(.tags | index($tag))) | length
        ' "$BOOKMARKS_FILE")

        if [[ "$filtered" -eq 0 ]]; then
            echo ""
            echo "No bookmarks with tag '$filter_tag'"
            exit 0
        fi
    else
        echo -e "${BLUE}=== Bookmarks ($count) ===${NC}"
    fi

    echo ""

    local query='.bookmarks | sort_by(.created) | reverse'
    if [[ -n "$filter_tag" ]]; then
        query=".bookmarks | map(select(.tags | index(\"$filter_tag\"))) | sort_by(.created) | reverse"
    fi

    jq -r "$query | .[] | \"\(.id)|\(.title)|\(.url)|\(.tags | join(\",\"))\"" "$BOOKMARKS_FILE" | \
    while IFS='|' read -r id title url tags; do
        # Truncate title if too long
        local display_title="$title"
        if [[ ${#display_title} -gt 40 ]]; then
            display_title="${display_title:0:37}..."
        fi

        echo -e "  ${YELLOW}[$id]${NC} ${GREEN}$display_title${NC}"
        echo -e "      ${GRAY}$url${NC}"
        if [[ -n "$tags" ]]; then
            echo -e "      ${MAGENTA}#${tags//,/ #}${NC}"
        fi
        echo ""
    done
}

search_bookmarks() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: bookmarks.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    # Search in title, url, and tags (case insensitive)
    local results=$(jq -r --arg q "$query" '
        .bookmarks | map(select(
            (.title | ascii_downcase | contains($q | ascii_downcase)) or
            (.url | ascii_downcase | contains($q | ascii_downcase)) or
            (.tags | map(ascii_downcase) | any(contains($q | ascii_downcase)))
        )) | .[] | "\(.id)|\(.title)|\(.url)|\(.tags | join(","))"
    ' "$BOOKMARKS_FILE")

    if [[ -z "$results" ]]; then
        echo "No bookmarks found matching \"$query\""
        exit 0
    fi

    echo "$results" | while IFS='|' read -r id title url tags; do
        echo -e "  ${YELLOW}[$id]${NC} ${GREEN}$title${NC}"
        echo -e "      ${GRAY}$url${NC}"
        if [[ -n "$tags" ]]; then
            echo -e "      ${MAGENTA}#${tags//,/ #}${NC}"
        fi
        echo ""
    done
}

list_tags() {
    echo -e "${BLUE}=== Tags ===${NC}"
    echo ""

    local tags=$(jq -r '.bookmarks | map(.tags) | flatten | group_by(.) | map({tag: .[0], count: length}) | sort_by(.count) | reverse | .[] | "\(.tag)|\(.count)"' "$BOOKMARKS_FILE")

    if [[ -z "$tags" ]]; then
        echo "No tags yet."
        exit 0
    fi

    echo "$tags" | while IFS='|' read -r tag count; do
        if [[ -n "$tag" ]]; then
            printf "  ${MAGENTA}#%-20s${NC} ${GRAY}(%d bookmarks)${NC}\n" "$tag" "$count"
        fi
    done
}

open_bookmark() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: bookmarks.sh open <id>"
        exit 1
    fi

    # Check if bookmark exists
    local bookmark=$(jq -r --argjson id "$id" '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE")

    if [[ -z "$bookmark" ]]; then
        echo -e "${RED}Bookmark #$id not found${NC}"
        exit 1
    fi

    local url=$(echo "$bookmark" | jq -r '.url')
    local title=$(echo "$bookmark" | jq -r '.title')

    # Update access time and count
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    jq --argjson id "$id" --arg ts "$timestamp" '
        .bookmarks = [.bookmarks[] | if .id == $id then .accessed = $ts | .access_count += 1 else . end]
    ' "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp" && mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

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

remove_bookmark() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: bookmarks.sh remove <id>"
        exit 1
    fi

    # Check if bookmark exists
    local exists=$(jq --argjson id "$id" '.bookmarks | map(select(.id == $id)) | length' "$BOOKMARKS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Bookmark #$id not found${NC}"
        exit 1
    fi

    local title=$(jq -r --argjson id "$id" '.bookmarks[] | select(.id == $id) | .title' "$BOOKMARKS_FILE")

    jq --argjson id "$id" '.bookmarks = [.bookmarks[] | select(.id != $id)]' "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp" && mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

    echo -e "${RED}Removed:${NC} $title"
}

edit_bookmark() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: bookmarks.sh edit <id>"
        exit 1
    fi

    # Check if bookmark exists
    local bookmark=$(jq -r --argjson id "$id" '.bookmarks[] | select(.id == $id)' "$BOOKMARKS_FILE")

    if [[ -z "$bookmark" ]]; then
        echo -e "${RED}Bookmark #$id not found${NC}"
        exit 1
    fi

    local current_title=$(echo "$bookmark" | jq -r '.title')
    local current_url=$(echo "$bookmark" | jq -r '.url')
    local current_tags=$(echo "$bookmark" | jq -r '.tags | join(" ")')

    echo -e "${BLUE}=== Edit Bookmark #$id ===${NC}"
    echo ""
    echo "Press Enter to keep current value."
    echo ""

    read -p "Title [$current_title]: " new_title
    read -p "URL [$current_url]: " new_url
    read -p "Tags (space-separated) [$current_tags]: " new_tags

    # Use current values if empty
    new_title="${new_title:-$current_title}"
    new_url="${new_url:-$current_url}"
    new_tags="${new_tags:-$current_tags}"

    # Parse tags into array
    local tags_json="[]"
    if [[ -n "$new_tags" ]]; then
        tags_json=$(echo "$new_tags" | tr ' ' '\n' | jq -R . | jq -s .)
    fi

    jq --argjson id "$id" \
       --arg title "$new_title" \
       --arg url "$new_url" \
       --argjson tags "$tags_json" '
        .bookmarks = [.bookmarks[] | if .id == $id then .title = $title | .url = $url | .tags = $tags else . end]
    ' "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp" && mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

    echo ""
    echo -e "${GREEN}Bookmark #$id updated${NC}"
}

export_bookmarks() {
    local output_file="${1:-bookmarks_export.json}"

    local count=$(jq '.bookmarks | length' "$BOOKMARKS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No bookmarks to export."
        exit 0
    fi

    jq '.bookmarks' "$BOOKMARKS_FILE" > "$output_file"

    echo -e "${GREEN}Exported $count bookmarks to:${NC} $output_file"
}

import_bookmarks() {
    local input_file="$1"

    if [[ -z "$input_file" ]]; then
        echo "Usage: bookmarks.sh import <file>"
        exit 1
    fi

    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}File not found:${NC} $input_file"
        exit 1
    fi

    # Validate JSON
    if ! jq empty "$input_file" 2>/dev/null; then
        echo -e "${RED}Invalid JSON file${NC}"
        exit 1
    fi

    local import_count=$(jq 'length' "$input_file")
    echo "Found $import_count bookmarks to import."
    read -p "Continue? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    local added=0
    local skipped=0

    jq -c '.[]' "$input_file" | while read -r bookmark; do
        local url=$(echo "$bookmark" | jq -r '.url')
        local title=$(echo "$bookmark" | jq -r '.title // empty')
        local tags=$(echo "$bookmark" | jq -r '.tags // [] | join(" ")')

        # Check for duplicate
        local exists=$(jq -r --arg url "$url" '.bookmarks | map(select(.url == $url)) | length' "$BOOKMARKS_FILE")

        if [[ "$exists" -gt 0 ]]; then
            echo -e "${YELLOW}Skipped (duplicate):${NC} $url"
            continue
        fi

        # Add bookmark
        local next_id=$(jq -r '.next_id' "$BOOKMARKS_FILE")
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        local tags_json="[]"
        if [[ -n "$tags" ]]; then
            tags_json=$(echo "$tags" | tr ' ' '\n' | grep -v '^$' | jq -R . | jq -s .)
        fi

        jq --arg url "$url" \
           --arg title "${title:-$(get_domain "$url")}" \
           --argjson tags "$tags_json" \
           --arg ts "$timestamp" \
           --argjson id "$next_id" '
            .bookmarks += [{
                "id": $id,
                "url": $url,
                "title": $title,
                "tags": $tags,
                "created": $ts,
                "accessed": null,
                "access_count": 0
            }] |
            .next_id = ($id + 1)
        ' "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp" && mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

        echo -e "${GREEN}Imported:${NC} $title"
    done

    echo ""
    echo -e "${GREEN}Import complete.${NC}"
}

show_help() {
    echo "Bookmarks - Command-line bookmark manager"
    echo ""
    echo "Usage:"
    echo "  bookmarks.sh add <url> [\"title\"] [tags...]  Add a bookmark"
    echo "  bookmarks.sh list [tag]                     List bookmarks"
    echo "  bookmarks.sh search \"query\"                 Search bookmarks"
    echo "  bookmarks.sh tags                           List all tags"
    echo "  bookmarks.sh open <id>                      Open in browser"
    echo "  bookmarks.sh remove <id>                    Remove a bookmark"
    echo "  bookmarks.sh edit <id>                      Edit bookmark"
    echo "  bookmarks.sh export [file]                  Export to JSON"
    echo "  bookmarks.sh import <file>                  Import from JSON"
    echo "  bookmarks.sh help                           Show this help"
    echo ""
    echo "Examples:"
    echo "  bookmarks.sh add https://github.com"
    echo "  bookmarks.sh add https://docs.python.org \"Python Docs\" python reference"
    echo "  bookmarks.sh list python"
    echo "  bookmarks.sh search docs"
    echo "  bookmarks.sh open 3"
}

case "$1" in
    add)
        shift
        add_bookmark "$@"
        ;;
    list|ls)
        list_bookmarks "$2"
        ;;
    search|find)
        shift
        search_bookmarks "$@"
        ;;
    tags)
        list_tags
        ;;
    open|go)
        open_bookmark "$2"
        ;;
    remove|rm|delete)
        remove_bookmark "$2"
        ;;
    edit)
        edit_bookmark "$2"
        ;;
    export)
        export_bookmarks "$2"
        ;;
    import)
        import_bookmarks "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_bookmarks
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'bookmarks.sh help' for usage"
        exit 1
        ;;
esac
