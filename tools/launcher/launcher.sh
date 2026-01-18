#!/bin/bash
#
# Launcher - Quick command palette for the productivity suite
#
# Usage:
#   launcher.sh                     - Interactive tool selector
#   launcher.sh list                - List all available tools
#   launcher.sh search "query"      - Search tools by name/description
#   launcher.sh run <tool> [args]   - Run a tool directly
#   launcher.sh alias <name> <cmd>  - Create a custom alias
#   launcher.sh aliases             - List all aliases
#   launcher.sh recent              - Show recently used commands
#   launcher.sh fav <tool>          - Toggle tool as favorite
#   launcher.sh favorites           - Show favorite tools
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/data"
ALIASES_FILE="$DATA_DIR/aliases.json"
HISTORY_FILE="$DATA_DIR/history.json"
FAVORITES_FILE="$DATA_DIR/favorites.json"
MANIFEST_FILE="$(dirname "$SUITE_DIR")/manifest.json"

mkdir -p "$DATA_DIR"

# Initialize files if they don't exist
if [[ ! -f "$ALIASES_FILE" ]]; then
    echo '{"aliases":{}}' > "$ALIASES_FILE"
fi

if [[ ! -f "$HISTORY_FILE" ]]; then
    echo '{"history":[]}' > "$HISTORY_FILE"
fi

if [[ ! -f "$FAVORITES_FILE" ]]; then
    echo '{"favorites":[]}' > "$FAVORITES_FILE"
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

# Get all tools from manifest
get_tools() {
    if [[ -f "$MANIFEST_FILE" ]]; then
        jq -r '.tools[] | "\(.name)|\(.description)|\(.path)|\(.category)"' "$MANIFEST_FILE" 2>/dev/null
    fi
}

# Get tool info by name
get_tool_info() {
    local name="$1"
    if [[ -f "$MANIFEST_FILE" ]]; then
        jq -r --arg name "$name" '.tools[] | select(.name == $name) | "\(.name)|\(.description)|\(.path)|\(.category)"' "$MANIFEST_FILE" 2>/dev/null
    fi
}

# Check if tool is a favorite
is_favorite() {
    local name="$1"
    jq -r --arg name "$name" '.favorites | index($name) != null' "$FAVORITES_FILE" 2>/dev/null
}

# Record command in history
record_history() {
    local command="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Keep last 50 entries
    jq --arg cmd "$command" --arg ts "$timestamp" '
        .history = ([{"command": $cmd, "timestamp": $ts}] + .history) | .history = .history[:50]
    ' "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# List all tools
list_tools() {
    echo -e "${BLUE}=== Productivity Suite Tools ===${NC}"
    echo ""

    local favorites=$(jq -r '.favorites[]' "$FAVORITES_FILE" 2>/dev/null)
    local current_category=""

    # Group by category
    get_tools | sort -t'|' -k4,4 -k1,1 | while IFS='|' read -r name desc path category; do
        if [[ "$category" != "$current_category" ]]; then
            current_category="$category"
            echo ""
            echo -e "${YELLOW}[$category]${NC}"
        fi

        local star=""
        if echo "$favorites" | grep -q "^${name}$"; then
            star="${MAGENTA}★${NC} "
        fi

        echo -e "  ${star}${GREEN}${name}${NC} - ${GRAY}${desc}${NC}"
    done

    echo ""
    echo -e "${CYAN}Run a tool with: launcher.sh run <tool-name>${NC}"
}

# Search tools
search_tools() {
    local query="$1"

    if [[ -z "$query" ]]; then
        echo "Usage: launcher.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local found=0

    get_tools | while IFS='|' read -r name desc path category; do
        if echo "$name $desc $category" | grep -qi "$query"; then
            echo -e "  ${GREEN}${name}${NC} ${GRAY}[$category]${NC}"
            echo -e "    ${desc}"
            echo ""
            ((found++))
        fi
    done

    # Also search aliases
    local alias_matches=$(jq -r --arg q "$query" '
        .aliases | to_entries[] | select(.key | test($q; "i")) | "\(.key)|\(.value)"
    ' "$ALIASES_FILE" 2>/dev/null)

    if [[ -n "$alias_matches" ]]; then
        echo -e "${YELLOW}Matching Aliases:${NC}"
        echo "$alias_matches" | while IFS='|' read -r alias_name alias_cmd; do
            echo -e "  ${MAGENTA}$alias_name${NC} -> $alias_cmd"
        done
    fi
}

# Run a tool
run_tool() {
    local tool_name="$1"
    shift
    local args="$*"

    if [[ -z "$tool_name" ]]; then
        echo "Usage: launcher.sh run <tool-name> [args]"
        exit 1
    fi

    # First check if it's an alias
    local alias_cmd=$(jq -r --arg name "$tool_name" '.aliases[$name] // ""' "$ALIASES_FILE" 2>/dev/null)

    if [[ -n "$alias_cmd" ]]; then
        record_history "$tool_name $args"
        echo -e "${CYAN}Running alias:${NC} $alias_cmd $args"
        echo ""
        eval "$alias_cmd $args"
        return
    fi

    # Check if tool exists
    local tool_info=$(get_tool_info "$tool_name")

    if [[ -z "$tool_info" ]]; then
        echo -e "${RED}Tool not found:${NC} $tool_name"
        echo ""
        echo "Available tools:"
        get_tools | cut -d'|' -f1 | sort | head -10 | while read name; do
            echo "  - $name"
        done
        echo "  ..."
        echo ""
        echo "Use 'launcher.sh list' to see all tools"
        exit 1
    fi

    IFS='|' read -r name desc path category <<< "$tool_info"

    local tool_script="$SUITE_DIR/$name/$name.sh"

    if [[ ! -f "$tool_script" ]]; then
        # Try alternate locations
        tool_script=$(find "$SUITE_DIR/$name" -name "*.sh" -type f 2>/dev/null | head -1)
    fi

    if [[ -z "$tool_script" ]] || [[ ! -f "$tool_script" ]]; then
        echo -e "${RED}Tool script not found in:${NC} $SUITE_DIR/$name/"
        exit 1
    fi

    record_history "$tool_name $args"

    echo -e "${CYAN}Running:${NC} $name $args"
    echo ""
    bash "$tool_script" $args
}

# Create alias
create_alias() {
    local alias_name="$1"
    local alias_cmd="$2"

    if [[ -z "$alias_name" ]] || [[ -z "$alias_cmd" ]]; then
        echo "Usage: launcher.sh alias <name> <command>"
        echo ""
        echo "Examples:"
        echo "  launcher.sh alias pt 'pomodoro start'"
        echo "  launcher.sh alias note 'quicknotes add'"
        echo "  launcher.sh alias td 'tasks list'"
        exit 1
    fi

    jq --arg name "$alias_name" --arg cmd "$alias_cmd" '
        .aliases[$name] = $cmd
    ' "$ALIASES_FILE" > "$ALIASES_FILE.tmp" && mv "$ALIASES_FILE.tmp" "$ALIASES_FILE"

    echo -e "${GREEN}Alias created:${NC} $alias_name -> $alias_cmd"
}

# Remove alias
remove_alias() {
    local alias_name="$1"

    if [[ -z "$alias_name" ]]; then
        echo "Usage: launcher.sh unalias <name>"
        exit 1
    fi

    local exists=$(jq -r --arg name "$alias_name" '.aliases[$name] // ""' "$ALIASES_FILE")

    if [[ -z "$exists" ]]; then
        echo -e "${RED}Alias not found:${NC} $alias_name"
        exit 1
    fi

    jq --arg name "$alias_name" 'del(.aliases[$name])' "$ALIASES_FILE" > "$ALIASES_FILE.tmp" && mv "$ALIASES_FILE.tmp" "$ALIASES_FILE"

    echo -e "${GREEN}Alias removed:${NC} $alias_name"
}

# List aliases
list_aliases() {
    echo -e "${BLUE}=== Custom Aliases ===${NC}"
    echo ""

    local aliases=$(jq -r '.aliases | to_entries[] | "\(.key)|\(.value)"' "$ALIASES_FILE" 2>/dev/null)

    if [[ -z "$aliases" ]]; then
        echo "No aliases defined."
        echo ""
        echo "Create one with: launcher.sh alias <name> <command>"
        exit 0
    fi

    echo "$aliases" | while IFS='|' read -r name cmd; do
        echo -e "  ${MAGENTA}$name${NC} -> $cmd"
    done
}

# Show recent commands
show_recent() {
    local count="${1:-10}"

    echo -e "${BLUE}=== Recent Commands ===${NC}"
    echo ""

    local history=$(jq -r --argjson n "$count" '.history[:$n][] | "\(.timestamp)|\(.command)"' "$HISTORY_FILE" 2>/dev/null)

    if [[ -z "$history" ]]; then
        echo "No command history yet."
        exit 0
    fi

    echo "$history" | while IFS='|' read -r ts cmd; do
        echo -e "  ${GRAY}$ts${NC}  $cmd"
    done

    echo ""
    echo -e "${CYAN}Re-run with: launcher.sh run <command>${NC}"
}

# Toggle favorite
toggle_favorite() {
    local tool_name="$1"

    if [[ -z "$tool_name" ]]; then
        echo "Usage: launcher.sh fav <tool-name>"
        exit 1
    fi

    # Check if tool exists
    local tool_info=$(get_tool_info "$tool_name")

    if [[ -z "$tool_info" ]]; then
        echo -e "${RED}Tool not found:${NC} $tool_name"
        exit 1
    fi

    local is_fav=$(is_favorite "$tool_name")

    if [[ "$is_fav" == "true" ]]; then
        jq --arg name "$tool_name" '.favorites = [.favorites[] | select(. != $name)]' "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" && mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
        echo -e "${YELLOW}Removed from favorites:${NC} $tool_name"
    else
        jq --arg name "$tool_name" '.favorites += [$name] | .favorites = (.favorites | unique)' "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" && mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
        echo -e "${GREEN}Added to favorites:${NC} $tool_name ★"
    fi
}

# Show favorites
show_favorites() {
    echo -e "${BLUE}=== Favorite Tools ===${NC}"
    echo ""

    local favorites=$(jq -r '.favorites[]' "$FAVORITES_FILE" 2>/dev/null)

    if [[ -z "$favorites" ]]; then
        echo "No favorites yet."
        echo ""
        echo "Add a favorite with: launcher.sh fav <tool-name>"
        exit 0
    fi

    echo "$favorites" | while read -r name; do
        local tool_info=$(get_tool_info "$name")
        if [[ -n "$tool_info" ]]; then
            IFS='|' read -r tname desc path category <<< "$tool_info"
            echo -e "  ${MAGENTA}★${NC} ${GREEN}${name}${NC} - ${GRAY}${desc}${NC}"
        fi
    done
}

# Interactive mode
interactive_mode() {
    echo -e "${BLUE}${BOLD}=== Productivity Suite Launcher ===${NC}"
    echo ""

    # Show favorites first if any
    local favorites=$(jq -r '.favorites[]' "$FAVORITES_FILE" 2>/dev/null)

    if [[ -n "$favorites" ]]; then
        echo -e "${YELLOW}Favorites:${NC}"
        local i=1
        echo "$favorites" | while read -r name; do
            local tool_info=$(get_tool_info "$name")
            if [[ -n "$tool_info" ]]; then
                IFS='|' read -r tname desc path category <<< "$tool_info"
                echo -e "  ${BOLD}$i.${NC} ${MAGENTA}★${NC} ${GREEN}${name}${NC} - ${GRAY}${desc}${NC}"
                ((i++))
            fi
        done
        echo ""
    fi

    # Show recent
    local recent=$(jq -r '.history[:5][].command' "$HISTORY_FILE" 2>/dev/null | sort -u | head -5)

    if [[ -n "$recent" ]]; then
        echo -e "${YELLOW}Recent:${NC}"
        echo "$recent" | while read -r cmd; do
            echo -e "  ${GRAY}•${NC} $cmd"
        done
        echo ""
    fi

    echo -e "${CYAN}Commands:${NC}"
    echo "  list    - Show all tools"
    echo "  search  - Search tools"
    echo "  recent  - Show history"
    echo "  quit    - Exit"
    echo ""

    read -p "Enter tool name or command: " input

    if [[ -z "$input" ]]; then
        exit 0
    fi

    case "$input" in
        list|ls)
            list_tools
            ;;
        search)
            read -p "Search query: " query
            search_tools "$query"
            ;;
        recent|history)
            show_recent
            ;;
        quit|exit|q)
            exit 0
            ;;
        *)
            # Try to run as tool
            run_tool $input
            ;;
    esac
}

# Show tool info
show_info() {
    local tool_name="$1"

    if [[ -z "$tool_name" ]]; then
        echo "Usage: launcher.sh info <tool-name>"
        exit 1
    fi

    local tool_info=$(get_tool_info "$tool_name")

    if [[ -z "$tool_info" ]]; then
        echo -e "${RED}Tool not found:${NC} $tool_name"
        exit 1
    fi

    IFS='|' read -r name desc path category <<< "$tool_info"

    echo -e "${BLUE}=== $name ===${NC}"
    echo ""
    echo -e "${CYAN}Description:${NC} $desc"
    echo -e "${CYAN}Category:${NC} $category"
    echo -e "${CYAN}Path:${NC} $path"

    # Check for README
    local readme="$SUITE_DIR/$name/README.md"
    if [[ -f "$readme" ]]; then
        echo ""
        echo -e "${YELLOW}From README:${NC}"
        head -20 "$readme" | tail -n +3 | sed 's/^/  /'
    fi

    # Show if favorite
    if [[ "$(is_favorite "$name")" == "true" ]]; then
        echo ""
        echo -e "${MAGENTA}★ This is a favorite${NC}"
    fi
}

show_help() {
    echo "Launcher - Quick command palette for the productivity suite"
    echo ""
    echo "Usage:"
    echo "  launcher.sh                    Interactive mode"
    echo "  launcher.sh list               List all available tools"
    echo "  launcher.sh search \"query\"     Search tools"
    echo "  launcher.sh run <tool> [args]  Run a tool"
    echo "  launcher.sh info <tool>        Show tool details"
    echo ""
    echo "Aliases:"
    echo "  launcher.sh alias <name> <cmd> Create an alias"
    echo "  launcher.sh unalias <name>     Remove an alias"
    echo "  launcher.sh aliases            List all aliases"
    echo ""
    echo "Favorites:"
    echo "  launcher.sh fav <tool>         Toggle favorite"
    echo "  launcher.sh favorites          Show favorites"
    echo ""
    echo "History:"
    echo "  launcher.sh recent [n]         Show last n commands"
    echo ""
    echo "Examples:"
    echo "  launcher.sh run pomodoro start"
    echo "  launcher.sh search time"
    echo "  launcher.sh alias p pomodoro"
    echo "  launcher.sh fav tasks"
}

case "$1" in
    list|ls)
        list_tools
        ;;
    search|find)
        shift
        search_tools "$*"
        ;;
    run|exec)
        shift
        run_tool "$@"
        ;;
    info|show)
        show_info "$2"
        ;;
    alias)
        create_alias "$2" "$3"
        ;;
    unalias|rmalias)
        remove_alias "$2"
        ;;
    aliases)
        list_aliases
        ;;
    recent|history)
        show_recent "$2"
        ;;
    fav|favorite)
        toggle_favorite "$2"
        ;;
    favorites|favs)
        show_favorites
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        interactive_mode
        ;;
    *)
        # Assume it's a tool name - try to run it
        run_tool "$@"
        ;;
esac
