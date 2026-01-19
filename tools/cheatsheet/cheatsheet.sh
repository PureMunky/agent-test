#!/bin/bash
#
# Cheatsheet - Quick reference cards for commands, shortcuts, and syntax
#
# A tool for storing and quickly looking up keyboard shortcuts, command syntax,
# programming patterns, and quick reference information organized by topic.
#
# Usage:
#   cheatsheet.sh list                      - List all cheatsheets
#   cheatsheet.sh show <name>               - Show a cheatsheet
#   cheatsheet.sh search <query>            - Search across all cheatsheets
#   cheatsheet.sh create <name>             - Create a new cheatsheet
#   cheatsheet.sh edit <name>               - Edit a cheatsheet
#   cheatsheet.sh add <name> <section> <key> <value> - Add an entry
#   cheatsheet.sh delete <name>             - Delete a cheatsheet
#   cheatsheet.sh export <name>             - Export cheatsheet to markdown
#   cheatsheet.sh import <file>             - Import cheatsheet from markdown
#   cheatsheet.sh builtin                   - List built-in cheatsheets
#   cheatsheet.sh builtin <name>            - Show a built-in cheatsheet
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
SHEETS_DIR="$DATA_DIR/sheets"

mkdir -p "$SHEETS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Built-in cheatsheets
get_builtin_git() {
    cat << 'SHEET'
{
    "name": "git",
    "description": "Git version control commands",
    "sections": {
        "Basic Commands": {
            "git init": "Initialize a new repository",
            "git clone <url>": "Clone a repository",
            "git status": "Show working tree status",
            "git add <file>": "Stage file for commit",
            "git add .": "Stage all changes",
            "git commit -m \"msg\"": "Commit staged changes",
            "git push": "Push to remote",
            "git pull": "Fetch and merge from remote"
        },
        "Branching": {
            "git branch": "List branches",
            "git branch <name>": "Create a branch",
            "git checkout <branch>": "Switch to branch",
            "git checkout -b <name>": "Create and switch to branch",
            "git merge <branch>": "Merge branch into current",
            "git branch -d <name>": "Delete a branch",
            "git branch -D <name>": "Force delete a branch"
        },
        "History & Diff": {
            "git log": "Show commit history",
            "git log --oneline": "Compact commit history",
            "git log --graph": "Show branch graph",
            "git diff": "Show unstaged changes",
            "git diff --staged": "Show staged changes",
            "git show <commit>": "Show commit details"
        },
        "Undoing Changes": {
            "git restore <file>": "Discard file changes",
            "git restore --staged <file>": "Unstage file",
            "git reset HEAD~1": "Undo last commit (keep changes)",
            "git reset --hard HEAD~1": "Undo last commit (discard)",
            "git revert <commit>": "Create undo commit",
            "git stash": "Stash changes",
            "git stash pop": "Apply stashed changes"
        },
        "Remote": {
            "git remote -v": "List remotes",
            "git remote add <name> <url>": "Add remote",
            "git fetch": "Fetch from remote",
            "git push -u origin <branch>": "Push and set upstream",
            "git push --force": "Force push (careful!)"
        }
    }
}
SHEET
}

get_builtin_vim() {
    cat << 'SHEET'
{
    "name": "vim",
    "description": "Vim text editor commands",
    "sections": {
        "Modes": {
            "i": "Insert mode (before cursor)",
            "a": "Insert mode (after cursor)",
            "I": "Insert at line start",
            "A": "Insert at line end",
            "o": "New line below",
            "O": "New line above",
            "v": "Visual mode",
            "V": "Visual line mode",
            "Ctrl+v": "Visual block mode",
            "Esc": "Return to normal mode"
        },
        "Movement": {
            "h/j/k/l": "Left/down/up/right",
            "w": "Next word",
            "b": "Previous word",
            "e": "End of word",
            "0": "Start of line",
            "$": "End of line",
            "^": "First non-blank char",
            "gg": "Start of file",
            "G": "End of file",
            "<n>G": "Go to line n",
            "Ctrl+d": "Half page down",
            "Ctrl+u": "Half page up"
        },
        "Editing": {
            "x": "Delete character",
            "dd": "Delete line",
            "dw": "Delete word",
            "d$": "Delete to end of line",
            "yy": "Yank (copy) line",
            "yw": "Yank word",
            "p": "Paste after",
            "P": "Paste before",
            "u": "Undo",
            "Ctrl+r": "Redo",
            ".": "Repeat last change"
        },
        "Search & Replace": {
            "/pattern": "Search forward",
            "?pattern": "Search backward",
            "n": "Next match",
            "N": "Previous match",
            "*": "Search word under cursor",
            ":%s/old/new/g": "Replace all in file",
            ":s/old/new/g": "Replace all in line"
        },
        "Files & Buffers": {
            ":w": "Save file",
            ":q": "Quit",
            ":wq or :x": "Save and quit",
            ":q!": "Quit without saving",
            ":e <file>": "Open file",
            ":bn": "Next buffer",
            ":bp": "Previous buffer",
            ":ls": "List buffers"
        }
    }
}
SHEET
}

get_builtin_docker() {
    cat << 'SHEET'
{
    "name": "docker",
    "description": "Docker container commands",
    "sections": {
        "Images": {
            "docker images": "List images",
            "docker pull <image>": "Pull image from registry",
            "docker build -t <name> .": "Build image from Dockerfile",
            "docker rmi <image>": "Remove image",
            "docker image prune": "Remove unused images"
        },
        "Containers": {
            "docker ps": "List running containers",
            "docker ps -a": "List all containers",
            "docker run <image>": "Run container",
            "docker run -d <image>": "Run in background",
            "docker run -it <image> bash": "Run with terminal",
            "docker run -p 8080:80 <image>": "Map port",
            "docker run -v /host:/cont <image>": "Mount volume",
            "docker stop <id>": "Stop container",
            "docker start <id>": "Start container",
            "docker rm <id>": "Remove container",
            "docker container prune": "Remove stopped containers"
        },
        "Exec & Logs": {
            "docker exec -it <id> bash": "Shell into container",
            "docker logs <id>": "View logs",
            "docker logs -f <id>": "Follow logs",
            "docker inspect <id>": "Container details",
            "docker top <id>": "Running processes"
        },
        "Docker Compose": {
            "docker compose up": "Start services",
            "docker compose up -d": "Start in background",
            "docker compose down": "Stop services",
            "docker compose ps": "List services",
            "docker compose logs": "View logs",
            "docker compose build": "Build services"
        },
        "System": {
            "docker system df": "Disk usage",
            "docker system prune": "Clean up everything",
            "docker network ls": "List networks",
            "docker volume ls": "List volumes"
        }
    }
}
SHEET
}

get_builtin_bash() {
    cat << 'SHEET'
{
    "name": "bash",
    "description": "Bash shell shortcuts and syntax",
    "sections": {
        "Navigation Shortcuts": {
            "Ctrl+a": "Move to start of line",
            "Ctrl+e": "Move to end of line",
            "Ctrl+b": "Move back one character",
            "Ctrl+f": "Move forward one character",
            "Alt+b": "Move back one word",
            "Alt+f": "Move forward one word",
            "Ctrl+xx": "Toggle start/current position"
        },
        "Editing Shortcuts": {
            "Ctrl+d": "Delete character under cursor",
            "Ctrl+h": "Delete character before cursor",
            "Ctrl+w": "Delete word before cursor",
            "Ctrl+k": "Delete to end of line",
            "Ctrl+u": "Delete to start of line",
            "Ctrl+y": "Paste deleted text",
            "Ctrl+t": "Swap characters",
            "Alt+t": "Swap words"
        },
        "History": {
            "Ctrl+r": "Search history",
            "Ctrl+g": "Cancel search",
            "Ctrl+p": "Previous command",
            "Ctrl+n": "Next command",
            "!!": "Repeat last command",
            "!$": "Last argument of previous",
            "!*": "All arguments of previous",
            "!<n>": "Execute history item n"
        },
        "Process Control": {
            "Ctrl+c": "Kill current process",
            "Ctrl+z": "Suspend process",
            "fg": "Resume in foreground",
            "bg": "Resume in background",
            "jobs": "List background jobs",
            "kill %1": "Kill job 1"
        },
        "Redirects & Pipes": {
            ">": "Redirect stdout (overwrite)",
            ">>": "Redirect stdout (append)",
            "2>": "Redirect stderr",
            "2>&1": "Stderr to stdout",
            "&>": "Redirect all output",
            "|": "Pipe output to command",
            "tee": "Write to file and stdout"
        }
    }
}
SHEET
}

get_builtin_tmux() {
    cat << 'SHEET'
{
    "name": "tmux",
    "description": "Tmux terminal multiplexer (prefix = Ctrl+b)",
    "sections": {
        "Sessions": {
            "tmux new -s <name>": "New named session",
            "tmux ls": "List sessions",
            "tmux attach -t <name>": "Attach to session",
            "tmux kill-session -t <name>": "Kill session",
            "prefix d": "Detach from session",
            "prefix $": "Rename session",
            "prefix s": "List/switch sessions"
        },
        "Windows": {
            "prefix c": "Create window",
            "prefix ,": "Rename window",
            "prefix w": "List windows",
            "prefix n": "Next window",
            "prefix p": "Previous window",
            "prefix <0-9>": "Go to window n",
            "prefix &": "Kill window"
        },
        "Panes": {
            "prefix %": "Split vertically",
            "prefix \"": "Split horizontally",
            "prefix <arrow>": "Move between panes",
            "prefix o": "Next pane",
            "prefix z": "Toggle zoom",
            "prefix x": "Kill pane",
            "prefix {": "Move pane left",
            "prefix }": "Move pane right",
            "prefix Space": "Cycle layouts"
        },
        "Copy Mode": {
            "prefix [": "Enter copy mode",
            "q": "Exit copy mode",
            "Space": "Start selection",
            "Enter": "Copy selection",
            "prefix ]": "Paste buffer"
        },
        "Other": {
            "prefix :": "Command prompt",
            "prefix t": "Show clock",
            "prefix ?": "List keybindings",
            "prefix r": "Reload config (if bound)"
        }
    }
}
SHEET
}

# Get list of built-in cheatsheets
list_builtins() {
    echo "git vim docker bash tmux"
}

# Show a built-in cheatsheet
show_builtin() {
    local name="$1"
    local sheet=""

    case "$name" in
        git) sheet=$(get_builtin_git) ;;
        vim) sheet=$(get_builtin_vim) ;;
        docker) sheet=$(get_builtin_docker) ;;
        bash) sheet=$(get_builtin_bash) ;;
        tmux) sheet=$(get_builtin_tmux) ;;
        *)
            echo -e "${RED}Unknown built-in cheatsheet: $name${NC}"
            echo "Available: $(list_builtins | tr ' ' ', ')"
            return 1
            ;;
    esac

    display_sheet "$sheet"
}

# Display a cheatsheet from JSON
display_sheet() {
    local sheet="$1"
    local name=$(echo "$sheet" | jq -r '.name')
    local desc=$(echo "$sheet" | jq -r '.description // ""')

    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}${GREEN}$name${NC}"
    if [[ -n "$desc" ]]; then
        echo -e "${BOLD}${BLUE}║${NC}  ${GRAY}$desc${NC}"
    fi
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Get sections
    local sections=$(echo "$sheet" | jq -r '.sections | keys[]')

    while IFS= read -r section; do
        echo -e "${YELLOW}━━━ $section ━━━${NC}"
        echo ""

        # Get entries for this section
        echo "$sheet" | jq -r --arg sec "$section" '.sections[$sec] | to_entries[] | "\(.key)|\(.value)"' | while IFS='|' read -r key value; do
            printf "  ${CYAN}%-30s${NC} %s\n" "$key" "$value"
        done

        echo ""
    done <<< "$sections"
}

# List all cheatsheets
list_sheets() {
    echo -e "${BLUE}=== Cheatsheets ===${NC}"
    echo ""

    local count=0

    # User sheets
    if ls "$SHEETS_DIR"/*.json &>/dev/null; then
        echo -e "${YELLOW}Your Cheatsheets:${NC}"
        for file in "$SHEETS_DIR"/*.json; do
            local name=$(basename "$file" .json)
            local desc=$(jq -r '.description // ""' "$file")
            local sections=$(jq -r '.sections | keys | length' "$file")

            if [[ -n "$desc" ]]; then
                echo -e "  ${GREEN}$name${NC} - $desc ${GRAY}($sections sections)${NC}"
            else
                echo -e "  ${GREEN}$name${NC} ${GRAY}($sections sections)${NC}"
            fi
            count=$((count + 1))
        done
        echo ""
    fi

    # Built-ins
    echo -e "${YELLOW}Built-in Cheatsheets:${NC}"
    for builtin in $(list_builtins); do
        echo -e "  ${CYAN}$builtin${NC}"
    done
    echo ""

    if [[ $count -eq 0 ]]; then
        echo -e "${GRAY}No custom cheatsheets yet.${NC}"
        echo "Create one with: cheatsheet.sh create <name>"
        echo ""
    fi
}

# Show a cheatsheet
show_sheet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: cheatsheet.sh show <name>"
        exit 1
    fi

    # Normalize name
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    # Check if it's a user sheet
    if [[ -f "$file" ]]; then
        display_sheet "$(cat "$file")"
        return
    fi

    # Check if it's a built-in
    if list_builtins | grep -qw "$name"; then
        show_builtin "$name"
        return
    fi

    echo -e "${RED}Cheatsheet '$name' not found${NC}"
    echo ""
    echo "Available cheatsheets:"
    list_sheets
    exit 1
}

# Search across all cheatsheets
search_sheets() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: cheatsheet.sh search <query>"
        exit 1
    fi

    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local found=0

    # Search user sheets
    if ls "$SHEETS_DIR"/*.json &>/dev/null; then
        for file in "$SHEETS_DIR"/*.json; do
            local name=$(basename "$file" .json)
            local matches=$(jq -r --arg q "$query_lower" '
                .sections | to_entries[] | .key as $section | .value | to_entries[] |
                select((.key | ascii_downcase | contains($q)) or (.value | ascii_downcase | contains($q))) |
                "\($section)|\(.key)|\(.value)"
            ' "$file" 2>/dev/null)

            if [[ -n "$matches" ]]; then
                echo -e "${GREEN}$name${NC}"
                echo "$matches" | while IFS='|' read -r section key value; do
                    printf "  ${YELLOW}[$section]${NC} ${CYAN}%-28s${NC} %s\n" "$key" "$value"
                done
                echo ""
                found=1
            fi
        done
    fi

    # Search built-ins
    for builtin in $(list_builtins); do
        local sheet=""
        case "$builtin" in
            git) sheet=$(get_builtin_git) ;;
            vim) sheet=$(get_builtin_vim) ;;
            docker) sheet=$(get_builtin_docker) ;;
            bash) sheet=$(get_builtin_bash) ;;
            tmux) sheet=$(get_builtin_tmux) ;;
        esac

        local matches=$(echo "$sheet" | jq -r --arg q "$query_lower" '
            .sections | to_entries[] | .key as $section | .value | to_entries[] |
            select((.key | ascii_downcase | contains($q)) or (.value | ascii_downcase | contains($q))) |
            "\($section)|\(.key)|\(.value)"
        ' 2>/dev/null)

        if [[ -n "$matches" ]]; then
            echo -e "${CYAN}$builtin${NC} ${GRAY}(built-in)${NC}"
            echo "$matches" | while IFS='|' read -r section key value; do
                printf "  ${YELLOW}[$section]${NC} ${CYAN}%-28s${NC} %s\n" "$key" "$value"
            done
            echo ""
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No results found for \"$query\""
    fi
}

# Create a new cheatsheet
create_sheet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: cheatsheet.sh create <name>"
        exit 1
    fi

    # Normalize name
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ -f "$file" ]]; then
        echo -e "${YELLOW}Cheatsheet '$name' already exists${NC}"
        echo "Use 'cheatsheet.sh edit $name' to modify it"
        exit 1
    fi

    echo -n "Description (optional): "
    read -r description

    echo -n "First section name (e.g., 'Basic Commands'): "
    read -r section

    if [[ -z "$section" ]]; then
        section="General"
    fi

    cat > "$file" << EOF
{
    "name": "$name",
    "description": "$description",
    "created": "$(date '+%Y-%m-%d %H:%M')",
    "sections": {
        "$section": {}
    }
}
EOF

    echo -e "${GREEN}Created cheatsheet:${NC} $name"
    echo ""
    echo "Add entries with:"
    echo "  cheatsheet.sh add $name \"$section\" \"command\" \"description\""
    echo ""
    echo "Or edit directly: $file"
}

# Add an entry to a cheatsheet
add_entry() {
    local name="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    if [[ -z "$name" ]] || [[ -z "$section" ]] || [[ -z "$key" ]] || [[ -z "$value" ]]; then
        echo "Usage: cheatsheet.sh add <name> <section> <key> <value>"
        echo ""
        echo "Example:"
        echo "  cheatsheet.sh add git \"Basic Commands\" \"git status\" \"Show working tree status\""
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        echo "Create it first with: cheatsheet.sh create $name"
        exit 1
    fi

    # Check if section exists, create if not
    local has_section=$(jq -r --arg sec "$section" 'has("sections") and (.sections | has($sec))' "$file")

    if [[ "$has_section" != "true" ]]; then
        jq --arg sec "$section" '.sections[$sec] = {}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi

    # Add the entry
    jq --arg sec "$section" --arg key "$key" --arg val "$value" \
        '.sections[$sec][$key] = $val' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    echo -e "${GREEN}Added to $name [$section]:${NC}"
    printf "  ${CYAN}%-30s${NC} %s\n" "$key" "$value"
}

# Add a section to a cheatsheet
add_section() {
    local name="$1"
    local section="$2"

    if [[ -z "$name" ]] || [[ -z "$section" ]]; then
        echo "Usage: cheatsheet.sh add-section <name> <section-name>"
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        exit 1
    fi

    local has_section=$(jq -r --arg sec "$section" '.sections | has($sec)' "$file")

    if [[ "$has_section" == "true" ]]; then
        echo -e "${YELLOW}Section '$section' already exists${NC}"
        exit 0
    fi

    jq --arg sec "$section" '.sections[$sec] = {}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    echo -e "${GREEN}Added section:${NC} $section"
}

# Edit a cheatsheet
edit_sheet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: cheatsheet.sh edit <name>"
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        exit 1
    fi

    local editor="${EDITOR:-${VISUAL:-nano}}"

    if command -v "$editor" &>/dev/null; then
        "$editor" "$file"
    else
        echo "Edit manually: $file"
    fi
}

# Delete a cheatsheet
delete_sheet() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: cheatsheet.sh delete <name>"
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        exit 1
    fi

    read -p "Delete cheatsheet '$name'? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$file"
        echo -e "${RED}Deleted:${NC} $name"
    else
        echo "Cancelled"
    fi
}

# Export cheatsheet to markdown
export_sheet() {
    local name="$1"
    local output="${2:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: cheatsheet.sh export <name> [output.md]"
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"
    local sheet=""

    # Check user sheets first
    if [[ -f "$file" ]]; then
        sheet=$(cat "$file")
    elif list_builtins | grep -qw "$name"; then
        case "$name" in
            git) sheet=$(get_builtin_git) ;;
            vim) sheet=$(get_builtin_vim) ;;
            docker) sheet=$(get_builtin_docker) ;;
            bash) sheet=$(get_builtin_bash) ;;
            tmux) sheet=$(get_builtin_tmux) ;;
        esac
    else
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        exit 1
    fi

    local desc=$(echo "$sheet" | jq -r '.description // ""')

    {
        echo "# $name Cheatsheet"
        if [[ -n "$desc" ]]; then
            echo ""
            echo "$desc"
        fi
        echo ""

        echo "$sheet" | jq -r '.sections | keys[]' | while read -r section; do
            echo "## $section"
            echo ""
            echo "| Command | Description |"
            echo "|---------|-------------|"
            echo "$sheet" | jq -r --arg sec "$section" '.sections[$sec] | to_entries[] | "| `\(.key)` | \(.value) |"'
            echo ""
        done
    } > "${output:-/dev/stdout}"

    if [[ -n "$output" ]]; then
        echo -e "${GREEN}Exported to:${NC} $output"
    fi
}

# Import cheatsheet from markdown
import_sheet() {
    local input="$1"

    if [[ -z "$input" ]] || [[ ! -f "$input" ]]; then
        echo "Usage: cheatsheet.sh import <file.md>"
        exit 1
    fi

    # Extract name from first heading
    local name=$(grep -m1 "^# " "$input" | sed 's/^# //' | sed 's/ [Cc]heatsheet$//' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    if [[ -z "$name" ]]; then
        echo -e "${RED}Could not determine name from file${NC}"
        echo "Expected first line to be: # Name Cheatsheet"
        exit 1
    fi

    local file="$SHEETS_DIR/${name}.json"

    if [[ -f "$file" ]]; then
        read -p "Cheatsheet '$name' exists. Overwrite? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi

    # Parse markdown (basic implementation)
    local sections="{}"
    local current_section=""

    while IFS= read -r line; do
        # Section header
        if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            sections=$(echo "$sections" | jq --arg sec "$current_section" '.[$sec] = {}')
        # Table row (skip header and separator)
        elif [[ "$line" =~ ^\|[[:space:]]*\`([^\`]+)\`[[:space:]]*\|[[:space:]]*(.+)[[:space:]]*\|$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            if [[ -n "$current_section" ]]; then
                sections=$(echo "$sections" | jq --arg sec "$current_section" --arg k "$key" --arg v "$value" '.[$sec][$k] = $v')
            fi
        fi
    done < "$input"

    # Create the JSON file
    jq -n --arg name "$name" --argjson sections "$sections" '{
        name: $name,
        description: "",
        created: (now | strftime("%Y-%m-%d %H:%M")),
        sections: $sections
    }' > "$file"

    echo -e "${GREEN}Imported:${NC} $name"
    echo "File: $file"
}

# Remove an entry from a cheatsheet
remove_entry() {
    local name="$1"
    local section="$2"
    local key="$3"

    if [[ -z "$name" ]] || [[ -z "$section" ]] || [[ -z "$key" ]]; then
        echo "Usage: cheatsheet.sh remove-entry <name> <section> <key>"
        exit 1
    fi

    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local file="$SHEETS_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Cheatsheet '$name' not found${NC}"
        exit 1
    fi

    jq --arg sec "$section" --arg key "$key" 'del(.sections[$sec][$key])' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    echo -e "${RED}Removed:${NC} [$section] $key"
}

show_help() {
    echo "Cheatsheet - Quick reference cards for commands, shortcuts, and syntax"
    echo ""
    echo "Usage:"
    echo "  cheatsheet.sh list                  List all cheatsheets"
    echo "  cheatsheet.sh show <name>           Show a cheatsheet"
    echo "  cheatsheet.sh <name>                Show a cheatsheet (shortcut)"
    echo "  cheatsheet.sh search <query>        Search across all cheatsheets"
    echo "  cheatsheet.sh create <name>         Create a new cheatsheet"
    echo "  cheatsheet.sh add <name> <section> <key> <value>"
    echo "                                      Add an entry"
    echo "  cheatsheet.sh add-section <name> <section>"
    echo "                                      Add a new section"
    echo "  cheatsheet.sh remove-entry <name> <section> <key>"
    echo "                                      Remove an entry"
    echo "  cheatsheet.sh edit <name>           Edit cheatsheet in \$EDITOR"
    echo "  cheatsheet.sh delete <name>         Delete a cheatsheet"
    echo "  cheatsheet.sh export <name> [file]  Export to markdown"
    echo "  cheatsheet.sh import <file.md>      Import from markdown"
    echo "  cheatsheet.sh builtin               List built-in cheatsheets"
    echo "  cheatsheet.sh help                  Show this help"
    echo ""
    echo "Built-in cheatsheets: $(list_builtins | tr ' ' ', ')"
    echo ""
    echo "Examples:"
    echo "  cheatsheet.sh git                   # Quick view git cheatsheet"
    echo "  cheatsheet.sh search commit         # Find 'commit' in all sheets"
    echo "  cheatsheet.sh create python         # Create custom sheet"
    echo "  cheatsheet.sh add python \"Basics\" \"print()\" \"Output to console\""
}

case "$1" in
    list|ls)
        list_sheets
        ;;
    show|view)
        show_sheet "$2"
        ;;
    search|find|s)
        shift
        search_sheets "$@"
        ;;
    create|new)
        create_sheet "$2"
        ;;
    add|a)
        shift
        add_entry "$@"
        ;;
    add-section)
        add_section "$2" "$3"
        ;;
    remove-entry|rm-entry)
        remove_entry "$2" "$3" "$4"
        ;;
    edit|e)
        edit_sheet "$2"
        ;;
    delete|del|rm)
        delete_sheet "$2"
        ;;
    export)
        export_sheet "$2" "$3"
        ;;
    import)
        import_sheet "$2"
        ;;
    builtin|builtins)
        if [[ -n "$2" ]]; then
            show_builtin "$2"
        else
            echo -e "${BLUE}Built-in Cheatsheets:${NC}"
            for b in $(list_builtins); do
                echo "  - $b"
            done
            echo ""
            echo "View with: cheatsheet.sh <name>"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_sheets
        ;;
    *)
        # Try to show as a cheatsheet name
        show_sheet "$1"
        ;;
esac
