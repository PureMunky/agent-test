#!/bin/bash
#
# Meeting Notes - Template generator and meeting note manager
#
# Usage:
#   meeting-notes.sh new "Meeting Title"                - Create new meeting notes
#   meeting-notes.sh list [n]                           - List recent meetings (default: 10)
#   meeting-notes.sh view <id>                          - View meeting notes
#   meeting-notes.sh edit <id>                          - Edit meeting notes in editor
#   meeting-notes.sh search "query"                     - Search meeting notes
#   meeting-notes.sh action-items [id]                  - List action items from meetings
#   meeting-notes.sh templates                          - List available templates
#   meeting-notes.sh template <name>                    - Use a specific template
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
NOTES_DIR="$DATA_DIR/notes"
INDEX_FILE="$DATA_DIR/index.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$NOTES_DIR"

# Initialize index file if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"meetings":[],"next_id":1}' > "$INDEX_FILE"
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

# Meeting templates
get_template() {
    local template_name="${1:-default}"

    case "$template_name" in
        standup|daily)
            cat << 'TEMPLATE'
## Daily Standup

**Date:** {{DATE}}
**Time:** {{TIME}}

### Yesterday
-

### Today
-

### Blockers
- None

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        one-on-one|1on1)
            cat << 'TEMPLATE'
## 1-on-1 Meeting

**Date:** {{DATE}}
**Time:** {{TIME}}
**With:**

---

### Check-in
- How are things going?
-

### Discussion Topics
1.

### Feedback
-

### Action Items
- [ ]

### Next Meeting Topics
-

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        retrospective|retro)
            cat << 'TEMPLATE'
## Retrospective

**Date:** {{DATE}}
**Sprint/Period:**
**Attendees:**

---

### What Went Well
-

### What Could Be Improved
-

### Action Items
- [ ]

### Key Metrics
-

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        brainstorm)
            cat << 'TEMPLATE'
## Brainstorming Session

**Date:** {{DATE}}
**Topic:** {{TITLE}}
**Attendees:**

---

### Problem Statement


### Ideas
1.
2.
3.

### Evaluation Criteria
-

### Selected Approach


### Next Steps
- [ ]

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        project-kickoff|kickoff)
            cat << 'TEMPLATE'
## Project Kickoff

**Date:** {{DATE}}
**Project:** {{TITLE}}
**Attendees:**

---

### Project Overview


### Goals & Objectives
1.
2.

### Scope
**In Scope:**
-

**Out of Scope:**
-

### Timeline
- Start:
- End:
- Key Milestones:
  -

### Roles & Responsibilities
| Role | Person | Responsibilities |
|------|--------|------------------|
|      |        |                  |

### Risks & Mitigation
-

### Action Items
- [ ]

### Next Meeting


---
*Generated with meeting-notes*
TEMPLATE
            ;;

        decision|adr)
            cat << 'TEMPLATE'
## Decision Record

**Date:** {{DATE}}
**Decision:** {{TITLE}}
**Attendees:**

---

### Context
Why is this decision needed?


### Options Considered

#### Option 1:
- Pros:
- Cons:

#### Option 2:
- Pros:
- Cons:

### Decision
We decided to:


### Rationale


### Consequences
-

### Action Items
- [ ]

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        default|*)
            cat << 'TEMPLATE'
## {{TITLE}}

**Date:** {{DATE}}
**Time:** {{TIME}}
**Attendees:**

---

### Agenda
1.
2.
3.

### Discussion Notes


### Decisions Made
-

### Action Items
- [ ]
- [ ]

### Follow-up
- Next meeting:
- Owner:

---
*Generated with meeting-notes*
TEMPLATE
            ;;
    esac
}

new_meeting() {
    local title="$*"
    local template="${MEETING_TEMPLATE:-default}"

    if [[ -z "$title" ]]; then
        echo "Usage: meeting-notes.sh new \"Meeting Title\""
        echo ""
        echo "Optional: Set template with MEETING_TEMPLATE env var"
        echo "  MEETING_TEMPLATE=standup meeting-notes.sh new \"Daily Standup\""
        exit 1
    fi

    local next_id=$(jq -r '.next_id' "$INDEX_FILE")
    local note_file="$NOTES_DIR/meeting_${next_id}.md"

    # Generate note from template
    local content=$(get_template "$template")
    content="${content//\{\{TITLE\}\}/$title}"
    content="${content//\{\{DATE\}\}/$TODAY}"
    content="${content//\{\{TIME\}\}/$(date +%H:%M)}"

    echo "$content" > "$note_file"

    # Update index
    jq --arg title "$title" \
       --arg file "meeting_${next_id}.md" \
       --arg date "$NOW" \
       --arg template "$template" \
       --argjson id "$next_id" '
        .meetings += [{
            "id": $id,
            "title": $title,
            "file": $file,
            "template": $template,
            "created": $date,
            "modified": $date
        }] |
        .next_id = ($id + 1)
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Created meeting notes #$next_id:${NC} $title"
    echo -e "${CYAN}File:${NC} $note_file"
    echo -e "${CYAN}Template:${NC} $template"
    echo ""

    # Open in editor if available
    local editor="${EDITOR:-${VISUAL:-nano}}"
    read -p "Open in editor? (Y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        $editor "$note_file"

        # Update modified time
        jq --argjson id "$next_id" --arg date "$(date '+%Y-%m-%d %H:%M')" '
            .meetings = [.meetings[] | if .id == $id then .modified = $date else . end]
        ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    fi
}

list_meetings() {
    local count=${1:-10}

    local total=$(jq '.meetings | length' "$INDEX_FILE")

    if [[ "$total" -eq 0 ]]; then
        echo "No meeting notes yet."
        echo "Create one with: meeting-notes.sh new \"Meeting Title\""
        exit 0
    fi

    echo -e "${BLUE}=== Recent Meetings (showing $count of $total) ===${NC}"
    echo ""

    jq -r ".meetings | sort_by(.created) | reverse | .[0:$count] | .[] | \"\(.id)|\(.title)|\(.created)|\(.template)\"" "$INDEX_FILE" | \
    while IFS='|' read -r id title created template; do
        # Truncate title if needed
        local display_title="$title"
        if [[ ${#display_title} -gt 50 ]]; then
            display_title="${display_title:0:47}..."
        fi

        echo -e "  ${YELLOW}[$id]${NC} ${GREEN}$display_title${NC}"
        echo -e "      ${GRAY}$created${NC} ${MAGENTA}($template)${NC}"
        echo ""
    done
}

view_meeting() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh view <id>"
        exit 1
    fi

    # Get meeting info
    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local note_file="$NOTES_DIR/$file"

    if [[ ! -f "$note_file" ]]; then
        echo -e "${RED}Note file not found: $note_file${NC}"
        exit 1
    fi

    # Display with less or cat
    if command -v less &> /dev/null && [[ -t 1 ]]; then
        less "$note_file"
    else
        cat "$note_file"
    fi
}

edit_meeting() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh edit <id>"
        exit 1
    fi

    # Get meeting info
    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local title=$(echo "$meeting" | jq -r '.title')
    local note_file="$NOTES_DIR/$file"

    if [[ ! -f "$note_file" ]]; then
        echo -e "${RED}Note file not found: $note_file${NC}"
        exit 1
    fi

    echo -e "${GREEN}Editing:${NC} $title"

    local editor="${EDITOR:-${VISUAL:-nano}}"
    $editor "$note_file"

    # Update modified time
    jq --argjson id "$id" --arg date "$(date '+%Y-%m-%d %H:%M')" '
        .meetings = [.meetings[] | if .id == $id then .modified = $date else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Updated meeting #$id${NC}"
}

search_meetings() {
    local query="$*"

    if [[ -z "$query" ]]; then
        echo "Usage: meeting-notes.sh search \"query\""
        exit 1
    fi

    echo -e "${BLUE}=== Search Results: \"$query\" ===${NC}"
    echo ""

    local found=0

    # Search in titles first
    local title_matches=$(jq -r --arg q "$query" '
        .meetings | map(select(.title | ascii_downcase | contains($q | ascii_downcase))) | .[] | "\(.id)|\(.title)|\(.created)"
    ' "$INDEX_FILE")

    if [[ -n "$title_matches" ]]; then
        echo -e "${CYAN}Title matches:${NC}"
        echo "$title_matches" | while IFS='|' read -r id title created; do
            echo -e "  ${YELLOW}[$id]${NC} $title ${GRAY}($created)${NC}"
            found=$((found + 1))
        done
        echo ""
    fi

    # Search in note content
    echo -e "${CYAN}Content matches:${NC}"
    for note_file in "$NOTES_DIR"/*.md; do
        if [[ -f "$note_file" ]]; then
            if grep -qi "$query" "$note_file" 2>/dev/null; then
                local filename=$(basename "$note_file")
                local id=$(jq -r --arg file "$filename" '.meetings[] | select(.file == $file) | .id' "$INDEX_FILE")
                local title=$(jq -r --arg file "$filename" '.meetings[] | select(.file == $file) | .title' "$INDEX_FILE")

                if [[ -n "$id" ]]; then
                    echo -e "  ${YELLOW}[$id]${NC} $title"
                    # Show matching lines
                    grep -i --color=always "$query" "$note_file" 2>/dev/null | head -3 | while read line; do
                        echo -e "      ${GRAY}$line${NC}"
                    done
                    found=$((found + 1))
                fi
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "  No matches found."
    fi
}

list_action_items() {
    local filter_id="$1"

    echo -e "${BLUE}=== Action Items ===${NC}"
    echo ""

    local found=0

    if [[ -n "$filter_id" ]]; then
        # Show action items from specific meeting
        local meeting=$(jq -r --argjson id "$filter_id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

        if [[ -z "$meeting" ]]; then
            echo -e "${RED}Meeting #$filter_id not found${NC}"
            exit 1
        fi

        local file=$(echo "$meeting" | jq -r '.file')
        local title=$(echo "$meeting" | jq -r '.title')
        local note_file="$NOTES_DIR/$file"

        echo -e "${GREEN}$title${NC} ${GRAY}(#$filter_id)${NC}"

        # Extract action items (lines starting with - [ ] or * [ ])
        grep -E '^\s*[-*]\s*\[\s*\]' "$note_file" 2>/dev/null | while read line; do
            echo -e "  ${YELLOW}○${NC} ${line#*] }"
            found=$((found + 1))
        done

        # Also show checked items
        grep -E '^\s*[-*]\s*\[[xX]\]' "$note_file" 2>/dev/null | while read line; do
            local item="${line#*] }"
            echo -e "  ${GREEN}✓${NC} ${GRAY}$item${NC}"
        done
    else
        # Show all uncompleted action items from all meetings
        jq -r '.meetings | sort_by(.created) | reverse | .[] | "\(.id)|\(.title)|\(.file)"' "$INDEX_FILE" | \
        while IFS='|' read -r id title file; do
            local note_file="$NOTES_DIR/$file"

            if [[ -f "$note_file" ]]; then
                local items=$(grep -E '^\s*[-*]\s*\[\s*\]' "$note_file" 2>/dev/null)

                if [[ -n "$items" ]]; then
                    echo -e "${GREEN}$title${NC} ${GRAY}(#$id)${NC}"
                    echo "$items" | while read line; do
                        echo -e "  ${YELLOW}○${NC} ${line#*] }"
                        found=$((found + 1))
                    done
                    echo ""
                fi
            fi
        done
    fi

    if [[ $found -eq 0 ]]; then
        echo "No uncompleted action items found."
    fi
}

list_templates() {
    echo -e "${BLUE}=== Available Templates ===${NC}"
    echo ""
    echo -e "  ${GREEN}default${NC}       General meeting notes with agenda and action items"
    echo -e "  ${GREEN}standup${NC}       Daily standup (yesterday, today, blockers)"
    echo -e "  ${GREEN}one-on-one${NC}    1-on-1 meeting template"
    echo -e "  ${GREEN}retrospective${NC} Sprint retrospective template"
    echo -e "  ${GREEN}brainstorm${NC}    Brainstorming session"
    echo -e "  ${GREEN}kickoff${NC}       Project kickoff meeting"
    echo -e "  ${GREEN}decision${NC}      Decision record / ADR format"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  MEETING_TEMPLATE=standup meeting-notes.sh new \"Daily Standup\""
    echo "  meeting-notes.sh template standup"
}

use_template() {
    local template="$1"
    shift
    local title="$*"

    if [[ -z "$template" ]]; then
        echo "Usage: meeting-notes.sh template <name> [\"Meeting Title\"]"
        echo ""
        echo "Run 'meeting-notes.sh templates' to see available templates."
        exit 1
    fi

    if [[ -z "$title" ]]; then
        # Use template name as title hint
        case "$template" in
            standup|daily) title="Daily Standup - $TODAY" ;;
            one-on-one|1on1) title="1-on-1 Meeting" ;;
            retrospective|retro) title="Retrospective" ;;
            brainstorm) title="Brainstorming Session" ;;
            kickoff) title="Project Kickoff" ;;
            decision|adr) title="Decision Record" ;;
            *) title="Meeting Notes" ;;
        esac
    fi

    MEETING_TEMPLATE="$template" new_meeting "$title"
}

remove_meeting() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh remove <id>"
        exit 1
    fi

    # Get meeting info
    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local title=$(echo "$meeting" | jq -r '.title')
    local note_file="$NOTES_DIR/$file"

    echo -e "${YELLOW}About to delete:${NC} $title"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Remove note file
    if [[ -f "$note_file" ]]; then
        rm "$note_file"
    fi

    # Remove from index
    jq --argjson id "$id" '.meetings = [.meetings[] | select(.id != $id)]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${RED}Deleted:${NC} $title"
}

show_help() {
    echo "Meeting Notes - Template generator and meeting note manager"
    echo ""
    echo "Usage:"
    echo "  meeting-notes.sh new \"Title\"       Create new meeting notes"
    echo "  meeting-notes.sh list [n]          List recent meetings (default: 10)"
    echo "  meeting-notes.sh view <id>         View meeting notes"
    echo "  meeting-notes.sh edit <id>         Edit meeting notes"
    echo "  meeting-notes.sh search \"query\"    Search in notes"
    echo "  meeting-notes.sh action-items [id] List action items"
    echo "  meeting-notes.sh templates         List available templates"
    echo "  meeting-notes.sh template <name>   Create with specific template"
    echo "  meeting-notes.sh remove <id>       Delete meeting notes"
    echo "  meeting-notes.sh help              Show this help"
    echo ""
    echo "Templates: default, standup, one-on-one, retrospective, brainstorm, kickoff, decision"
    echo ""
    echo "Examples:"
    echo "  meeting-notes.sh new \"Weekly Team Sync\""
    echo "  meeting-notes.sh template standup"
    echo "  meeting-notes.sh template kickoff \"Project Alpha\""
    echo "  meeting-notes.sh action-items"
}

case "$1" in
    new|create|add)
        shift
        new_meeting "$@"
        ;;
    list|ls)
        list_meetings "$2"
        ;;
    view|show|cat)
        view_meeting "$2"
        ;;
    edit)
        edit_meeting "$2"
        ;;
    search|find)
        shift
        search_meetings "$@"
        ;;
    action-items|actions|todos)
        list_action_items "$2"
        ;;
    templates)
        list_templates
        ;;
    template|tpl)
        shift
        use_template "$@"
        ;;
    remove|rm|delete)
        remove_meeting "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_meetings 5
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'meeting-notes.sh help' for usage"
        exit 1
        ;;
esac
