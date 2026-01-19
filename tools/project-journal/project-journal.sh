#!/bin/bash
#
# Project Journal - Track progress, notes, and milestones for projects
#
# Usage:
#   project-journal.sh new "Project Name"              - Create a new project
#   project-journal.sh list                            - List all projects
#   project-journal.sh log "project" "entry"           - Add a journal entry
#   project-journal.sh milestone "project" "milestone" - Record a milestone
#   project-journal.sh view "project"                  - View project journal
#   project-journal.sh status "project" [status]       - View/set project status
#   project-journal.sh link "project" "url" [desc]     - Add a related link
#   project-journal.sh stats                           - Show statistics
#   project-journal.sh archive "project"               - Archive a project
#   project-journal.sh export "project" [file]         - Export project to markdown
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
PROJECTS_FILE="$DATA_DIR/projects.json"

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

# Initialize projects file
if [[ ! -f "$PROJECTS_FILE" ]]; then
    echo '{"projects":[]}' > "$PROJECTS_FILE"
fi

# Get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

get_date() {
    date '+%Y-%m-%d'
}

# Find project by name (case-insensitive partial match)
find_project() {
    local query="$1"
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    # Try exact match first
    local exact=$(jq -r --arg q "$query" '.projects[] | select(.name == $q and .archived != true) | .name' "$PROJECTS_FILE" | head -1)
    if [[ -n "$exact" ]]; then
        echo "$exact"
        return 0
    fi

    # Try case-insensitive partial match
    local match=$(jq -r --arg q "$query_lower" '
        .projects[] |
        select((.name | ascii_downcase | contains($q)) and .archived != true) |
        .name
    ' "$PROJECTS_FILE" | head -1)

    if [[ -n "$match" ]]; then
        echo "$match"
        return 0
    fi

    return 1
}

# Create new project
new_project() {
    local name="$*"

    if [[ -z "$name" ]]; then
        echo "Usage: project-journal.sh new \"Project Name\""
        exit 1
    fi

    # Check if project exists
    local existing=$(jq -r --arg name "$name" '.projects[] | select(.name == $name) | .name' "$PROJECTS_FILE")
    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Project '$name' already exists.${NC}"
        exit 1
    fi

    local timestamp=$(get_timestamp)

    # Add project
    jq --arg name "$name" --arg ts "$timestamp" '
        .projects += [{
            "name": $name,
            "created": $ts,
            "status": "active",
            "description": "",
            "entries": [],
            "milestones": [],
            "links": [],
            "archived": false
        }]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Created project:${NC} $name"
    echo -e "${CYAN}Status:${NC} active"
    echo ""
    echo "Add entries with: project-journal.sh log \"$name\" \"Your update here\""
}

# List all projects
list_projects() {
    local show_archived="$1"

    local filter='select(.archived != true)'
    local title="Active Projects"

    if [[ "$show_archived" == "--all" ]] || [[ "$show_archived" == "-a" ]]; then
        filter='.'
        title="All Projects"
    elif [[ "$show_archived" == "--archived" ]]; then
        filter='select(.archived == true)'
        title="Archived Projects"
    fi

    local count=$(jq "[.projects[] | $filter] | length" "$PROJECTS_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No projects found."
        echo "Create one with: project-journal.sh new \"Project Name\""
        exit 0
    fi

    echo -e "${BLUE}=== $title ($count) ===${NC}"
    echo ""

    jq -r ".projects[] | $filter | \"\(.name)|\(.status)|\(.created)|\(.entries | length)|\(.milestones | length)|\(.archived)\"" "$PROJECTS_FILE" | \
    while IFS='|' read -r name status created entries milestones archived; do
        local status_color="$GREEN"
        case "$status" in
            active) status_color="$GREEN" ;;
            paused|on-hold) status_color="$YELLOW" ;;
            completed) status_color="$CYAN" ;;
            blocked) status_color="$RED" ;;
        esac

        local archived_tag=""
        if [[ "$archived" == "true" ]]; then
            archived_tag=" ${GRAY}[archived]${NC}"
        fi

        echo -e "${BOLD}$name${NC}$archived_tag"
        echo -e "  ${status_color}[$status]${NC} ${GRAY}|${NC} ${CYAN}$entries${NC} entries ${GRAY}|${NC} ${MAGENTA}$milestones${NC} milestones"
        echo -e "  ${GRAY}Created: $created${NC}"
        echo ""
    done
}

# Add journal entry
add_entry() {
    local project_query="$1"
    shift
    local content="$*"

    if [[ -z "$project_query" ]] || [[ -z "$content" ]]; then
        echo "Usage: project-journal.sh log \"project\" \"Your journal entry\""
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        echo "Run 'project-journal.sh list' to see available projects."
        exit 1
    fi

    local timestamp=$(get_timestamp)
    local date=$(get_date)

    # Extract tags from content (words starting with #)
    local tags=$(echo "$content" | grep -oE '#[a-zA-Z0-9_-]+' | tr '\n' ',' | sed 's/,$//')

    # Add entry
    jq --arg name "$project_name" --arg content "$content" --arg ts "$timestamp" --arg date "$date" --arg tags "$tags" '
        .projects = [.projects[] |
            if .name == $name then
                .entries += [{
                    "content": $content,
                    "timestamp": $ts,
                    "date": $date,
                    "tags": ($tags | split(",") | map(select(. != "")))
                }]
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Added to $project_name:${NC}"
    echo -e "  $content"
    if [[ -n "$tags" ]]; then
        echo -e "  ${MAGENTA}Tags: $tags${NC}"
    fi
}

# Add milestone
add_milestone() {
    local project_query="$1"
    shift
    local milestone="$*"

    if [[ -z "$project_query" ]] || [[ -z "$milestone" ]]; then
        echo "Usage: project-journal.sh milestone \"project\" \"Milestone description\""
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        exit 1
    fi

    local timestamp=$(get_timestamp)

    # Add milestone
    jq --arg name "$project_name" --arg milestone "$milestone" --arg ts "$timestamp" '
        .projects = [.projects[] |
            if .name == $name then
                .milestones += [{
                    "description": $milestone,
                    "achieved": $ts
                }]
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${MAGENTA}Milestone recorded for $project_name:${NC}"
    echo -e "  $milestone"
}

# View project details
view_project() {
    local project_query="$1"
    local limit="${2:-20}"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh view \"project\" [limit]"
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        # Try archived projects
        project_name=$(jq -r --arg q "$project_query" '
            .projects[] | select(.name | ascii_downcase | contains($q | ascii_downcase)) | .name
        ' "$PROJECTS_FILE" | head -1)

        if [[ -z "$project_name" ]]; then
            echo -e "${RED}Project not found:${NC} $project_query"
            exit 1
        fi
    fi

    # Get project data
    local project=$(jq --arg name "$project_name" '.projects[] | select(.name == $name)' "$PROJECTS_FILE")

    local status=$(echo "$project" | jq -r '.status')
    local created=$(echo "$project" | jq -r '.created')
    local description=$(echo "$project" | jq -r '.description // ""')
    local entry_count=$(echo "$project" | jq '.entries | length')
    local milestone_count=$(echo "$project" | jq '.milestones | length')
    local archived=$(echo "$project" | jq -r '.archived')

    # Status color
    local status_color="$GREEN"
    case "$status" in
        active) status_color="$GREEN" ;;
        paused|on-hold) status_color="$YELLOW" ;;
        completed) status_color="$CYAN" ;;
        blocked) status_color="$RED" ;;
    esac

    echo -e "${BLUE}=== $project_name ===${NC}"
    if [[ "$archived" == "true" ]]; then
        echo -e "${GRAY}[ARCHIVED]${NC}"
    fi
    echo ""
    echo -e "${CYAN}Status:${NC} ${status_color}$status${NC}"
    echo -e "${CYAN}Created:${NC} $created"
    if [[ -n "$description" && "$description" != "null" ]]; then
        echo -e "${CYAN}Description:${NC} $description"
    fi
    echo -e "${CYAN}Entries:${NC} $entry_count  ${CYAN}Milestones:${NC} $milestone_count"
    echo ""

    # Show links
    local link_count=$(echo "$project" | jq '.links | length')
    if [[ "$link_count" -gt 0 ]]; then
        echo -e "${YELLOW}Links:${NC}"
        echo "$project" | jq -r '.links[] | "  \(.description // .url): \(.url)"'
        echo ""
    fi

    # Show milestones
    if [[ "$milestone_count" -gt 0 ]]; then
        echo -e "${MAGENTA}Milestones:${NC}"
        echo "$project" | jq -r '.milestones | reverse | .[] | "  \u2713 \(.description) (\(.achieved | split(" ")[0]))"'
        echo ""
    fi

    # Show recent entries
    if [[ "$entry_count" -gt 0 ]]; then
        echo -e "${GREEN}Journal Entries (most recent $limit):${NC}"
        echo ""

        echo "$project" | jq -r ".entries | reverse | .[0:$limit] | .[] | \"\(.date)|\(.content)|\(.tags | join(\",\"))\"" | \
        while IFS='|' read -r date content tags; do
            echo -e "  ${CYAN}$date${NC}"
            echo -e "    $content"
            if [[ -n "$tags" ]]; then
                echo -e "    ${MAGENTA}$tags${NC}"
            fi
            echo ""
        done
    fi
}

# Set/view project status
set_status() {
    local project_query="$1"
    local new_status="$2"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh status \"project\" [active|paused|completed|blocked|on-hold]"
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        exit 1
    fi

    if [[ -z "$new_status" ]]; then
        # Just show current status
        local current=$(jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .status' "$PROJECTS_FILE")
        echo -e "${CYAN}$project_name status:${NC} $current"
        exit 0
    fi

    # Validate status
    case "$new_status" in
        active|paused|completed|blocked|on-hold)
            ;;
        *)
            echo -e "${RED}Invalid status:${NC} $new_status"
            echo "Valid statuses: active, paused, completed, blocked, on-hold"
            exit 1
            ;;
    esac

    # Update status
    jq --arg name "$project_name" --arg status "$new_status" '
        .projects = [.projects[] |
            if .name == $name then
                .status = $status
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Updated $project_name:${NC} status = $new_status"

    # Auto-add milestone for completion
    if [[ "$new_status" == "completed" ]]; then
        add_milestone "$project_name" "Project completed"
    fi
}

# Add link to project
add_link() {
    local project_query="$1"
    local url="$2"
    shift 2
    local description="$*"

    if [[ -z "$project_query" ]] || [[ -z "$url" ]]; then
        echo "Usage: project-journal.sh link \"project\" \"url\" [description]"
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        exit 1
    fi

    local timestamp=$(get_timestamp)

    # Add link
    jq --arg name "$project_name" --arg url "$url" --arg desc "$description" --arg ts "$timestamp" '
        .projects = [.projects[] |
            if .name == $name then
                .links += [{
                    "url": $url,
                    "description": (if $desc == "" then null else $desc end),
                    "added": $ts
                }]
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Added link to $project_name:${NC}"
    if [[ -n "$description" ]]; then
        echo -e "  $description: $url"
    else
        echo -e "  $url"
    fi
}

# Set project description
set_description() {
    local project_query="$1"
    shift
    local description="$*"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh desc \"project\" \"Description text\""
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        exit 1
    fi

    # Update description
    jq --arg name "$project_name" --arg desc "$description" '
        .projects = [.projects[] |
            if .name == $name then
                .description = $desc
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Updated description for $project_name${NC}"
}

# Archive project
archive_project() {
    local project_query="$1"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh archive \"project\""
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Project not found:${NC} $project_query"
        exit 1
    fi

    echo -e "${YELLOW}Archive project '$project_name'?${NC}"
    read -p "(y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    jq --arg name "$project_name" '
        .projects = [.projects[] |
            if .name == $name then
                .archived = true
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Archived:${NC} $project_name"
}

# Unarchive project
unarchive_project() {
    local project_query="$1"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh unarchive \"project\""
        exit 1
    fi

    # Find in archived projects
    local project_name=$(jq -r --arg q "$project_query" '
        .projects[] | select(.archived == true and (.name | ascii_downcase | contains($q | ascii_downcase))) | .name
    ' "$PROJECTS_FILE" | head -1)

    if [[ -z "$project_name" ]]; then
        echo -e "${RED}Archived project not found:${NC} $project_query"
        exit 1
    fi

    jq --arg name "$project_name" '
        .projects = [.projects[] |
            if .name == $name then
                .archived = false
            else
                .
            end
        ]
    ' "$PROJECTS_FILE" > "$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

    echo -e "${GREEN}Unarchived:${NC} $project_name"
}

# Show statistics
show_stats() {
    echo -e "${BLUE}=== Project Statistics ===${NC}"
    echo ""

    local total=$(jq '.projects | length' "$PROJECTS_FILE")
    local active=$(jq '[.projects[] | select(.status == "active" and .archived != true)] | length' "$PROJECTS_FILE")
    local completed=$(jq '[.projects[] | select(.status == "completed")] | length' "$PROJECTS_FILE")
    local archived=$(jq '[.projects[] | select(.archived == true)] | length' "$PROJECTS_FILE")
    local total_entries=$(jq '[.projects[].entries | length] | add // 0' "$PROJECTS_FILE")
    local total_milestones=$(jq '[.projects[].milestones | length] | add // 0' "$PROJECTS_FILE")

    echo -e "${CYAN}Projects:${NC}"
    echo -e "  Total: $total"
    echo -e "  Active: ${GREEN}$active${NC}"
    echo -e "  Completed: ${CYAN}$completed${NC}"
    echo -e "  Archived: ${GRAY}$archived${NC}"
    echo ""
    echo -e "${CYAN}Activity:${NC}"
    echo -e "  Total journal entries: $total_entries"
    echo -e "  Total milestones: $total_milestones"
    echo ""

    # Recent activity
    echo -e "${YELLOW}Recent Activity (last 7 days):${NC}"
    local week_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d' 2>/dev/null)

    jq -r --arg week "$week_ago" '
        .projects[] | select(.archived != true) |
        .name as $name |
        .entries[] | select(.date >= $week) |
        "\(.date)|\($name)|\(.content | .[0:60])"
    ' "$PROJECTS_FILE" 2>/dev/null | sort -r | head -10 | \
    while IFS='|' read -r date name content; do
        echo -e "  ${GRAY}$date${NC} ${GREEN}$name${NC}"
        echo -e "    $content"
    done

    if [[ $(jq -r --arg week "$week_ago" '[.projects[].entries[] | select(.date >= $week)] | length' "$PROJECTS_FILE" 2>/dev/null) -eq 0 ]]; then
        echo -e "  ${GRAY}No recent activity${NC}"
    fi
}

# Export project to markdown
export_project() {
    local project_query="$1"
    local output_file="$2"

    if [[ -z "$project_query" ]]; then
        echo "Usage: project-journal.sh export \"project\" [output.md]"
        exit 1
    fi

    # Find project
    local project_name=$(find_project "$project_query")
    if [[ -z "$project_name" ]]; then
        # Try archived
        project_name=$(jq -r --arg q "$project_query" '
            .projects[] | select(.name | ascii_downcase | contains($q | ascii_downcase)) | .name
        ' "$PROJECTS_FILE" | head -1)

        if [[ -z "$project_name" ]]; then
            echo -e "${RED}Project not found:${NC} $project_query"
            exit 1
        fi
    fi

    if [[ -z "$output_file" ]]; then
        # Generate filename
        local safe_name=$(echo "$project_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
        output_file="${safe_name}_journal.md"
    fi

    # Get full path
    if [[ ! "$output_file" = /* ]]; then
        output_file="$(pwd)/$output_file"
    fi

    local project=$(jq --arg name "$project_name" '.projects[] | select(.name == $name)' "$PROJECTS_FILE")

    {
        echo "# $project_name"
        echo ""
        echo "**Status:** $(echo "$project" | jq -r '.status')"
        echo "**Created:** $(echo "$project" | jq -r '.created')"

        local desc=$(echo "$project" | jq -r '.description // ""')
        if [[ -n "$desc" && "$desc" != "null" ]]; then
            echo ""
            echo "$desc"
        fi
        echo ""

        # Links
        local link_count=$(echo "$project" | jq '.links | length')
        if [[ "$link_count" -gt 0 ]]; then
            echo "## Links"
            echo ""
            echo "$project" | jq -r '.links[] | "- [\(.description // .url)](\(.url))"'
            echo ""
        fi

        # Milestones
        local milestone_count=$(echo "$project" | jq '.milestones | length')
        if [[ "$milestone_count" -gt 0 ]]; then
            echo "## Milestones"
            echo ""
            echo "$project" | jq -r '.milestones[] | "- [x] \(.description) *(\(.achieved | split(" ")[0]))*"'
            echo ""
        fi

        # Journal entries
        local entry_count=$(echo "$project" | jq '.entries | length')
        if [[ "$entry_count" -gt 0 ]]; then
            echo "## Journal"
            echo ""
            echo "$project" | jq -r '.entries | sort_by(.date) | reverse | .[] | "### \(.date)\n\n\(.content)\n"'
        fi

        echo "---"
        echo "*Exported from project-journal on $(date '+%Y-%m-%d')*"
    } > "$output_file"

    echo -e "${GREEN}Exported to:${NC} $output_file"
}

# Search across projects
search_projects() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: project-journal.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search: \"$query\" ===${NC}"
    echo ""

    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    # Search project names
    echo -e "${CYAN}Projects:${NC}"
    local found=0
    jq -r --arg q "$query_lower" '
        .projects[] |
        select(.name | ascii_downcase | contains($q)) |
        "\(.name)|\(.status)|\(.archived)"
    ' "$PROJECTS_FILE" | while IFS='|' read -r name status archived; do
        local tag=""
        [[ "$archived" == "true" ]] && tag=" ${GRAY}[archived]${NC}"
        echo -e "  ${GREEN}$name${NC} [$status]$tag"
        found=1
    done

    echo ""

    # Search entries
    echo -e "${CYAN}Journal Entries:${NC}"
    jq -r --arg q "$query_lower" '
        .projects[] |
        .name as $name |
        .entries[] |
        select(.content | ascii_downcase | contains($q)) |
        "\($name)|\(.date)|\(.content | .[0:80])"
    ' "$PROJECTS_FILE" 2>/dev/null | head -20 | while IFS='|' read -r name date content; do
        echo -e "  ${GREEN}$name${NC} ${GRAY}($date)${NC}"
        echo -e "    $content"
        echo ""
    done
}

# Show help
show_help() {
    echo "Project Journal - Track progress, notes, and milestones for projects"
    echo ""
    echo "Usage:"
    echo "  project-journal.sh new \"name\"              Create a new project"
    echo "  project-journal.sh list [-a|--archived]    List projects"
    echo "  project-journal.sh log \"proj\" \"entry\"      Add a journal entry"
    echo "  project-journal.sh milestone \"proj\" \"text\" Record a milestone"
    echo "  project-journal.sh view \"proj\" [limit]     View project details"
    echo "  project-journal.sh status \"proj\" [status]  View/set project status"
    echo "  project-journal.sh desc \"proj\" \"text\"      Set project description"
    echo "  project-journal.sh link \"proj\" \"url\" [desc]Add a related link"
    echo "  project-journal.sh search \"query\"          Search across projects"
    echo "  project-journal.sh stats                   Show statistics"
    echo "  project-journal.sh archive \"proj\"          Archive a project"
    echo "  project-journal.sh unarchive \"proj\"        Restore archived project"
    echo "  project-journal.sh export \"proj\" [file]    Export to markdown"
    echo "  project-journal.sh help                    Show this help"
    echo ""
    echo "Status values: active, paused, completed, blocked, on-hold"
    echo ""
    echo "Examples:"
    echo "  project-journal.sh new \"Website Redesign\""
    echo "  project-journal.sh log website \"Completed wireframes for homepage\""
    echo "  project-journal.sh log website \"Fixed #bug with navigation #frontend\""
    echo "  project-journal.sh milestone website \"v1.0 launched!\""
    echo "  project-journal.sh status website completed"
    echo "  project-journal.sh link website \"https://figma.com/...\" \"Design mockups\""
    echo ""
    echo "Tips:"
    echo "  - Use #tags in entries for easy categorization"
    echo "  - Project names can be abbreviated when logging"
}

# Main command handler
case "$1" in
    new|create|add)
        shift
        new_project "$@"
        ;;
    list|ls)
        list_projects "$2"
        ;;
    log|entry|note)
        shift
        add_entry "$@"
        ;;
    milestone|ms|achieve)
        shift
        add_milestone "$@"
        ;;
    view|show|v)
        shift
        view_project "$@"
        ;;
    status|st)
        shift
        set_status "$@"
        ;;
    desc|description)
        shift
        set_description "$@"
        ;;
    link|url)
        shift
        add_link "$@"
        ;;
    search|find|grep)
        shift
        search_projects "$@"
        ;;
    stats|statistics)
        show_stats
        ;;
    archive)
        archive_project "$2"
        ;;
    unarchive|restore)
        unarchive_project "$2"
        ;;
    export)
        shift
        export_project "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_projects
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'project-journal.sh help' for usage"
        exit 1
        ;;
esac
