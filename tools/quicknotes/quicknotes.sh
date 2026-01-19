#!/bin/bash
#
# Quick Notes - Fast command-line note capture with tagging
#
# Usage:
#   quicknotes.sh add "Your note here"       - Add a note
#   quicknotes.sh add "Note #work #urgent"   - Add a note with inline tags
#   quicknotes.sh list [n]                   - Show last n notes (default: 10)
#   quicknotes.sh search "keyword"           - Search notes
#   quicknotes.sh today                      - Show today's notes
#   quicknotes.sh tag "tagname"              - Show notes with specific tag
#   quicknotes.sh tags                       - List all tags with counts
#   quicknotes.sh edit                       - Open notes in editor
#   quicknotes.sh delete <line_num>          - Delete a specific note
#   quicknotes.sh export [file]              - Export notes to file
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
NOTES_FILE="$DATA_DIR/notes.txt"
TAGS_INDEX="$DATA_DIR/tags_index.txt"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"
touch "$NOTES_FILE"
touch "$TAGS_INDEX"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m'

# Extract tags from a note (words starting with #)
extract_tags() {
    local note="$1"
    echo "$note" | grep -oE '#[a-zA-Z0-9_-]+' | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' '
}

# Format note for display, highlighting tags
format_note() {
    local note="$1"
    # Highlight hashtags in magenta
    echo "$note" | sed -E "s/#([a-zA-Z0-9_-]+)/$(printf "${MAGENTA}")#\1$(printf "${NC}")/g"
}

add_note() {
    local note="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -z "$note" ]]; then
        echo "Usage: quicknotes.sh add \"Your note here\""
        echo ""
        echo "Tip: Use #tags inline to categorize notes"
        echo "  Example: quicknotes.sh add \"Review PR #work #urgent\""
        exit 1
    fi

    # Extract and store tags
    local tags=$(extract_tags "$note")

    # Store note
    echo "[$timestamp] $note" >> "$NOTES_FILE"

    # Update tags index if tags present
    if [[ -n "$tags" ]]; then
        local line_num=$(wc -l < "$NOTES_FILE")
        for tag in $tags; do
            echo "$tag:$line_num:$timestamp" >> "$TAGS_INDEX"
        done
    fi

    echo -e "${GREEN}Note added.${NC}"

    # Show tags if present
    if [[ -n "$tags" ]]; then
        echo -e "${GRAY}Tags:${NC}${MAGENTA}$tags${NC}"
    fi
}

list_notes() {
    local count=${1:-10}

    if [[ ! -s "$NOTES_FILE" ]]; then
        echo "No notes yet. Add one with: quicknotes.sh add \"Your note\""
        exit 0
    fi

    local total=$(wc -l < "$NOTES_FILE")

    echo -e "${BLUE}=== Recent Notes (${count} of ${total}) ===${NC}"
    echo ""

    # Show notes with line numbers for reference
    tail -n "$count" "$NOTES_FILE" | nl -ba | while IFS= read -r line; do
        local line_num=$(echo "$line" | awk '{print $1}')
        local content=$(echo "$line" | cut -f2-)

        # Extract timestamp and note
        timestamp=$(echo "$content" | grep -oP '^\[\K[^\]]+' 2>/dev/null || echo "")
        note=$(echo "$content" | sed 's/^\[[^]]*\] //')

        if [[ -n "$timestamp" ]]; then
            echo -e "${GRAY}${line_num}.${NC} ${CYAN}[$timestamp]${NC} $(format_note "$note")"
        else
            echo -e "${GRAY}${line_num}.${NC} $content"
        fi
    done

    echo ""
    echo -e "${GRAY}Tip: Use 'quicknotes.sh tag #tagname' to filter by tag${NC}"
}

search_notes() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: quicknotes.sh search \"keyword\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local results=$(grep -in "$query" "$NOTES_FILE" 2>/dev/null)

    if [[ -z "$results" ]]; then
        echo "No notes found matching \"$query\""
    else
        local count=$(echo "$results" | wc -l)
        echo -e "${GRAY}Found $count note(s):${NC}"
        echo ""

        echo "$results" | while IFS= read -r line; do
            local line_num=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)

            timestamp=$(echo "$content" | grep -oP '^\[\K[^\]]+' 2>/dev/null || echo "")
            note=$(echo "$content" | sed 's/^\[[^]]*\] //')

            # Highlight the search term
            highlighted=$(echo "$note" | grep -i --color=always "$query" 2>/dev/null || echo "$note")

            if [[ -n "$timestamp" ]]; then
                echo -e "${GRAY}${line_num}.${NC} ${CYAN}[$timestamp]${NC} $(format_note "$highlighted")"
            else
                echo -e "${GRAY}${line_num}.${NC} $highlighted"
            fi
        done
    fi
}

today_notes() {
    echo -e "${BLUE}=== Today's Notes ($TODAY) ===${NC}"
    echo ""

    local results=$(grep -n "^\[$TODAY" "$NOTES_FILE" 2>/dev/null)

    if [[ -z "$results" ]]; then
        echo "No notes today. Add one with: quicknotes.sh add \"Your note\""
    else
        local count=$(echo "$results" | wc -l)
        echo -e "${GRAY}$count note(s) today:${NC}"
        echo ""

        echo "$results" | while IFS= read -r line; do
            local line_num=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)

            timestamp=$(echo "$content" | grep -oP '^\[\K[^\]]+' 2>/dev/null || echo "")
            note=$(echo "$content" | sed 's/^\[[^]]*\] //')
            time_only=$(echo "$timestamp" | cut -d' ' -f2)

            echo -e "${GRAY}${line_num}.${NC} ${CYAN}[$time_only]${NC} $(format_note "$note")"
        done
    fi
}

filter_by_tag() {
    local tag="$1"

    if [[ -z "$tag" ]]; then
        echo "Usage: quicknotes.sh tag \"tagname\""
        echo "  or:  quicknotes.sh tag #tagname"
        exit 1
    fi

    # Remove leading # if present and lowercase
    tag=$(echo "$tag" | sed 's/^#//' | tr '[:upper:]' '[:lower:]')

    echo -e "${BLUE}=== Notes tagged #$tag ===${NC}"
    echo ""

    # Search for the tag in notes (case insensitive)
    local results=$(grep -in "#$tag" "$NOTES_FILE" 2>/dev/null)

    if [[ -z "$results" ]]; then
        echo "No notes found with tag #$tag"
        echo ""
        echo -e "${GRAY}Available tags:${NC}"
        list_tags_compact
    else
        local count=$(echo "$results" | wc -l)
        echo -e "${GRAY}$count note(s):${NC}"
        echo ""

        echo "$results" | while IFS= read -r line; do
            local line_num=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)

            timestamp=$(echo "$content" | grep -oP '^\[\K[^\]]+' 2>/dev/null || echo "")
            note=$(echo "$content" | sed 's/^\[[^]]*\] //')

            if [[ -n "$timestamp" ]]; then
                echo -e "${GRAY}${line_num}.${NC} ${CYAN}[$timestamp]${NC} $(format_note "$note")"
            else
                echo -e "${GRAY}${line_num}.${NC} $(format_note "$content")"
            fi
        done
    fi
}

list_tags() {
    echo -e "${BLUE}=== Tags ===${NC}"
    echo ""

    if [[ ! -s "$NOTES_FILE" ]]; then
        echo "No notes yet."
        exit 0
    fi

    # Extract all tags from notes and count them
    local tags=$(grep -ohE '#[a-zA-Z0-9_-]+' "$NOTES_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn)

    if [[ -z "$tags" ]]; then
        echo "No tags found in notes."
        echo ""
        echo -e "${GRAY}Tip: Add tags inline when creating notes:${NC}"
        echo -e "${GRAY}  quicknotes.sh add \"Review code #work #urgent\"${NC}"
    else
        echo -e "${GRAY}Usage count | Tag${NC}"
        echo ""
        echo "$tags" | while read -r count tag; do
            printf "  ${YELLOW}%3d${NC}  ${MAGENTA}%s${NC}\n" "$count" "$tag"
        done

        echo ""
        echo -e "${GRAY}Filter notes: quicknotes.sh tag #tagname${NC}"
    fi
}

list_tags_compact() {
    grep -ohE '#[a-zA-Z0-9_-]+' "$NOTES_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' '
    echo ""
}

delete_note() {
    local line_num="$1"

    if [[ -z "$line_num" ]]; then
        echo "Usage: quicknotes.sh delete <line_number>"
        echo ""
        echo "Use 'quicknotes.sh list' to see line numbers."
        exit 1
    fi

    if ! [[ "$line_num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Line number must be a positive integer${NC}"
        exit 1
    fi

    local total=$(wc -l < "$NOTES_FILE")

    if [[ "$line_num" -lt 1 ]] || [[ "$line_num" -gt "$total" ]]; then
        echo -e "${RED}Error: Line $line_num does not exist (1-$total available)${NC}"
        exit 1
    fi

    # Show the note being deleted
    local note=$(sed -n "${line_num}p" "$NOTES_FILE")
    echo -e "${YELLOW}Deleting:${NC} $note"

    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i "${line_num}d" "$NOTES_FILE"
        echo -e "${RED}Note deleted.${NC}"
    else
        echo "Cancelled."
    fi
}

export_notes() {
    local output_file="${1:-notes_export_$(date +%Y%m%d).txt}"

    if [[ ! -s "$NOTES_FILE" ]]; then
        echo "No notes to export."
        exit 0
    fi

    local count=$(wc -l < "$NOTES_FILE")
    cp "$NOTES_FILE" "$output_file"

    echo -e "${GREEN}Exported $count note(s) to:${NC} $output_file"
}

edit_notes() {
    local editor="${EDITOR:-nano}"
    $editor "$NOTES_FILE"
}

show_stats() {
    echo -e "${BLUE}=== Notes Statistics ===${NC}"
    echo ""

    if [[ ! -s "$NOTES_FILE" ]]; then
        echo "No notes yet."
        exit 0
    fi

    local total=$(wc -l < "$NOTES_FILE")
    local today_count=$(grep -c "^\[$TODAY" "$NOTES_FILE" 2>/dev/null || echo "0")
    local this_week=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null)
    local week_count=$(awk -v date="$this_week" 'substr($0, 2, 10) >= date' "$NOTES_FILE" 2>/dev/null | wc -l)
    local tag_count=$(grep -ohE '#[a-zA-Z0-9_-]+' "$NOTES_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u | wc -l)
    local tagged_notes=$(grep -c '#[a-zA-Z0-9_-]' "$NOTES_FILE" 2>/dev/null || echo "0")

    echo -e "Total notes:        ${GREEN}$total${NC}"
    echo -e "Added today:        ${CYAN}$today_count${NC}"
    echo -e "Added this week:    ${CYAN}$week_count${NC}"
    echo ""
    echo -e "Unique tags:        ${MAGENTA}$tag_count${NC}"
    echo -e "Tagged notes:       ${MAGENTA}$tagged_notes${NC} ($(( tagged_notes * 100 / total ))%)"
}

show_help() {
    echo "Quick Notes - Fast command-line note capture with tagging"
    echo ""
    echo "Usage:"
    echo "  quicknotes.sh add \"note\"           Add a new note"
    echo "  quicknotes.sh add \"note #tag\"      Add note with inline tags"
    echo "  quicknotes.sh list [n]             Show last n notes (default: 10)"
    echo "  quicknotes.sh search \"query\"       Search notes"
    echo "  quicknotes.sh today                Show today's notes"
    echo "  quicknotes.sh tag \"tagname\"        Filter notes by tag"
    echo "  quicknotes.sh tags                 List all tags with counts"
    echo "  quicknotes.sh delete <line>        Delete a specific note"
    echo "  quicknotes.sh export [file]        Export notes to file"
    echo "  quicknotes.sh stats                Show statistics"
    echo "  quicknotes.sh edit                 Open notes in editor"
    echo "  quicknotes.sh help                 Show this help"
    echo ""
    echo "Tagging:"
    echo "  Add tags inline using #hashtag syntax:"
    echo "    quicknotes.sh add \"Review PR #work #code-review\""
    echo "    quicknotes.sh add \"Buy milk #personal #shopping\""
    echo ""
    echo "  Filter by tag:"
    echo "    quicknotes.sh tag work"
    echo "    quicknotes.sh tag #work"
    echo ""
    echo "Quick add (pipe input):"
    echo "  echo \"my note\" | quicknotes.sh add"
    echo ""
    echo "Examples:"
    echo "  quicknotes.sh add \"Meeting notes: discussed Q1 goals #work #meeting\""
    echo "  quicknotes.sh \"Quick thought about the project\"  # Shortcut add"
    echo "  quicknotes.sh tag meeting"
    echo "  quicknotes.sh list 20"
}

# Handle piped input (only if there's actual pipe content)
if [[ ! -t 0 ]] && [[ "$1" == "add" ]]; then
    note=$(cat)
    if [[ -n "$note" ]]; then
        add_note "$note"
        exit 0
    fi
    # If pipe was empty, fall through to regular command handling
fi

case "$1" in
    add)
        shift
        add_note "$@"
        ;;
    list|ls)
        list_notes "$2"
        ;;
    search|find)
        shift
        search_notes "$@"
        ;;
    today)
        today_notes
        ;;
    tag|t)
        shift
        filter_by_tag "$@"
        ;;
    tags)
        list_tags
        ;;
    delete|del|rm)
        delete_note "$2"
        ;;
    export)
        export_notes "$2"
        ;;
    stats|st)
        show_stats
        ;;
    edit)
        edit_notes
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # No args - show recent notes
        list_notes 5
        ;;
    *)
        # Assume it's a note to add
        add_note "$@"
        ;;
esac
