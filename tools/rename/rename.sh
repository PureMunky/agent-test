#!/bin/bash
#
# rename.sh - Batch file renamer for productivity
# Rename multiple files with patterns, find/replace, numbering, and more
#
# Usage:
#   rename.sh preview <pattern> [dir]       - Preview rename operation
#   rename.sh apply <pattern> [dir]         - Apply rename operation
#   rename.sh replace <find> <replace> [dir] - Find and replace in filenames
#   rename.sh prefix <prefix> [dir]         - Add prefix to filenames
#   rename.sh suffix <suffix> [dir]         - Add suffix (before extension)
#   rename.sh number [dir]                  - Add sequential numbers
#   rename.sh date [dir]                    - Add date prefix
#   rename.sh lower [dir]                   - Convert to lowercase
#   rename.sh upper [dir]                   - Convert to UPPERCASE
#   rename.sh spaces [dir]                  - Replace spaces with underscores
#   rename.sh strip <chars> [dir]           - Remove specific characters
#   rename.sh ext <new-ext> [dir]           - Change file extension
#   rename.sh undo                          - Undo last rename operation
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
HISTORY_FILE="$DATA_DIR/history.json"

mkdir -p "$DATA_DIR"

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

# Check for jq (optional - needed for undo/history)
HAS_JQ=false
if command -v jq &> /dev/null; then
    HAS_JQ=true
    # Initialize history file
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo '{"operations":[]}' > "$HISTORY_FILE"
    fi
fi

# Get files in directory (non-recursive, files only)
get_files() {
    local dir="${1:-.}"
    find "$dir" -maxdepth 1 -type f -not -name '.*' 2>/dev/null | sort
}

# Preview rename operation
preview_rename() {
    local old_name="$1"
    local new_name="$2"

    if [[ "$old_name" != "$new_name" ]]; then
        echo -e "  ${GRAY}$(basename "$old_name")${NC} ${YELLOW}→${NC} ${GREEN}$(basename "$new_name")${NC}"
        return 0
    fi
    return 1
}

# Execute rename with safety checks
safe_rename() {
    local old_path="$1"
    local new_path="$2"

    # Don't rename if names are the same
    if [[ "$old_path" == "$new_path" ]]; then
        return 1
    fi

    # Check if destination already exists
    if [[ -e "$new_path" ]]; then
        echo -e "  ${RED}Skipped:${NC} $(basename "$new_path") already exists"
        return 1
    fi

    mv "$old_path" "$new_path" && return 0 || return 1
}

# Save operation to history for undo
save_to_history() {
    [[ "$HAS_JQ" != "true" ]] && return 0

    local operation_type="$1"
    local moves_json="$2"
    local dir="$3"

    jq --argjson moves "$moves_json" --arg type "$operation_type" --arg dir "$dir" --arg time "$(date -Iseconds)" '
        .operations += [{
            type: $type,
            directory: $dir,
            timestamp: $time,
            moves: $moves
        }]
    ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Find and replace in filenames
cmd_replace() {
    local find_str="$1"
    local replace_str="$2"
    local dir="${3:-.}"
    local dry_run="${4:-true}"

    if [[ -z "$find_str" ]]; then
        echo -e "${RED}Error: Please provide a search string${NC}"
        echo "Usage: rename.sh replace <find> <replace> [directory]"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Replace '$find_str' with '$replace_str' ===${NC}"
    else
        echo -e "${BLUE}=== Replace '$find_str' with '$replace_str' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename="${filename//$find_str/$replace_str}"
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then
                        if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with 'rename.sh replace \"$find_str\" \"$replace_str\" \"$dir\" --apply' to apply"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "replace" "$moves_json" "$dir"
        fi
    fi
}

# Add prefix to filenames
cmd_prefix() {
    local prefix="$1"
    local dir="${2:-.}"
    local dry_run="${3:-true}"

    if [[ -z "$prefix" ]]; then
        echo -e "${RED}Error: Please provide a prefix${NC}"
        echo "Usage: rename.sh prefix <prefix> [directory]"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Add prefix '$prefix' ===${NC}"
    else
        echo -e "${BLUE}=== Add prefix '$prefix' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename="${prefix}${filename}"
        local new_path="$dirname/$new_filename"

        if [[ "$dry_run" == "true" ]]; then
            preview_rename "$file" "$new_path" && ((count++))
        else
            if safe_rename "$file" "$new_path"; then
                echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                ((count++))
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "prefix" "$moves_json" "$dir"
        fi
    fi
}

# Add suffix to filenames (before extension)
cmd_suffix() {
    local suffix="$1"
    local dir="${2:-.}"
    local dry_run="${3:-true}"

    if [[ -z "$suffix" ]]; then
        echo -e "${RED}Error: Please provide a suffix${NC}"
        echo "Usage: rename.sh suffix <suffix> [directory]"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Add suffix '$suffix' ===${NC}"
    else
        echo -e "${BLUE}=== Add suffix '$suffix' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local name="${filename%.*}"
        local ext="${filename##*.}"

        local new_filename
        if [[ "$ext" == "$filename" ]]; then
            # No extension
            new_filename="${name}${suffix}"
        else
            new_filename="${name}${suffix}.${ext}"
        fi
        local new_path="$dirname/$new_filename"

        if [[ "$dry_run" == "true" ]]; then
            preview_rename "$file" "$new_path" && ((count++))
        else
            if safe_rename "$file" "$new_path"; then
                echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                ((count++))
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "suffix" "$moves_json" "$dir"
        fi
    fi
}

# Add sequential numbers to filenames
cmd_number() {
    local dir="${1:-.}"
    local dry_run="${2:-true}"
    local start="${3:-1}"
    local padding="${4:-3}"
    local position="${5:-prefix}"  # prefix or suffix

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Add sequential numbers ===${NC}"
    else
        echo -e "${BLUE}=== Add sequential numbers ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo -e "${GRAY}Start: $start, Padding: $padding digits, Position: $position${NC}"
    echo ""

    local count=0
    local num=$start
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local name="${filename%.*}"
        local ext="${filename##*.}"
        local padded_num=$(printf "%0${padding}d" $num)

        local new_filename
        if [[ "$ext" == "$filename" ]]; then
            if [[ "$position" == "prefix" ]]; then
                new_filename="${padded_num}_${name}"
            else
                new_filename="${name}_${padded_num}"
            fi
        else
            if [[ "$position" == "prefix" ]]; then
                new_filename="${padded_num}_${name}.${ext}"
            else
                new_filename="${name}_${padded_num}.${ext}"
            fi
        fi
        local new_path="$dirname/$new_filename"

        if [[ "$dry_run" == "true" ]]; then
            preview_rename "$file" "$new_path" && ((count++))
        else
            if safe_rename "$file" "$new_path"; then
                echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                ((count++))
            fi
        fi
        ((num++))
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "number" "$moves_json" "$dir"
        fi
    fi
}

# Add date prefix to filenames
cmd_date() {
    local dir="${1:-.}"
    local dry_run="${2:-true}"
    local format="${3:-%Y-%m-%d}"

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Add date prefix ===${NC}"
    else
        echo -e "${BLUE}=== Add date prefix ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo -e "${GRAY}Date format: $format (uses file modification date)${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")

        # Get file modification date
        local file_date
        file_date=$(date -r "$file" +"$format" 2>/dev/null) || \
        file_date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)

        local new_filename="${file_date}_${filename}"
        local new_path="$dirname/$new_filename"

        if [[ "$dry_run" == "true" ]]; then
            preview_rename "$file" "$new_path" && ((count++))
        else
            if safe_rename "$file" "$new_path"; then
                echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                ((count++))
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "date" "$moves_json" "$dir"
        fi
    fi
}

# Convert filenames to lowercase
cmd_lower() {
    local dir="${1:-.}"
    local dry_run="${2:-true}"

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Convert to lowercase ===${NC}"
    else
        echo -e "${BLUE}=== Convert to lowercase ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename="${filename,,}"  # bash lowercase
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "lower" "$moves_json" "$dir"
        fi
    fi
}

# Convert filenames to UPPERCASE
cmd_upper() {
    local dir="${1:-.}"
    local dry_run="${2:-true}"

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Convert to UPPERCASE ===${NC}"
    else
        echo -e "${BLUE}=== Convert to UPPERCASE ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename="${filename^^}"  # bash uppercase
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "upper" "$moves_json" "$dir"
        fi
    fi
}

# Replace spaces with underscores (or other character)
cmd_spaces() {
    local dir="${1:-.}"
    local dry_run="${2:-true}"
    local replacement="${3:-_}"

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Replace spaces with '$replacement' ===${NC}"
    else
        echo -e "${BLUE}=== Replace spaces with '$replacement' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename="${filename// /$replacement}"
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "spaces" "$moves_json" "$dir"
        fi
    fi
}

# Strip specific characters from filenames
cmd_strip() {
    local chars="$1"
    local dir="${2:-.}"
    local dry_run="${3:-true}"

    if [[ -z "$chars" ]]; then
        echo -e "${RED}Error: Please provide characters to strip${NC}"
        echo "Usage: rename.sh strip <chars> [directory]"
        echo "Example: rename.sh strip '()[]' ~/Downloads"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Strip characters '$chars' ===${NC}"
    else
        echo -e "${BLUE}=== Strip characters '$chars' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local new_filename=$(echo "$filename" | tr -d "$chars")
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]] && [[ -n "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "strip" "$moves_json" "$dir"
        fi
    fi
}

# Change file extension
cmd_ext() {
    local new_ext="$1"
    local dir="${2:-.}"
    local dry_run="${3:-true}"

    if [[ -z "$new_ext" ]]; then
        echo -e "${RED}Error: Please provide new extension${NC}"
        echo "Usage: rename.sh ext <new-extension> [directory]"
        echo "Example: rename.sh ext txt ~/Documents"
        exit 1
    fi

    # Remove leading dot if provided
    new_ext="${new_ext#.}"

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Preview: Change extension to '.$new_ext' ===${NC}"
    else
        echo -e "${BLUE}=== Change extension to '.$new_ext' ===${NC}"
    fi
    echo -e "${GRAY}Directory: $dir${NC}"
    echo ""

    local count=0
    local moves_json="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        local name="${filename%.*}"
        local old_ext="${filename##*.}"

        # Skip if file has no extension
        if [[ "$old_ext" == "$filename" ]]; then
            local new_filename="${name}.${new_ext}"
        else
            local new_filename="${name}.${new_ext}"
        fi
        local new_path="$dirname/$new_filename"

        if [[ "$filename" != "$new_filename" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                preview_rename "$file" "$new_path" && ((count++))
            else
                if safe_rename "$file" "$new_path"; then
                    echo -e "  ${GREEN}Renamed:${NC} $filename → $new_filename"
                    if [[ "$HAS_JQ" == "true" ]]; then moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$new_path" '. + [{from: $from, to: $to}]'); fi
                    ((count++))
                fi
            fi
        fi
    done < <(get_files "$dir")

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No files to rename."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would rename $count file(s)${NC}"
            echo ""
            echo "Run with '--apply' to apply changes"
        else
            echo -e "${GREEN}Renamed $count file(s)${NC}"
            save_to_history "ext" "$moves_json" "$dir"
        fi
    fi
}

# Undo last rename operation
cmd_undo() {
    if [[ "$HAS_JQ" != "true" ]]; then
        echo -e "${RED}Error: undo requires jq. Install with: sudo apt install jq${NC}"
        exit 1
    fi

    local last_op=$(jq -r '.operations | last' "$HISTORY_FILE")

    if [[ -z "$last_op" ]] || [[ "$last_op" == "null" ]]; then
        echo "No operations to undo."
        exit 0
    fi

    local op_type=$(echo "$last_op" | jq -r '.type')
    local op_time=$(echo "$last_op" | jq -r '.timestamp')
    local op_dir=$(echo "$last_op" | jq -r '.directory')
    local move_count=$(echo "$last_op" | jq '.moves | length')

    echo -e "${BLUE}=== Undo Last Rename Operation ===${NC}"
    echo ""
    echo -e "${CYAN}Type:${NC} $op_type"
    echo -e "${CYAN}Time:${NC} $op_time"
    echo -e "${CYAN}Directory:${NC} $op_dir"
    echo -e "${CYAN}Files:${NC} $move_count"
    echo ""

    read -p "Undo this operation? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    local undo_count=0

    echo "$last_op" | jq -r '.moves[] | "\(.to)|\(.from)"' | while IFS='|' read -r current_path original_path; do
        if [[ -f "$current_path" ]]; then
            mv "$current_path" "$original_path" 2>/dev/null && {
                echo -e "  ${GREEN}Restored:${NC} $(basename "$original_path")"
                ((undo_count++))
            }
        else
            echo -e "  ${YELLOW}Skipped (not found):${NC} $(basename "$current_path")"
        fi
    done

    # Remove from history
    jq '.operations = .operations[:-1]' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

    echo ""
    echo -e "${GREEN}Undo complete.${NC}"
}

# Show operation history
cmd_history() {
    if [[ "$HAS_JQ" != "true" ]]; then
        echo -e "${RED}Error: history requires jq. Install with: sudo apt install jq${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Rename History ===${NC}"
    echo ""

    local count=$(jq '.operations | length' "$HISTORY_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No operations recorded."
        exit 0
    fi

    jq -r '.operations | reverse | .[0:10] | .[] | "\(.timestamp)|\(.type)|\(.directory)|\(.moves | length)"' "$HISTORY_FILE" | \
    while IFS='|' read -r timestamp type dir moves; do
        local time_short=$(echo "$timestamp" | cut -dT -f1,2 | tr 'T' ' ')
        echo -e "  ${CYAN}$time_short${NC}"
        echo -e "    ${YELLOW}$type${NC} - $moves file(s)"
        echo -e "    ${GRAY}$dir${NC}"
        echo ""
    done

    echo -e "${GRAY}Total: $count operation(s) in history${NC}"
}

# Show help
show_help() {
    echo "Batch File Renamer - Rename multiple files with patterns"
    echo ""
    echo "Usage:"
    echo "  rename.sh <command> [options] [directory]"
    echo ""
    echo "Commands:"
    echo "  replace <find> <replace>    Find and replace in filenames"
    echo "  prefix <prefix>             Add prefix to all filenames"
    echo "  suffix <suffix>             Add suffix before extension"
    echo "  number                      Add sequential numbers (001_, 002_, ...)"
    echo "  date                        Add date prefix from file modification date"
    echo "  lower                       Convert filenames to lowercase"
    echo "  upper                       Convert filenames to UPPERCASE"
    echo "  spaces                      Replace spaces with underscores"
    echo "  strip <chars>               Remove specific characters"
    echo "  ext <new-ext>               Change file extension"
    echo "  undo                        Undo last rename operation"
    echo "  history                     Show rename history"
    echo "  help                        Show this help"
    echo ""
    echo "Options:"
    echo "  --apply                     Apply changes (default is preview/dry-run)"
    echo "  --start <n>                 Starting number for 'number' command"
    echo "  --padding <n>               Digit padding for 'number' (default: 3)"
    echo "  --position <prefix|suffix>  Number position (default: prefix)"
    echo "  --format <fmt>              Date format for 'date' command"
    echo "  --char <c>                  Replacement character for 'spaces'"
    echo ""
    echo "Examples:"
    echo "  rename.sh replace 'IMG_' 'photo_' ~/Photos"
    echo "  rename.sh replace 'IMG_' 'photo_' ~/Photos --apply"
    echo "  rename.sh prefix 'backup_' ~/Documents"
    echo "  rename.sh number ~/Photos --start 1 --padding 4"
    echo "  rename.sh lower ~/Downloads --apply"
    echo "  rename.sh strip '()[]' ~/Downloads"
    echo "  rename.sh ext jpg ~/Images --apply"
    echo "  rename.sh undo"
    echo ""
    echo "Note: All commands run in preview mode by default."
    echo "      Add --apply to actually rename files."
}

# Parse arguments and execute
main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    # Parse common flags
    local apply=false
    local args=()
    local start=1
    local padding=3
    local position="prefix"
    local format="%Y-%m-%d"
    local replacement="_"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apply|-a)
                apply=true
                ;;
            --start)
                start="$2"
                shift
                ;;
            --padding)
                padding="$2"
                shift
                ;;
            --position)
                position="$2"
                shift
                ;;
            --format)
                format="$2"
                shift
                ;;
            --char)
                replacement="$2"
                shift
                ;;
            *)
                args+=("$1")
                ;;
        esac
        shift
    done

    local dry_run="true"
    [[ "$apply" == "true" ]] && dry_run="false"

    case "$cmd" in
        replace)
            cmd_replace "${args[0]}" "${args[1]}" "${args[2]:-.}" "$dry_run"
            ;;
        prefix)
            cmd_prefix "${args[0]}" "${args[1]:-.}" "$dry_run"
            ;;
        suffix)
            cmd_suffix "${args[0]}" "${args[1]:-.}" "$dry_run"
            ;;
        number|num)
            cmd_number "${args[0]:-.}" "$dry_run" "$start" "$padding" "$position"
            ;;
        date)
            cmd_date "${args[0]:-.}" "$dry_run" "$format"
            ;;
        lower|lowercase)
            cmd_lower "${args[0]:-.}" "$dry_run"
            ;;
        upper|uppercase)
            cmd_upper "${args[0]:-.}" "$dry_run"
            ;;
        spaces)
            cmd_spaces "${args[0]:-.}" "$dry_run" "$replacement"
            ;;
        strip)
            cmd_strip "${args[0]}" "${args[1]:-.}" "$dry_run"
            ;;
        ext|extension)
            cmd_ext "${args[0]}" "${args[1]:-.}" "$dry_run"
            ;;
        undo)
            cmd_undo
            ;;
        history|hist)
            cmd_history
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            echo "Run 'rename.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
