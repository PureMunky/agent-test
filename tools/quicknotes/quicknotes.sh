#!/bin/bash
#
# Quick Notes - Fast command-line note capture
#
# Usage:
#   quicknotes.sh add "Your note here"
#   quicknotes.sh list [n]           - Show last n notes (default: 10)
#   quicknotes.sh search "keyword"   - Search notes
#   quicknotes.sh today              - Show today's notes
#   quicknotes.sh edit               - Open notes in editor
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
NOTES_FILE="$DATA_DIR/notes.txt"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"
touch "$NOTES_FILE"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

add_note() {
    local note="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -z "$note" ]]; then
        echo "Usage: quicknotes.sh add \"Your note here\""
        exit 1
    fi

    echo "[$timestamp] $note" >> "$NOTES_FILE"
    echo -e "${GREEN}Note added.${NC}"
}

list_notes() {
    local count=${1:-10}

    if [[ ! -s "$NOTES_FILE" ]]; then
        echo "No notes yet. Add one with: quicknotes.sh add \"Your note\""
        exit 0
    fi

    echo -e "${BLUE}=== Last $count Notes ===${NC}"
    echo ""
    tail -n "$count" "$NOTES_FILE" | while IFS= read -r line; do
        # Extract timestamp and note
        timestamp=$(echo "$line" | grep -oP '^\[\K[^\]]+')
        note=$(echo "$line" | sed 's/^\[[^]]*\] //')
        echo -e "${CYAN}[$timestamp]${NC} $note"
    done
}

search_notes() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: quicknotes.sh search \"keyword\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local results=$(grep -i "$query" "$NOTES_FILE")

    if [[ -z "$results" ]]; then
        echo "No notes found matching \"$query\""
    else
        echo "$results" | while IFS= read -r line; do
            timestamp=$(echo "$line" | grep -oP '^\[\K[^\]]+')
            note=$(echo "$line" | sed 's/^\[[^]]*\] //')
            # Highlight the search term
            highlighted=$(echo "$note" | grep -i --color=always "$query")
            echo -e "${CYAN}[$timestamp]${NC} $highlighted"
        done
    fi
}

today_notes() {
    echo -e "${BLUE}=== Today's Notes ($TODAY) ===${NC}"
    echo ""

    local results=$(grep "^\[$TODAY" "$NOTES_FILE")

    if [[ -z "$results" ]]; then
        echo "No notes today. Add one with: quicknotes.sh add \"Your note\""
    else
        echo "$results" | while IFS= read -r line; do
            timestamp=$(echo "$line" | grep -oP '^\[\K[^\]]+')
            note=$(echo "$line" | sed 's/^\[[^]]*\] //')
            time_only=$(echo "$timestamp" | cut -d' ' -f2)
            echo -e "${CYAN}[$time_only]${NC} $note"
        done
    fi
}

edit_notes() {
    local editor="${EDITOR:-nano}"
    $editor "$NOTES_FILE"
}

show_help() {
    echo "Quick Notes - Fast command-line note capture"
    echo ""
    echo "Usage:"
    echo "  quicknotes.sh add \"note\"    Add a new note"
    echo "  quicknotes.sh list [n]      Show last n notes (default: 10)"
    echo "  quicknotes.sh search \"q\"    Search notes"
    echo "  quicknotes.sh today         Show today's notes"
    echo "  quicknotes.sh edit          Open notes in editor"
    echo "  quicknotes.sh help          Show this help"
    echo ""
    echo "Quick add (pipe input):"
    echo "  echo \"my note\" | quicknotes.sh add"
}

# Handle piped input
if [[ ! -t 0 ]] && [[ "$1" == "add" ]]; then
    note=$(cat)
    add_note "$note"
    exit 0
fi

case "$1" in
    add)
        shift
        add_note "$@"
        ;;
    list)
        list_notes "$2"
        ;;
    search)
        shift
        search_notes "$@"
        ;;
    today)
        today_notes
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
