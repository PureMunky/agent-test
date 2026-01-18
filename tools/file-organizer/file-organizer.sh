#!/bin/bash
#
# File Organizer - Organize files by type, date, or custom rules
#
# Usage:
#   file-organizer.sh scan [directory]              - Scan and report file types
#   file-organizer.sh organize [directory]          - Organize files by type
#   file-organizer.sh by-date [directory]           - Organize files by date
#   file-organizer.sh cleanup [directory]           - Find duplicates and empty files
#   file-organizer.sh rules                         - Show/edit organization rules
#   file-organizer.sh undo                          - Undo last organization
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
RULES_FILE="$DATA_DIR/rules.json"
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

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Initialize rules file with defaults
if [[ ! -f "$RULES_FILE" ]]; then
    cat > "$RULES_FILE" << 'EOF'
{
    "categories": {
        "Images": ["jpg", "jpeg", "png", "gif", "bmp", "svg", "webp", "ico", "tiff", "raw", "heic"],
        "Documents": ["pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx", "ppt", "pptx", "csv"],
        "Videos": ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "m4v", "mpeg"],
        "Audio": ["mp3", "wav", "flac", "aac", "ogg", "wma", "m4a", "opus"],
        "Archives": ["zip", "tar", "gz", "rar", "7z", "bz2", "xz", "tgz"],
        "Code": ["py", "js", "ts", "java", "c", "cpp", "h", "go", "rs", "rb", "php", "sh", "bash"],
        "Data": ["json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf"],
        "Executables": ["exe", "msi", "dmg", "app", "deb", "rpm", "AppImage"],
        "Fonts": ["ttf", "otf", "woff", "woff2", "eot"]
    },
    "ignore_patterns": [
        ".*",
        "node_modules",
        "__pycache__",
        ".git"
    ]
}
EOF
fi

# Initialize history file
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"operations":[]}' > "$HISTORY_FILE"
fi

# Get category for file extension
get_category() {
    local ext="$1"
    ext="${ext,,}"  # lowercase

    local category=$(jq -r --arg ext "$ext" '
        .categories | to_entries | map(select(.value | index($ext))) | .[0].key // "Other"
    ' "$RULES_FILE")

    echo "$category"
}

# Check if path should be ignored
should_ignore() {
    local name="$1"
    local patterns=$(jq -r '.ignore_patterns[]' "$RULES_FILE")

    while IFS= read -r pattern; do
        if [[ "$name" == $pattern ]] || [[ "$name" == .$pattern ]]; then
            return 0
        fi
    done <<< "$patterns"

    return 1
}

# Scan directory and report
scan_directory() {
    local dir="${1:-.}"

    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Directory not found:${NC} $dir"
        exit 1
    fi

    dir=$(realpath "$dir")
    echo -e "${BLUE}=== File Scan: $dir ===${NC}"
    echo ""

    declare -A category_counts
    declare -A category_sizes
    local total_files=0
    local total_size=0

    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")

        # Skip ignored patterns
        if should_ignore "$filename"; then
            continue
        fi

        # Get extension
        local ext="${filename##*.}"
        if [[ "$ext" == "$filename" ]]; then
            ext=""
        fi

        local category=$(get_category "$ext")
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)

        category_counts["$category"]=$((${category_counts["$category"]:-0} + 1))
        category_sizes["$category"]=$((${category_sizes["$category"]:-0} + size))
        total_files=$((total_files + 1))
        total_size=$((total_size + size))
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)

    if [[ $total_files -eq 0 ]]; then
        echo "No files found in directory."
        exit 0
    fi

    echo -e "${YELLOW}Files by Category:${NC}"
    echo ""

    # Sort categories by count
    for category in "${!category_counts[@]}"; do
        local count=${category_counts[$category]}
        local size=${category_sizes[$category]}
        local size_human=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")

        printf "  ${GREEN}%-15s${NC} %4d files  ${GRAY}(%s)${NC}\n" "$category" "$count" "$size_human"
    done

    echo ""
    local total_size_human=$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "${total_size}B")
    echo -e "${CYAN}Total:${NC} $total_files files ($total_size_human)"

    # Show subdirectories
    local subdir_count=$(find "$dir" -maxdepth 1 -type d ! -path "$dir" 2>/dev/null | wc -l)
    if [[ $subdir_count -gt 0 ]]; then
        echo ""
        echo -e "${GRAY}+ $subdir_count subdirectories${NC}"
    fi
}

# Organize files by type
organize_by_type() {
    local dir="${1:-.}"
    local dry_run="${2:-false}"

    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Directory not found:${NC} $dir"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Dry Run: Organize by Type ===${NC}"
    else
        echo -e "${BLUE}=== Organizing by Type: $dir ===${NC}"
    fi
    echo ""

    declare -A moves
    local move_count=0

    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")

        # Skip ignored patterns
        if should_ignore "$filename"; then
            continue
        fi

        # Get extension and category
        local ext="${filename##*.}"
        if [[ "$ext" == "$filename" ]]; then
            ext=""
        fi

        local category=$(get_category "$ext")
        local dest_dir="$dir/$category"
        local dest_file="$dest_dir/$filename"

        # Skip if already in correct location
        if [[ "$(dirname "$file")" == "$dest_dir" ]]; then
            continue
        fi

        # Handle filename conflicts
        if [[ -e "$dest_file" ]]; then
            local base="${filename%.*}"
            local counter=1
            while [[ -e "$dest_dir/${base}_$counter.$ext" ]]; do
                ((counter++))
            done
            if [[ -n "$ext" ]]; then
                dest_file="$dest_dir/${base}_$counter.$ext"
            else
                dest_file="$dest_dir/${filename}_$counter"
            fi
        fi

        if [[ "$dry_run" == "true" ]]; then
            echo -e "  ${GRAY}$filename${NC} -> ${GREEN}$category/${NC}"
        else
            mkdir -p "$dest_dir"
            mv "$file" "$dest_file"
            echo -e "  ${GREEN}Moved:${NC} $filename -> $category/"

            # Record for undo
            moves["$dest_file"]="$file"
        fi

        ((move_count++))
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)

    echo ""
    if [[ $move_count -eq 0 ]]; then
        echo "No files to organize."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would move $move_count file(s)${NC}"
            echo ""
            echo "Run without --dry-run to apply changes."
        else
            echo -e "${GREEN}Organized $move_count file(s)${NC}"

            # Save to history for undo
            local history_entry=$(jq -n --argjson moves "$(declare -p moves | sed "s/declare -A moves=//" | sed 's/(/[/g' | sed 's/)/]/g' | sed 's/\[/{"moves":{/g' | sed 's/\]/}}/g' | sed 's/\] /,/g')" \
                --arg dir "$dir" --arg time "$(date -Iseconds)" \
                '{type: "organize_by_type", directory: $dir, timestamp: $time, moves: []}')

            # Build proper moves array
            local moves_json="["
            local first=true
            for dest in "${!moves[@]}"; do
                local src="${moves[$dest]}"
                if [[ "$first" != "true" ]]; then
                    moves_json+=","
                fi
                moves_json+="{\"from\":\"$src\",\"to\":\"$dest\"}"
                first=false
            done
            moves_json+="]"

            jq --argjson moves "$moves_json" --arg dir "$dir" --arg time "$(date -Iseconds)" '
                .operations += [{
                    type: "organize_by_type",
                    directory: $dir,
                    timestamp: $time,
                    moves: $moves
                }]
            ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        fi
    fi
}

# Organize files by date
organize_by_date() {
    local dir="${1:-.}"
    local dry_run="${2:-false}"

    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Directory not found:${NC} $dir"
        exit 1
    fi

    dir=$(realpath "$dir")

    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}=== Dry Run: Organize by Date ===${NC}"
    else
        echo -e "${BLUE}=== Organizing by Date: $dir ===${NC}"
    fi
    echo ""

    local move_count=0
    local moves_json="[]"

    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")

        # Skip ignored patterns
        if should_ignore "$filename"; then
            continue
        fi

        # Get file modification date
        local file_date=$(stat -f%Sm -t%Y-%m "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d'-' -f1-2)
        local year=$(echo "$file_date" | cut -d'-' -f1)
        local month=$(echo "$file_date" | cut -d'-' -f2)

        local dest_dir="$dir/$year/$month"
        local dest_file="$dest_dir/$filename"

        # Skip if already in correct location
        if [[ "$(dirname "$file")" == "$dest_dir" ]]; then
            continue
        fi

        # Handle filename conflicts
        if [[ -e "$dest_file" ]]; then
            local base="${filename%.*}"
            local ext="${filename##*.}"
            local counter=1
            while [[ -e "$dest_dir/${base}_$counter.$ext" ]]; do
                ((counter++))
            done
            if [[ "$ext" != "$filename" ]]; then
                dest_file="$dest_dir/${base}_$counter.$ext"
            else
                dest_file="$dest_dir/${filename}_$counter"
            fi
        fi

        if [[ "$dry_run" == "true" ]]; then
            echo -e "  ${GRAY}$filename${NC} -> ${GREEN}$year/$month/${NC}"
        else
            mkdir -p "$dest_dir"
            mv "$file" "$dest_file"
            echo -e "  ${GREEN}Moved:${NC} $filename -> $year/$month/"

            moves_json=$(echo "$moves_json" | jq --arg from "$file" --arg to "$dest_file" '. + [{from: $from, to: $to}]')
        fi

        ((move_count++))
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)

    echo ""
    if [[ $move_count -eq 0 ]]; then
        echo "No files to organize."
    else
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${CYAN}Would move $move_count file(s)${NC}"
            echo ""
            echo "Run without --dry-run to apply changes."
        else
            echo -e "${GREEN}Organized $move_count file(s)${NC}"

            # Save to history
            jq --argjson moves "$moves_json" --arg dir "$dir" --arg time "$(date -Iseconds)" '
                .operations += [{
                    type: "organize_by_date",
                    directory: $dir,
                    timestamp: $time,
                    moves: $moves
                }]
            ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        fi
    fi
}

# Find duplicates and empty files
cleanup_scan() {
    local dir="${1:-.}"

    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Directory not found:${NC} $dir"
        exit 1
    fi

    dir=$(realpath "$dir")
    echo -e "${BLUE}=== Cleanup Scan: $dir ===${NC}"
    echo ""

    # Find empty files
    echo -e "${YELLOW}Empty Files:${NC}"
    local empty_count=0
    while IFS= read -r -d '' file; do
        echo -e "  ${GRAY}$(basename "$file")${NC}"
        ((empty_count++))
    done < <(find "$dir" -maxdepth 2 -type f -empty -print0 2>/dev/null)

    if [[ $empty_count -eq 0 ]]; then
        echo "  None found"
    else
        echo ""
        echo -e "  ${CYAN}Found $empty_count empty file(s)${NC}"
    fi

    echo ""

    # Find potential duplicates (same size)
    echo -e "${YELLOW}Potential Duplicates (same size):${NC}"
    local dup_groups=0

    # Group files by size
    declare -A size_files
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        if should_ignore "$filename"; then
            continue
        fi
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        if [[ $size -gt 0 ]]; then
            size_files["$size"]+="$file"$'\n'
        fi
    done < <(find "$dir" -maxdepth 2 -type f -print0 2>/dev/null)

    for size in "${!size_files[@]}"; do
        local files="${size_files[$size]}"
        local count=$(echo -n "$files" | grep -c '^')

        if [[ $count -gt 1 ]]; then
            local size_human=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")
            echo -e "  ${MAGENTA}Size: $size_human${NC}"
            echo -n "$files" | head -5 | while read -r f; do
                if [[ -n "$f" ]]; then
                    echo -e "    ${GRAY}$(basename "$f")${NC}"
                fi
            done
            if [[ $count -gt 5 ]]; then
                echo -e "    ${GRAY}... and $((count - 5)) more${NC}"
            fi
            echo ""
            ((dup_groups++))
        fi
    done

    if [[ $dup_groups -eq 0 ]]; then
        echo "  No potential duplicates found"
    else
        echo -e "  ${CYAN}Found $dup_groups group(s) of potential duplicates${NC}"
        echo ""
        echo -e "${GRAY}Note: Files with same size may not be true duplicates.${NC}"
        echo -e "${GRAY}Use 'md5sum' or similar to verify before deleting.${NC}"
    fi

    echo ""

    # Find large files
    echo -e "${YELLOW}Largest Files:${NC}"
    find "$dir" -maxdepth 2 -type f -print0 2>/dev/null | \
        xargs -0 stat -f '%z %N' 2>/dev/null | sort -rn | head -5 | \
        while read -r size filepath; do
            local size_human=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")
            local fname=$(basename "$filepath")
            printf "  ${GRAY}%-10s${NC} %s\n" "$size_human" "$fname"
        done 2>/dev/null || \
    find "$dir" -maxdepth 2 -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -5 | \
        while read -r size filepath; do
            local size_human=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")
            local fname=$(basename "$filepath")
            printf "  ${GRAY}%-10s${NC} %s\n" "$size_human" "$fname"
        done
}

# Show or edit rules
show_rules() {
    echo -e "${BLUE}=== Organization Rules ===${NC}"
    echo ""
    echo -e "${CYAN}Rules file:${NC} $RULES_FILE"
    echo ""

    echo -e "${YELLOW}Categories:${NC}"
    jq -r '.categories | to_entries[] | "  \(.key): \(.value | join(", "))"' "$RULES_FILE"

    echo ""
    echo -e "${YELLOW}Ignored patterns:${NC}"
    jq -r '.ignore_patterns[]' "$RULES_FILE" | while read -r pattern; do
        echo "  - $pattern"
    done

    echo ""
    echo -e "${GRAY}Edit with: ${NC}${EDITOR:-nano} $RULES_FILE"
}

# Undo last operation
undo_last() {
    local last_op=$(jq -r '.operations | last' "$HISTORY_FILE")

    if [[ -z "$last_op" ]] || [[ "$last_op" == "null" ]]; then
        echo "No operations to undo."
        exit 0
    fi

    local op_type=$(echo "$last_op" | jq -r '.type')
    local op_time=$(echo "$last_op" | jq -r '.timestamp')
    local op_dir=$(echo "$last_op" | jq -r '.directory')

    echo -e "${BLUE}=== Undo Last Operation ===${NC}"
    echo ""
    echo -e "${CYAN}Type:${NC} $op_type"
    echo -e "${CYAN}Time:${NC} $op_time"
    echo -e "${CYAN}Directory:${NC} $op_dir"
    echo ""

    read -p "Undo this operation? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    local undo_count=0

    echo "$last_op" | jq -r '.moves[] | "\(.from)|\(.to)"' | while IFS='|' read -r from to; do
        if [[ -f "$to" ]]; then
            local from_dir=$(dirname "$from")
            mkdir -p "$from_dir"
            mv "$to" "$from"
            echo -e "  ${GREEN}Restored:${NC} $(basename "$from")"
            ((undo_count++))
        else
            echo -e "  ${YELLOW}Skipped (not found):${NC} $(basename "$to")"
        fi
    done

    # Remove empty directories created by organize
    echo "$last_op" | jq -r '.moves[].to' | while read -r to; do
        local parent=$(dirname "$to")
        if [[ -d "$parent" ]] && [[ -z "$(ls -A "$parent" 2>/dev/null)" ]]; then
            rmdir "$parent" 2>/dev/null && echo -e "  ${GRAY}Removed empty:${NC} $(basename "$parent")/"
        fi
    done

    # Remove from history
    jq '.operations = .operations[:-1]' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

    echo ""
    echo -e "${GREEN}Undo complete.${NC}"
}

# Show history
show_history() {
    echo -e "${BLUE}=== Operation History ===${NC}"
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

show_help() {
    echo "File Organizer - Organize files by type, date, or custom rules"
    echo ""
    echo "Usage:"
    echo "  file-organizer.sh scan [dir]            Scan and report file types"
    echo "  file-organizer.sh organize [dir]        Organize files by type"
    echo "  file-organizer.sh by-date [dir]         Organize files by date (YYYY/MM)"
    echo "  file-organizer.sh cleanup [dir]         Find duplicates and empty files"
    echo "  file-organizer.sh rules                 Show organization rules"
    echo "  file-organizer.sh undo                  Undo last organization"
    echo "  file-organizer.sh history               Show operation history"
    echo "  file-organizer.sh help                  Show this help"
    echo ""
    echo "Options:"
    echo "  --dry-run                               Preview changes without applying"
    echo ""
    echo "Examples:"
    echo "  file-organizer.sh scan ~/Downloads"
    echo "  file-organizer.sh organize ~/Downloads --dry-run"
    echo "  file-organizer.sh organize ~/Downloads"
    echo "  file-organizer.sh by-date ~/Photos"
    echo "  file-organizer.sh undo"
}

# Parse arguments
case "$1" in
    scan)
        scan_directory "$2"
        ;;
    organize|by-type)
        dry_run="false"
        dir="$2"
        if [[ "$2" == "--dry-run" ]]; then
            dry_run="true"
            dir="${3:-.}"
        elif [[ "$3" == "--dry-run" ]]; then
            dry_run="true"
        fi
        organize_by_type "$dir" "$dry_run"
        ;;
    by-date|date)
        dry_run="false"
        dir="$2"
        if [[ "$2" == "--dry-run" ]]; then
            dry_run="true"
            dir="${3:-.}"
        elif [[ "$3" == "--dry-run" ]]; then
            dry_run="true"
        fi
        organize_by_date "$dir" "$dry_run"
        ;;
    cleanup|clean)
        cleanup_scan "$2"
        ;;
    rules)
        show_rules
        ;;
    undo)
        undo_last
        ;;
    history|hist)
        show_history
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'file-organizer.sh help' for usage"
        exit 1
        ;;
esac
