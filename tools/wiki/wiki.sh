#!/bin/bash
#
# Wiki - Personal knowledge base and documentation manager
#
# Usage:
#   wiki.sh new "title" [--topic topic]        Create a new wiki page
#   wiki.sh edit <id|title>                    Edit an existing page
#   wiki.sh view <id|title>                    View a page
#   wiki.sh list [--topic topic]               List all pages
#   wiki.sh search "query"                     Search pages
#   wiki.sh topics                             List all topics
#   wiki.sh link <from_id> <to_id>             Link two pages
#   wiki.sh backlinks <id>                     Show pages linking to a page
#   wiki.sh recent [n]                         Show recently updated pages
#   wiki.sh archive <id>                       Archive a page
#   wiki.sh export [--format md|html]          Export all pages
#   wiki.sh stats                              Show wiki statistics
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
PAGES_DIR="$DATA_DIR/pages"
INDEX_FILE="$DATA_DIR/index.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$PAGES_DIR"

# Initialize index file if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" << 'EOF'
{
    "pages": [],
    "next_id": 1,
    "topics": [],
    "config": {
        "default_editor": "",
        "auto_link": true,
        "show_backlinks": true
    }
}
EOF
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

# Generate a URL-friendly slug from title
slugify() {
    local input="$*"
    echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Find page by ID or title
find_page() {
    local query="$1"
    local page=""

    # Try as numeric ID first
    if [[ "$query" =~ ^[0-9]+$ ]]; then
        page=$(jq -r --argjson id "$query" '.pages[] | select(.id == $id)' "$INDEX_FILE")
    fi

    # Try as slug/title match
    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        local slug=$(slugify "$query")
        page=$(jq -r --arg slug "$slug" '.pages[] | select(.slug == $slug)' "$INDEX_FILE")
    fi

    # Try partial title match
    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        page=$(jq -r --arg q "$query" '.pages[] | select(.title | ascii_downcase | contains($q | ascii_downcase))' "$INDEX_FILE" | head -1)
    fi

    echo "$page"
}

# Create new page
new_page() {
    local title=""
    local topic="general"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --topic|-t)
                topic="$2"
                shift 2
                ;;
            *)
                if [[ -z "$title" ]]; then
                    title="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "Usage: wiki.sh new \"Page Title\" [--topic topic]"
        exit 1
    fi

    local slug=$(slugify "$title")

    # Check if page with same slug exists
    local existing=$(jq -r --arg slug "$slug" '.pages[] | select(.slug == $slug and .archived != true)' "$INDEX_FILE")
    if [[ -n "$existing" ]] && [[ "$existing" != "null" ]]; then
        echo -e "${YELLOW}A page with similar title already exists:${NC}"
        echo "$existing" | jq -r '"  [\(.id)] \(.title)"'
        read -p "Create anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
        # Append timestamp to make slug unique
        slug="${slug}-$(date +%s)"
    fi

    local next_id=$(jq -r '.next_id' "$INDEX_FILE")
    local page_file="$PAGES_DIR/page_${next_id}.md"

    # Create page with template
    cat > "$page_file" << EOF
# $title

**Topic:** $topic
**Created:** $NOW
**Last Updated:** $NOW

---

## Overview



## Details



## Related

-

---
*Wiki page #$next_id*
EOF

    # Add topic if new
    local topic_exists=$(jq -r --arg t "$topic" '.topics | index($t)' "$INDEX_FILE")
    if [[ "$topic_exists" == "null" ]]; then
        jq --arg t "$topic" '.topics += [$t]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    fi

    # Update index
    jq --arg title "$title" \
       --arg slug "$slug" \
       --arg topic "$topic" \
       --arg file "page_${next_id}.md" \
       --arg created "$NOW" \
       --argjson id "$next_id" '
        .pages += [{
            "id": $id,
            "title": $title,
            "slug": $slug,
            "topic": $topic,
            "file": $file,
            "created": $created,
            "updated": $created,
            "links": [],
            "archived": false
        }] |
        .next_id = ($id + 1)
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Created wiki page #$next_id:${NC} $title"
    echo -e "${CYAN}Topic:${NC} $topic"
    echo -e "${CYAN}File:${NC} $page_file"
    echo ""

    # Open in editor
    local editor="${EDITOR:-${VISUAL:-nano}}"
    read -p "Open in editor? (Y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        $editor "$page_file"

        # Update modified time and detect links
        update_page_metadata "$next_id"
    fi
}

# Edit existing page
edit_page() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh edit <id|title>"
        exit 1
    fi

    local page=$(find_page "$query")

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        echo ""
        echo "Try 'wiki.sh list' to see all pages or 'wiki.sh search' to find one."
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')
    local file=$(echo "$page" | jq -r '.file')
    local page_file="$PAGES_DIR/$file"

    if [[ ! -f "$page_file" ]]; then
        echo -e "${RED}Page file not found:${NC} $page_file"
        exit 1
    fi

    echo -e "${GREEN}Editing:${NC} $title (#$id)"

    local editor="${EDITOR:-${VISUAL:-nano}}"
    $editor "$page_file"

    # Update metadata
    update_page_metadata "$id"

    echo -e "${GREEN}Updated:${NC} $title"
}

# Update page metadata after edit
update_page_metadata() {
    local id="$1"
    local now=$(date '+%Y-%m-%d %H:%M')

    # Get page info
    local page=$(jq -r --argjson id "$id" '.pages[] | select(.id == $id)' "$INDEX_FILE")
    local file=$(echo "$page" | jq -r '.file')
    local page_file="$PAGES_DIR/$file"

    # Detect wiki links [[Page Title]] or [[id]]
    local links="[]"
    if [[ -f "$page_file" ]]; then
        # Extract link targets from [[...]] patterns
        links=$(grep -oE '\[\[[^\]]+\]\]' "$page_file" 2>/dev/null | sed 's/\[\[//g' | sed 's/\]\]//g' | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
    fi

    # Update index with new timestamp and links
    jq --argjson id "$id" --arg updated "$now" --argjson links "$links" '
        .pages = [.pages[] | if .id == $id then . + {"updated": $updated, "links": $links} else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
}

# View page
view_page() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh view <id|title>"
        exit 1
    fi

    local page=$(find_page "$query")

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')
    local topic=$(echo "$page" | jq -r '.topic')
    local file=$(echo "$page" | jq -r '.file')
    local created=$(echo "$page" | jq -r '.created')
    local updated=$(echo "$page" | jq -r '.updated')
    local page_file="$PAGES_DIR/$file"

    if [[ ! -f "$page_file" ]]; then
        echo -e "${RED}Page file not found:${NC} $page_file"
        exit 1
    fi

    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}$title${NC} ${GRAY}(#$id)${NC}"
    echo -e "  ${CYAN}Topic:${NC} $topic  ${GRAY}|${NC}  ${CYAN}Updated:${NC} $updated"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Display with less or cat
    if command -v less &> /dev/null && [[ -t 1 ]]; then
        cat "$page_file"
    else
        cat "$page_file"
    fi

    # Show backlinks if enabled
    if [[ "$(jq -r '.config.show_backlinks' "$INDEX_FILE")" == "true" ]]; then
        echo ""
        echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
        local backlinks=$(jq -r --arg title "$title" --argjson id "$id" '
            .pages[] | select(.links | map(ascii_downcase) | (index($title | ascii_downcase) or index($id | tostring))) | "\(.id)|\(.title)"
        ' "$INDEX_FILE" 2>/dev/null)

        if [[ -n "$backlinks" ]]; then
            echo -e "${CYAN}Backlinks:${NC}"
            echo "$backlinks" | while IFS='|' read -r bid btitle; do
                echo -e "  ${YELLOW}←${NC} [$bid] $btitle"
            done
        fi
    fi
}

# List pages
list_pages() {
    local filter_topic=""
    local show_archived=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --topic|-t)
                filter_topic="$2"
                shift 2
                ;;
            --archived|-a)
                show_archived=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${BLUE}=== Wiki Pages ===${NC}"
    echo ""

    local query='.pages'
    if [[ "$show_archived" != "true" ]]; then
        query="$query | map(select(.archived != true))"
    fi
    if [[ -n "$filter_topic" ]]; then
        query="$query | map(select(.topic == \"$filter_topic\"))"
    fi

    local pages=$(jq -r "$query | sort_by(.updated) | reverse | .[] | \"\(.id)|\(.title)|\(.topic)|\(.updated)|\(.archived)\"" "$INDEX_FILE")

    if [[ -z "$pages" ]]; then
        echo "No pages found."
        if [[ -n "$filter_topic" ]]; then
            echo "Try without --topic filter or create a new page."
        fi
        exit 0
    fi

    local current_topic=""
    echo "$pages" | while IFS='|' read -r id title topic updated archived; do
        if [[ "$current_topic" != "$topic" ]]; then
            if [[ -n "$current_topic" ]]; then
                echo ""
            fi
            echo -e "${MAGENTA}[$topic]${NC}"
            current_topic="$topic"
        fi

        local archived_mark=""
        if [[ "$archived" == "true" ]]; then
            archived_mark=" ${GRAY}(archived)${NC}"
        fi

        # Truncate title if too long
        local display_title="$title"
        if [[ ${#display_title} -gt 50 ]]; then
            display_title="${display_title:0:47}..."
        fi

        echo -e "  ${YELLOW}[$id]${NC} $display_title${archived_mark}"
        echo -e "       ${GRAY}Updated: $updated${NC}"
    done

    echo ""
    local total=$(jq "$query | length" "$INDEX_FILE")
    echo -e "${CYAN}Total: $total page(s)${NC}"
}

# Search pages
search_pages() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local found=0

    # Search in titles
    echo -e "${CYAN}Title matches:${NC}"
    local title_matches=$(jq -r --arg q "$query" '
        .pages | map(select(.archived != true and (.title | ascii_downcase | contains($q | ascii_downcase)))) | .[] | "\(.id)|\(.title)|\(.topic)"
    ' "$INDEX_FILE")

    if [[ -n "$title_matches" ]]; then
        echo "$title_matches" | while IFS='|' read -r id title topic; do
            echo -e "  ${YELLOW}[$id]${NC} $title ${GRAY}($topic)${NC}"
            ((found++))
        done
    else
        echo "  No title matches"
    fi
    echo ""

    # Search in content
    echo -e "${CYAN}Content matches:${NC}"
    for page_file in "$PAGES_DIR"/*.md; do
        if [[ -f "$page_file" ]]; then
            if grep -qi "$query" "$page_file" 2>/dev/null; then
                local filename=$(basename "$page_file")
                local page_info=$(jq -r --arg file "$filename" '.pages[] | select(.file == $file and .archived != true) | "\(.id)|\(.title)"' "$INDEX_FILE")

                if [[ -n "$page_info" ]]; then
                    local id=$(echo "$page_info" | cut -d'|' -f1)
                    local title=$(echo "$page_info" | cut -d'|' -f2)

                    echo -e "  ${YELLOW}[$id]${NC} $title"
                    # Show matching context
                    grep -i --color=always -m 2 "$query" "$page_file" 2>/dev/null | while read -r line; do
                        echo -e "       ${GRAY}...${line:0:70}...${NC}"
                    done
                    ((found++))
                fi
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "  No content matches"
    fi
}

# List topics
list_topics() {
    echo -e "${BLUE}=== Wiki Topics ===${NC}"
    echo ""

    jq -r '.topics[]' "$INDEX_FILE" | while read -r topic; do
        local count=$(jq -r --arg t "$topic" '.pages | map(select(.topic == $t and .archived != true)) | length' "$INDEX_FILE")
        printf "  ${MAGENTA}%-20s${NC} %d page(s)\n" "$topic" "$count"
    done

    echo ""
    echo -e "${GRAY}Create pages in a topic with: wiki.sh new \"Title\" --topic topic-name${NC}"
}

# Link pages
link_pages() {
    local from_id="$1"
    local to_id="$2"

    if [[ -z "$from_id" ]] || [[ -z "$to_id" ]]; then
        echo "Usage: wiki.sh link <from_id> <to_id>"
        exit 1
    fi

    local from_page=$(find_page "$from_id")
    local to_page=$(find_page "$to_id")

    if [[ -z "$from_page" ]] || [[ "$from_page" == "null" ]]; then
        echo -e "${RED}Source page not found:${NC} $from_id"
        exit 1
    fi

    if [[ -z "$to_page" ]] || [[ "$to_page" == "null" ]]; then
        echo -e "${RED}Target page not found:${NC} $to_id"
        exit 1
    fi

    local from_actual_id=$(echo "$from_page" | jq -r '.id')
    local from_title=$(echo "$from_page" | jq -r '.title')
    local to_actual_id=$(echo "$to_page" | jq -r '.id')
    local to_title=$(echo "$to_page" | jq -r '.title')

    # Add link to source page
    jq --argjson from_id "$from_actual_id" --arg to_title "$to_title" '
        .pages = [.pages[] | if .id == $from_id then .links = ((.links // []) + [$to_title] | unique) else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Linked:${NC} $from_title ${CYAN}→${NC} $to_title"
    echo ""
    echo -e "${GRAY}Tip: You can also add [[Page Title]] in the page content for wiki-style links${NC}"
}

# Show backlinks
show_backlinks() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh backlinks <id|title>"
        exit 1
    fi

    local page=$(find_page "$query")

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')

    echo -e "${BLUE}=== Backlinks to: $title (#$id) ===${NC}"
    echo ""

    local backlinks=$(jq -r --arg title "$title" --argjson id "$id" '
        .pages[] | select(.archived != true) | select(.links | map(ascii_downcase) | (index($title | ascii_downcase) or index($id | tostring))) | "\(.id)|\(.title)|\(.topic)"
    ' "$INDEX_FILE")

    if [[ -z "$backlinks" ]]; then
        echo "No pages link to this page."
    else
        echo "$backlinks" | while IFS='|' read -r bid btitle btopic; do
            echo -e "  ${YELLOW}←${NC} [$bid] $btitle ${GRAY}($btopic)${NC}"
        done
    fi
}

# Show recent pages
show_recent() {
    local count=${1:-10}

    echo -e "${BLUE}=== Recently Updated Pages ===${NC}"
    echo ""

    jq -r ".pages | map(select(.archived != true)) | sort_by(.updated) | reverse | .[0:$count] | .[] | \"\(.id)|\(.title)|\(.topic)|\(.updated)\"" "$INDEX_FILE" | \
    while IFS='|' read -r id title topic updated; do
        echo -e "  ${YELLOW}[$id]${NC} $title"
        echo -e "       ${GRAY}$updated${NC} ${MAGENTA}($topic)${NC}"
        echo ""
    done
}

# Archive page
archive_page() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh archive <id|title>"
        exit 1
    fi

    local page=$(find_page "$query")

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')

    read -p "Archive '$title'? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    jq --argjson id "$id" '
        .pages = [.pages[] | if .id == $id then . + {"archived": true} else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${YELLOW}Archived:${NC} $title"
    echo ""
    echo -e "${GRAY}Restore with: wiki.sh unarchive $id${NC}"
}

# Unarchive page
unarchive_page() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh unarchive <id>"
        exit 1
    fi

    local page=$(jq -r --argjson id "$query" '.pages[] | select(.id == $id)' "$INDEX_FILE" 2>/dev/null)

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')

    jq --argjson id "$id" '
        .pages = [.pages[] | if .id == $id then . + {"archived": false} else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Restored:${NC} $title"
}

# Export pages
export_pages() {
    local format="${1:-md}"
    local export_dir="$DATA_DIR/export_$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$export_dir"

    echo -e "${BLUE}=== Exporting Wiki ===${NC}"
    echo ""

    local count=0

    jq -r '.pages[] | select(.archived != true) | "\(.id)|\(.title)|\(.slug)|\(.topic)|\(.file)"' "$INDEX_FILE" | \
    while IFS='|' read -r id title slug topic file; do
        local src_file="$PAGES_DIR/$file"

        if [[ -f "$src_file" ]]; then
            local topic_dir="$export_dir/$topic"
            mkdir -p "$topic_dir"

            if [[ "$format" == "html" ]]; then
                # Basic markdown to HTML conversion
                local html_file="$topic_dir/${slug}.html"
                echo "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>$title</title>" > "$html_file"
                echo "<style>body{font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px;}</style></head><body>" >> "$html_file"

                # Simple markdown conversion
                sed 's/^# \(.*\)/<h1>\1<\/h1>/; s/^## \(.*\)/<h2>\1<\/h2>/; s/^### \(.*\)/<h3>\1<\/h3>/; s/^\*\*\(.*\)\*\*/<strong>\1<\/strong>/; s/^- \(.*\)/<li>\1<\/li>/' "$src_file" >> "$html_file"

                echo "</body></html>" >> "$html_file"
                echo -e "  ${GREEN}Exported:${NC} $topic/$slug.html"
            else
                cp "$src_file" "$topic_dir/${slug}.md"
                echo -e "  ${GREEN}Exported:${NC} $topic/$slug.md"
            fi

            ((count++))
        fi
    done

    echo ""
    echo -e "${CYAN}Exported $count page(s) to:${NC} $export_dir"
}

# Show statistics
show_stats() {
    echo -e "${BLUE}=== Wiki Statistics ===${NC}"
    echo ""

    local total_pages=$(jq '.pages | length' "$INDEX_FILE")
    local active_pages=$(jq '.pages | map(select(.archived != true)) | length' "$INDEX_FILE")
    local archived_pages=$((total_pages - active_pages))
    local total_topics=$(jq '.topics | length' "$INDEX_FILE")

    echo -e "${CYAN}Pages:${NC}"
    echo "  Active: $active_pages"
    echo "  Archived: $archived_pages"
    echo "  Total: $total_pages"
    echo ""

    echo -e "${CYAN}Topics:${NC} $total_topics"
    jq -r '.topics[]' "$INDEX_FILE" | while read -r topic; do
        local count=$(jq -r --arg t "$topic" '.pages | map(select(.topic == $t and .archived != true)) | length' "$INDEX_FILE")
        echo "  - $topic: $count"
    done
    echo ""

    # Most linked pages
    echo -e "${CYAN}Most Connected Pages:${NC}"
    jq -r '.pages | map(select(.archived != true)) | sort_by(.links | length) | reverse | .[0:5] | .[] | "\(.links | length)|\(.title)"' "$INDEX_FILE" | \
    while IFS='|' read -r links title; do
        if [[ "$links" -gt 0 ]]; then
            echo "  $title ($links links)"
        fi
    done
    echo ""

    # Recent activity
    echo -e "${CYAN}Recent Activity:${NC}"
    local today_count=$(jq -r --arg today "$TODAY" '.pages | map(select(.updated | startswith($today))) | length' "$INDEX_FILE")
    echo "  Updated today: $today_count"

    # Calculate total content size
    local total_size=0
    for page_file in "$PAGES_DIR"/*.md; do
        if [[ -f "$page_file" ]]; then
            local size=$(wc -c < "$page_file")
            total_size=$((total_size + size))
        fi
    done
    local size_kb=$((total_size / 1024))
    echo "  Total content: ${size_kb}KB"
}

# Delete page permanently
delete_page() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: wiki.sh delete <id>"
        exit 1
    fi

    local page=$(find_page "$query")

    if [[ -z "$page" ]] || [[ "$page" == "null" ]]; then
        echo -e "${RED}Page not found:${NC} $query"
        exit 1
    fi

    local id=$(echo "$page" | jq -r '.id')
    local title=$(echo "$page" | jq -r '.title')
    local file=$(echo "$page" | jq -r '.file')
    local page_file="$PAGES_DIR/$file"

    echo -e "${RED}WARNING: This will permanently delete '$title' (#$id)${NC}"
    read -p "Type 'DELETE' to confirm: " confirm

    if [[ "$confirm" != "DELETE" ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Remove file
    if [[ -f "$page_file" ]]; then
        rm "$page_file"
    fi

    # Remove from index
    jq --argjson id "$id" '.pages = [.pages[] | select(.id != $id)]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${RED}Deleted:${NC} $title"
}

show_help() {
    echo "Wiki - Personal knowledge base and documentation manager"
    echo ""
    echo "Usage:"
    echo "  wiki.sh new \"title\" [--topic t]  Create a new wiki page"
    echo "  wiki.sh edit <id|title>          Edit an existing page"
    echo "  wiki.sh view <id|title>          View a page"
    echo "  wiki.sh list [--topic t]         List all pages"
    echo "  wiki.sh search \"query\"           Search pages"
    echo "  wiki.sh topics                   List all topics"
    echo "  wiki.sh link <from> <to>         Link two pages"
    echo "  wiki.sh backlinks <id>           Show pages linking to a page"
    echo "  wiki.sh recent [n]               Show recently updated pages"
    echo "  wiki.sh archive <id>             Archive a page"
    echo "  wiki.sh unarchive <id>           Restore archived page"
    echo "  wiki.sh export [--format md|html] Export all pages"
    echo "  wiki.sh stats                    Show wiki statistics"
    echo "  wiki.sh delete <id>              Permanently delete a page"
    echo "  wiki.sh help                     Show this help"
    echo ""
    echo "Wiki Links:"
    echo "  Use [[Page Title]] in page content to create wiki-style links"
    echo "  These are automatically detected and tracked as backlinks"
    echo ""
    echo "Examples:"
    echo "  wiki.sh new \"Git Workflow\" --topic development"
    echo "  wiki.sh edit \"git workflow\""
    echo "  wiki.sh search \"docker\""
    echo "  wiki.sh list --topic development"
}

case "$1" in
    new|create|add)
        shift
        new_page "$@"
        ;;
    edit|e)
        edit_page "$2"
        ;;
    view|show|v)
        view_page "$2"
        ;;
    list|ls)
        shift
        list_pages "$@"
        ;;
    search|find|s)
        shift
        search_pages "$@"
        ;;
    topics)
        list_topics
        ;;
    link)
        link_pages "$2" "$3"
        ;;
    backlinks|bl)
        show_backlinks "$2"
        ;;
    recent)
        show_recent "$2"
        ;;
    archive)
        archive_page "$2"
        ;;
    unarchive|restore)
        unarchive_page "$2"
        ;;
    export)
        shift
        format="md"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --format|-f)
                    format="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        export_pages "$format"
        ;;
    stats|statistics)
        show_stats
        ;;
    delete|rm)
        delete_page "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # Default: show recent pages
        show_recent 5
        ;;
    *)
        # Try to view page by name
        page=$(find_page "$1")
        if [[ -n "$page" ]] && [[ "$page" != "null" ]]; then
            view_page "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'wiki.sh help' for usage"
            exit 1
        fi
        ;;
esac
