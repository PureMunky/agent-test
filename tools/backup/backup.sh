#!/bin/bash
#
# Backup - Simple backup utility for important files and directories
#
# Usage:
#   backup.sh add <path>              - Add a path to backup list
#   backup.sh remove <id>             - Remove a path from backup list
#   backup.sh list                    - Show all backup sources
#   backup.sh run [name]              - Create a backup (optional custom name)
#   backup.sh restore <backup-id>     - Restore from a backup
#   backup.sh history                 - Show backup history
#   backup.sh prune [days]            - Remove backups older than N days (default: 30)
#   backup.sh suite                   - Backup all productivity suite data
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
SOURCES_FILE="$DATA_DIR/sources.json"
HISTORY_FILE="$DATA_DIR/history.json"
BACKUP_DIR="$DATA_DIR/backups"
SUITE_DIR="$(dirname "$SCRIPT_DIR")"

mkdir -p "$DATA_DIR" "$BACKUP_DIR"

# Initialize files if they don't exist
if [[ ! -f "$SOURCES_FILE" ]]; then
    echo '{"sources":[],"next_id":1}' > "$SOURCES_FILE"
fi

if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"backups":[]}' > "$HISTORY_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required. Install with: sudo apt install jq${NC}"
    exit 1
fi

# Human-readable file size
human_size() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

add_source() {
    local path="$1"

    if [[ -z "$path" ]]; then
        echo "Usage: backup.sh add <path>"
        exit 1
    fi

    # Expand to absolute path
    if [[ "$path" != /* ]]; then
        path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")"
    fi

    # Check if path exists
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        exit 1
    fi

    # Check if already added
    local exists=$(jq --arg path "$path" '.sources | map(select(.path == $path)) | length' "$SOURCES_FILE")
    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Path already in backup list: $path${NC}"
        exit 0
    fi

    local next_id=$(jq -r '.next_id' "$SOURCES_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    local type="file"
    [[ -d "$path" ]] && type="directory"

    jq --arg path "$path" --arg ts "$timestamp" --argjson id "$next_id" --arg type "$type" '
        .sources += [{
            "id": $id,
            "path": $path,
            "type": $type,
            "added": $ts
        }] |
        .next_id = ($id + 1)
    ' "$SOURCES_FILE" > "$SOURCES_FILE.tmp" && mv "$SOURCES_FILE.tmp" "$SOURCES_FILE"

    echo -e "${GREEN}Added to backup list:${NC} $path ($type)"
}

remove_source() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: backup.sh remove <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.sources | map(select(.id == $id)) | length' "$SOURCES_FILE")
    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Source #$id not found${NC}"
        exit 1
    fi

    local path=$(jq -r --argjson id "$id" '.sources[] | select(.id == $id) | .path' "$SOURCES_FILE")

    jq --argjson id "$id" '.sources = [.sources[] | select(.id != $id)]' "$SOURCES_FILE" > "$SOURCES_FILE.tmp" && mv "$SOURCES_FILE.tmp" "$SOURCES_FILE"

    echo -e "${GREEN}Removed from backup list:${NC} $path"
}

list_sources() {
    echo -e "${BLUE}=== Backup Sources ===${NC}"
    echo ""

    local count=$(jq '.sources | length' "$SOURCES_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No backup sources configured."
        echo ""
        echo "Add sources with: backup.sh add <path>"
        echo "Or backup entire suite: backup.sh suite"
        exit 0
    fi

    echo -e "${CYAN}Configured sources ($count):${NC}"
    jq -r '.sources[] | "  [\(.id)] \(.type | if . == "directory" then "📁" else "📄" end) \(.path)"' "$SOURCES_FILE"
    echo ""
}

run_backup() {
    local backup_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local backup_path="$BACKUP_DIR/$backup_name.tar.gz"

    # Check if we have sources
    local count=$(jq '.sources | length' "$SOURCES_FILE")
    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No backup sources configured.${NC}"
        echo "Add sources with: backup.sh add <path>"
        exit 1
    fi

    echo -e "${BLUE}=== Creating Backup ===${NC}"
    echo ""
    echo -e "Backup name: ${CYAN}$backup_name${NC}"
    echo ""

    # Create temp file list
    local temp_list=$(mktemp)
    local missing_count=0

    # Get all source paths
    while IFS= read -r path; do
        if [[ -e "$path" ]]; then
            echo "$path" >> "$temp_list"
            echo -e "  ${GREEN}✓${NC} $path"
        else
            echo -e "  ${RED}✗${NC} $path (missing)"
            ((missing_count++))
        fi
    done < <(jq -r '.sources[].path' "$SOURCES_FILE")

    if [[ ! -s "$temp_list" ]]; then
        echo -e "${RED}No valid sources to backup.${NC}"
        rm -f "$temp_list"
        exit 1
    fi

    echo ""

    # Create backup archive
    if tar -czf "$backup_path" -T "$temp_list" 2>/dev/null; then
        local size=$(stat -c%s "$backup_path" 2>/dev/null || stat -f%z "$backup_path" 2>/dev/null)
        local human=$(human_size $size)

        # Record in history
        local backup_id=$(date +%s)
        jq --arg name "$backup_name" --arg ts "$timestamp" --arg path "$backup_path" --argjson size "$size" --argjson id "$backup_id" '
            .backups += [{
                "id": $id,
                "name": $name,
                "timestamp": $ts,
                "path": $path,
                "size": $size
            }]
        ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

        echo -e "${GREEN}Backup created successfully!${NC}"
        echo -e "  Location: ${CYAN}$backup_path${NC}"
        echo -e "  Size: ${CYAN}$human${NC}"

        if [[ $missing_count -gt 0 ]]; then
            echo -e "  ${YELLOW}Warning: $missing_count source(s) were missing${NC}"
        fi
    else
        echo -e "${RED}Failed to create backup archive${NC}"
        rm -f "$temp_list"
        exit 1
    fi

    rm -f "$temp_list"
}

restore_backup() {
    local backup_id="$1"

    if [[ -z "$backup_id" ]]; then
        echo "Usage: backup.sh restore <backup-id>"
        echo ""
        echo "Use 'backup.sh history' to see available backups"
        exit 1
    fi

    # Find backup by ID
    local backup_path=$(jq -r --argjson id "$backup_id" '.backups[] | select(.id == $id) | .path' "$HISTORY_FILE")

    if [[ -z "$backup_path" || "$backup_path" == "null" ]]; then
        echo -e "${RED}Backup #$backup_id not found${NC}"
        echo "Use 'backup.sh history' to see available backups"
        exit 1
    fi

    if [[ ! -f "$backup_path" ]]; then
        echo -e "${RED}Backup file not found: $backup_path${NC}"
        exit 1
    fi

    local backup_name=$(jq -r --argjson id "$backup_id" '.backups[] | select(.id == $id) | .name' "$HISTORY_FILE")

    echo -e "${BLUE}=== Restore Backup ===${NC}"
    echo ""
    echo -e "Backup: ${CYAN}$backup_name${NC}"
    echo -e "File: ${CYAN}$backup_path${NC}"
    echo ""

    echo -e "${YELLOW}Warning: This will overwrite existing files.${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi

    echo ""
    echo "Restoring files..."

    if tar -xzf "$backup_path" -C / 2>/dev/null; then
        echo -e "${GREEN}Restore completed successfully!${NC}"
    else
        echo -e "${RED}Restore failed. Some files may not have been restored.${NC}"
        exit 1
    fi
}

show_history() {
    echo -e "${BLUE}=== Backup History ===${NC}"
    echo ""

    local count=$(jq '.backups | length' "$HISTORY_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No backups yet. Create one with: backup.sh run"
        exit 0
    fi

    echo -e "${CYAN}Available backups ($count):${NC}"
    echo ""

    jq -r '.backups | sort_by(.id) | reverse | .[] | "\(.id)|\(.name)|\(.timestamp)|\(.size)"' "$HISTORY_FILE" | while IFS='|' read -r id name ts size; do
        local human=$(human_size $size)
        local exists=""
        local path=$(jq -r --argjson id "$id" '.backups[] | select(.id == $id) | .path' "$HISTORY_FILE")
        [[ ! -f "$path" ]] && exists=" ${RED}(missing)${NC}"
        echo -e "  [${CYAN}$id${NC}] $name"
        echo -e "      ${GRAY}$ts - $human$exists${NC}"
    done
}

prune_backups() {
    local days=${1:-30}
    local cutoff=$(date -d "$days days ago" +%s 2>/dev/null || date -v-${days}d +%s 2>/dev/null)

    if [[ -z "$cutoff" ]]; then
        echo -e "${RED}Error calculating date cutoff${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Prune Backups ===${NC}"
    echo ""
    echo -e "Removing backups older than ${CYAN}$days days${NC}..."
    echo ""

    local removed=0
    local freed=0

    # Find old backups
    while IFS='|' read -r id path size; do
        if [[ "$id" -lt "$cutoff" ]]; then
            local name=$(jq -r --argjson id "$id" '.backups[] | select(.id == $id) | .name' "$HISTORY_FILE")

            # Remove file
            if [[ -f "$path" ]]; then
                rm -f "$path"
                ((freed += size))
            fi

            # Remove from history
            jq --argjson id "$id" '.backups = [.backups[] | select(.id != $id)]' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

            echo -e "  ${RED}✗${NC} Removed: $name"
            ((removed++))
        fi
    done < <(jq -r '.backups[] | "\(.id)|\(.path)|\(.size)"' "$HISTORY_FILE")

    if [[ $removed -eq 0 ]]; then
        echo "No backups to prune."
    else
        local human=$(human_size $freed)
        echo ""
        echo -e "${GREEN}Removed $removed backup(s), freed $human${NC}"
    fi
}

backup_suite() {
    echo -e "${BLUE}=== Backup Productivity Suite ===${NC}"
    echo ""
    echo "This will backup all data from the productivity suite tools."
    echo ""

    local backup_name="suite-$(date +%Y%m%d-%H%M%S)"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local backup_path="$BACKUP_DIR/$backup_name.tar.gz"
    local temp_list=$(mktemp)
    local tool_count=0

    # Find all data directories in the suite
    for tool_dir in "$SUITE_DIR"/*/; do
        local tool_name=$(basename "$tool_dir")
        local data_path="$tool_dir/data"

        if [[ -d "$data_path" && "$tool_name" != "backup" ]]; then
            echo "$data_path" >> "$temp_list"
            echo -e "  ${GREEN}✓${NC} $tool_name/data"
            ((tool_count++))
        fi
    done

    if [[ $tool_count -eq 0 ]]; then
        echo "No tool data found to backup."
        rm -f "$temp_list"
        exit 0
    fi

    echo ""
    echo -e "Found data in ${CYAN}$tool_count${NC} tools."
    echo ""

    # Create backup archive
    if tar -czf "$backup_path" -T "$temp_list" 2>/dev/null; then
        local size=$(stat -c%s "$backup_path" 2>/dev/null || stat -f%z "$backup_path" 2>/dev/null)
        local human=$(human_size $size)

        # Record in history
        local backup_id=$(date +%s)
        jq --arg name "$backup_name" --arg ts "$timestamp" --arg path "$backup_path" --argjson size "$size" --argjson id "$backup_id" '
            .backups += [{
                "id": $id,
                "name": $name,
                "timestamp": $ts,
                "path": $path,
                "size": $size,
                "type": "suite"
            }]
        ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

        echo -e "${GREEN}Suite backup created successfully!${NC}"
        echo -e "  Location: ${CYAN}$backup_path${NC}"
        echo -e "  Size: ${CYAN}$human${NC}"
    else
        echo -e "${RED}Failed to create backup archive${NC}"
        rm -f "$temp_list"
        exit 1
    fi

    rm -f "$temp_list"
}

show_help() {
    echo "Backup - Simple backup utility for files and directories"
    echo ""
    echo "Usage:"
    echo "  backup.sh add <path>             Add a path to backup list"
    echo "  backup.sh remove <id>            Remove a path from backup list"
    echo "  backup.sh list                   Show all backup sources"
    echo "  backup.sh run [name]             Create a backup (optional custom name)"
    echo "  backup.sh restore <backup-id>    Restore from a backup"
    echo "  backup.sh history                Show backup history"
    echo "  backup.sh prune [days]           Remove backups older than N days (default: 30)"
    echo "  backup.sh suite                  Backup all productivity suite data"
    echo "  backup.sh help                   Show this help"
    echo ""
    echo "Examples:"
    echo "  backup.sh add ~/.bashrc          Add bashrc to backup sources"
    echo "  backup.sh add ~/Documents        Add Documents folder"
    echo "  backup.sh run weekly-backup      Create named backup"
    echo "  backup.sh suite                  Backup all tool data"
    echo "  backup.sh prune 7                Remove backups older than 7 days"
}

case "$1" in
    add)
        add_source "$2"
        ;;
    remove|rm)
        remove_source "$2"
        ;;
    list|ls)
        list_sources
        ;;
    run|create)
        run_backup "$2"
        ;;
    restore)
        restore_backup "$2"
        ;;
    history)
        show_history
        ;;
    prune|clean)
        prune_backups "$2"
        ;;
    suite)
        backup_suite
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_sources
        echo ""
        show_history
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'backup.sh help' for usage"
        exit 1
        ;;
esac
