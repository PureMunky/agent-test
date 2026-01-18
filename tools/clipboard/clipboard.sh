#!/bin/bash
#
# clipboard.sh - Clipboard history manager
# Store, search, and retrieve clipboard history from the command line
#

set -e

# Configuration
DATA_DIR="${CLIPBOARD_DATA_DIR:-$HOME/.local/share/clipboard-history}"
HISTORY_FILE="$DATA_DIR/history.txt"
MAX_ENTRIES="${CLIPBOARD_MAX_ENTRIES:-100}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure data directory exists
init_data_dir() {
    if [[ ! -d "$DATA_DIR" ]]; then
        mkdir -p "$DATA_DIR"
        touch "$HISTORY_FILE"
        echo -e "${GREEN}Initialized clipboard history at $DATA_DIR${NC}"
    fi
}

# Detect clipboard command based on available tools
detect_clipboard_cmd() {
    if command -v xclip &> /dev/null; then
        CLIP_COPY="xclip -selection clipboard"
        CLIP_PASTE="xclip -selection clipboard -o"
    elif command -v xsel &> /dev/null; then
        CLIP_COPY="xsel --clipboard --input"
        CLIP_PASTE="xsel --clipboard --output"
    elif command -v wl-copy &> /dev/null; then
        # Wayland support
        CLIP_COPY="wl-copy"
        CLIP_PASTE="wl-paste"
    elif command -v pbcopy &> /dev/null; then
        # macOS support
        CLIP_COPY="pbcopy"
        CLIP_PASTE="pbpaste"
    else
        echo -e "${RED}Error: No clipboard utility found.${NC}"
        echo "Please install one of: xclip, xsel, wl-clipboard (Wayland), or use macOS."
        return 1
    fi
}

# Generate unique ID for entry
generate_id() {
    echo "$(date +%s)_$$_$RANDOM"
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Save current clipboard to history
save() {
    init_data_dir
    detect_clipboard_cmd || return 1

    local content
    content=$($CLIP_PASTE 2>/dev/null) || {
        echo -e "${YELLOW}Clipboard is empty or unreadable${NC}"
        return 1
    }

    if [[ -z "$content" ]]; then
        echo -e "${YELLOW}Clipboard is empty${NC}"
        return 1
    fi

    local id=$(generate_id)
    local timestamp=$(get_timestamp)
    local tag="${1:-}"

    # Encode content for storage (escape newlines and special chars)
    local encoded_content=$(echo "$content" | base64 -w 0)

    # Prepend new entry to history
    local temp_file=$(mktemp)
    echo "$id|$timestamp|$tag|$encoded_content" > "$temp_file"

    if [[ -f "$HISTORY_FILE" ]]; then
        cat "$HISTORY_FILE" >> "$temp_file"
    fi

    mv "$temp_file" "$HISTORY_FILE"

    # Trim to max entries
    local temp_trim=$(mktemp)
    head -n "$MAX_ENTRIES" "$HISTORY_FILE" > "$temp_trim"
    mv "$temp_trim" "$HISTORY_FILE"

    local preview="${content:0:50}"
    [[ ${#content} -gt 50 ]] && preview="$preview..."

    echo -e "${GREEN}✓ Saved to clipboard history${NC}"
    echo -e "${CYAN}Preview:${NC} $preview"
    [[ -n "$tag" ]] && echo -e "${CYAN}Tag:${NC} $tag"
}

# Capture clipboard and save (alias for save)
capture() {
    save "$@"
}

# List clipboard history
list() {
    init_data_dir

    if [[ ! -s "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}No clipboard history found${NC}"
        return 0
    fi

    local limit="${1:-10}"
    local count=0

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    CLIPBOARD HISTORY                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    while IFS='|' read -r id timestamp tag encoded_content; do
        [[ $count -ge $limit ]] && break
        count=$((count + 1))

        # Decode content
        local content=$(echo "$encoded_content" | base64 -d 2>/dev/null)
        local preview="${content:0:60}"
        [[ ${#content} -gt 60 ]] && preview="$preview..."

        # Remove newlines from preview
        preview=$(echo "$preview" | tr '\n' ' ')

        echo -e "${CYAN}[$count]${NC} ${YELLOW}$timestamp${NC}"
        [[ -n "$tag" ]] && echo -e "    ${GREEN}Tag: $tag${NC}"
        echo -e "    $preview"
        echo
    done < "$HISTORY_FILE"

    local total=$(wc -l < "$HISTORY_FILE")
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo -e "Showing $count of $total entries. Use 'clipboard list <n>' to show more."
}

# Get entry by index and copy to clipboard
get() {
    init_data_dir
    detect_clipboard_cmd || return 1

    local index="${1:-1}"

    if ! [[ "$index" =~ ^[0-9]+$ ]] || [[ "$index" -lt 1 ]]; then
        echo -e "${RED}Error: Invalid index. Use a positive number.${NC}"
        return 1
    fi

    local entry=$(sed -n "${index}p" "$HISTORY_FILE")

    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: Entry #$index not found${NC}"
        return 1
    fi

    local encoded_content=$(echo "$entry" | cut -d'|' -f4)
    local content=$(echo "$encoded_content" | base64 -d 2>/dev/null)

    echo "$content" | $CLIP_COPY

    local preview="${content:0:50}"
    [[ ${#content} -gt 50 ]] && preview="$preview..."

    echo -e "${GREEN}✓ Copied entry #$index to clipboard${NC}"
    echo -e "${CYAN}Preview:${NC} $preview"
}

# Show full content of an entry
show() {
    init_data_dir

    local index="${1:-1}"

    if ! [[ "$index" =~ ^[0-9]+$ ]] || [[ "$index" -lt 1 ]]; then
        echo -e "${RED}Error: Invalid index. Use a positive number.${NC}"
        return 1
    fi

    local entry=$(sed -n "${index}p" "$HISTORY_FILE")

    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: Entry #$index not found${NC}"
        return 1
    fi

    local timestamp=$(echo "$entry" | cut -d'|' -f2)
    local tag=$(echo "$entry" | cut -d'|' -f3)
    local encoded_content=$(echo "$entry" | cut -d'|' -f4)
    local content=$(echo "$encoded_content" | base64 -d 2>/dev/null)

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Entry #$index${NC} - $timestamp"
    [[ -n "$tag" ]] && echo -e "${GREEN}Tag: $tag${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    echo "$content"
}

# Search history by keyword
search() {
    init_data_dir

    local query="$1"

    if [[ -z "$query" ]]; then
        echo -e "${RED}Error: Please provide a search term${NC}"
        echo "Usage: clipboard search <term>"
        return 1
    fi

    if [[ ! -s "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}No clipboard history found${NC}"
        return 0
    fi

    echo -e "${BLUE}Search results for:${NC} $query"
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo

    local count=0
    local line_num=0

    while IFS='|' read -r id timestamp tag encoded_content; do
        line_num=$((line_num + 1))

        # Decode and search content
        local content=$(echo "$encoded_content" | base64 -d 2>/dev/null)

        if echo "$content" | grep -qi "$query" || echo "$tag" | grep -qi "$query"; then
            count=$((count + 1))
            local preview="${content:0:60}"
            [[ ${#content} -gt 60 ]] && preview="$preview..."
            preview=$(echo "$preview" | tr '\n' ' ')

            echo -e "${CYAN}[$line_num]${NC} ${YELLOW}$timestamp${NC}"
            [[ -n "$tag" ]] && echo -e "    ${GREEN}Tag: $tag${NC}"
            echo -e "    $preview"
            echo
        fi
    done < "$HISTORY_FILE"

    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}No matches found${NC}"
    else
        echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
        echo -e "Found $count matching entries. Use 'clipboard get <n>' to copy."
    fi
}

# Delete an entry
delete() {
    init_data_dir

    local index="$1"

    if [[ -z "$index" ]]; then
        echo -e "${RED}Error: Please provide entry number to delete${NC}"
        echo "Usage: clipboard delete <n>"
        return 1
    fi

    if ! [[ "$index" =~ ^[0-9]+$ ]] || [[ "$index" -lt 1 ]]; then
        echo -e "${RED}Error: Invalid index. Use a positive number.${NC}"
        return 1
    fi

    local total=$(wc -l < "$HISTORY_FILE")

    if [[ "$index" -gt "$total" ]]; then
        echo -e "${RED}Error: Entry #$index not found${NC}"
        return 1
    fi

    local temp_file=$(mktemp)
    sed "${index}d" "$HISTORY_FILE" > "$temp_file"
    mv "$temp_file" "$HISTORY_FILE"

    echo -e "${GREEN}✓ Deleted entry #$index${NC}"
}

# Clear all history
clear_history() {
    init_data_dir

    echo -e "${YELLOW}This will delete all clipboard history.${NC}"
    read -p "Are you sure? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        > "$HISTORY_FILE"
        echo -e "${GREEN}✓ Clipboard history cleared${NC}"
    else
        echo "Cancelled"
    fi
}

# Export history to file
export_history() {
    init_data_dir

    local output_file="${1:-clipboard_export_$(date +%Y%m%d_%H%M%S).txt}"

    if [[ ! -s "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}No clipboard history to export${NC}"
        return 0
    fi

    {
        echo "# Clipboard History Export"
        echo "# Exported: $(date)"
        echo "# Entries: $(wc -l < "$HISTORY_FILE")"
        echo

        local count=0
        while IFS='|' read -r id timestamp tag encoded_content; do
            ((count++))
            local content=$(echo "$encoded_content" | base64 -d 2>/dev/null)

            echo "=== Entry #$count ==="
            echo "Timestamp: $timestamp"
            [[ -n "$tag" ]] && echo "Tag: $tag"
            echo "---"
            echo "$content"
            echo
        done < "$HISTORY_FILE"
    } > "$output_file"

    echo -e "${GREEN}✓ Exported $(wc -l < "$HISTORY_FILE") entries to: $output_file${NC}"
}

# Add content directly (from stdin or argument)
add() {
    init_data_dir

    local content=""
    local tag=""

    # Check for tag flag
    if [[ "$1" == "-t" || "$1" == "--tag" ]]; then
        tag="$2"
        shift 2
    fi

    if [[ -n "$1" ]]; then
        content="$1"
    elif [[ ! -t 0 ]]; then
        # Read from stdin if piped
        content=$(cat)
    else
        echo -e "${RED}Error: No content provided${NC}"
        echo "Usage: clipboard add <content>"
        echo "   or: echo 'content' | clipboard add"
        return 1
    fi

    local id=$(generate_id)
    local timestamp=$(get_timestamp)
    local encoded_content=$(echo "$content" | base64 -w 0)

    local temp_file=$(mktemp)
    echo "$id|$timestamp|$tag|$encoded_content" > "$temp_file"

    if [[ -f "$HISTORY_FILE" ]]; then
        cat "$HISTORY_FILE" >> "$temp_file"
    fi

    mv "$temp_file" "$HISTORY_FILE"

    # Trim to max entries
    local temp_trim=$(mktemp)
    head -n "$MAX_ENTRIES" "$HISTORY_FILE" > "$temp_trim"
    mv "$temp_trim" "$HISTORY_FILE"

    local preview="${content:0:50}"
    [[ ${#content} -gt 50 ]] && preview="$preview..."

    echo -e "${GREEN}✓ Added to clipboard history${NC}"
    echo -e "${CYAN}Preview:${NC} $preview"
    [[ -n "$tag" ]] && echo -e "${CYAN}Tag:${NC} $tag"
}

# Show stats
stats() {
    init_data_dir

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                  CLIPBOARD HISTORY STATS                   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    local total=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
    echo -e "${CYAN}Total entries:${NC} $total"
    echo -e "${CYAN}Max entries:${NC} $MAX_ENTRIES"
    echo -e "${CYAN}Data directory:${NC} $DATA_DIR"

    if [[ -f "$HISTORY_FILE" ]]; then
        local size=$(du -h "$HISTORY_FILE" | cut -f1)
        echo -e "${CYAN}History file size:${NC} $size"

        if [[ $total -gt 0 ]]; then
            local oldest=$(tail -1 "$HISTORY_FILE" | cut -d'|' -f2)
            local newest=$(head -1 "$HISTORY_FILE" | cut -d'|' -f2)
            echo -e "${CYAN}Oldest entry:${NC} $oldest"
            echo -e "${CYAN}Newest entry:${NC} $newest"

            # Count tagged entries
            local tagged=$(grep -v '||' "$HISTORY_FILE" | grep -c '|[^|]*|[^|]' || echo 0)
            echo -e "${CYAN}Tagged entries:${NC} $tagged"
        fi
    fi
}

# Show usage
usage() {
    echo -e "${BLUE}clipboard${NC} - Clipboard history manager"
    echo
    echo -e "${YELLOW}USAGE:${NC}"
    echo "    clipboard <command> [options]"
    echo
    echo -e "${YELLOW}COMMANDS:${NC}"
    echo "    save [tag]          Save current clipboard to history"
    echo "    capture [tag]       Alias for save"
    echo "    add [-t tag] <text> Add text directly to history"
    echo "    list [n]            List last n entries (default: 10)"
    echo "    get <n>             Copy entry #n to clipboard"
    echo "    show <n>            Display full content of entry #n"
    echo "    search <term>       Search history by keyword"
    echo "    delete <n>          Delete entry #n"
    echo "    clear               Clear all clipboard history"
    echo "    export [file]       Export history to text file"
    echo "    stats               Show history statistics"
    echo "    help                Show this help message"
    echo
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "    clipboard save                  # Save current clipboard"
    echo "    clipboard save work             # Save with 'work' tag"
    echo "    clipboard list 20               # Show last 20 entries"
    echo "    clipboard get 3                 # Copy 3rd entry to clipboard"
    echo "    clipboard search password       # Search for 'password'"
    echo "    clipboard add 'quick text'      # Add text directly"
    echo "    echo 'data' | clipboard add     # Add from pipe"
    echo
    echo -e "${YELLOW}ENVIRONMENT:${NC}"
    echo "    CLIPBOARD_DATA_DIR      Data directory (default: ~/.local/share/clipboard-history)"
    echo "    CLIPBOARD_MAX_ENTRIES   Max history entries (default: 100)"
}

# Main entry point
main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        save)           save "$@" ;;
        capture)        capture "$@" ;;
        add)            add "$@" ;;
        list|ls)        list "$@" ;;
        get|copy)       get "$@" ;;
        show|view)      show "$@" ;;
        search|find)    search "$@" ;;
        delete|rm)      delete "$@" ;;
        clear)          clear_history ;;
        export)         export_history "$@" ;;
        stats)          stats ;;
        help|--help|-h) usage ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            echo "Run 'clipboard help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
