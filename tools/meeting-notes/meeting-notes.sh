#!/bin/bash
#
# Meeting Notes v2.0 - Enhanced meeting notes with attendees, series, export, archive, and statistics
#
# New in v2.0:
#   - Attendees tracking with contact integration
#   - Meeting series for recurring meetings (link daily standups, weekly syncs)
#   - Export to markdown/HTML
#   - Archive system for old meetings
#   - Statistics (meetings per week, common attendees, action item completion)
#   - Quick meeting creation with --attendees flag
#
# Usage:
#   meeting-notes.sh new "Meeting Title" [--attendees "name1,name2"] [--series "name"]
#   meeting-notes.sh list [n] [--series "name"] [--archived]
#   meeting-notes.sh view <id>
#   meeting-notes.sh edit <id>
#   meeting-notes.sh search "query"
#   meeting-notes.sh action-items [id] [--all]
#   meeting-notes.sh complete <meeting_id> <action_num>
#   meeting-notes.sh templates
#   meeting-notes.sh template <name> [title]
#   meeting-notes.sh series [name]
#   meeting-notes.sh series add "name" [--description "desc"]
#   meeting-notes.sh archive <id>
#   meeting-notes.sh unarchive <id>
#   meeting-notes.sh export <id> [--format md|html]
#   meeting-notes.sh stats
#   meeting-notes.sh remove <id>
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
NOTES_DIR="$DATA_DIR/notes"
ARCHIVE_DIR="$DATA_DIR/archive"
INDEX_FILE="$DATA_DIR/index.json"
SERIES_FILE="$DATA_DIR/series.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$NOTES_DIR" "$ARCHIVE_DIR"

# Initialize index file if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"meetings":[],"next_id":1}' > "$INDEX_FILE"
fi

# Initialize series file if it doesn't exist
if [[ ! -f "$SERIES_FILE" ]]; then
    echo '{"series":[]}' > "$SERIES_FILE"
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

# Migrate from v1 to v2 (add missing fields)
migrate_if_needed() {
    # Check if migration needed by looking for v2 fields
    local needs_migration=$(jq -r '.meetings[0] | has("attendees") | not' "$INDEX_FILE" 2>/dev/null)

    if [[ "$needs_migration" == "true" ]] && [[ $(jq '.meetings | length' "$INDEX_FILE") -gt 0 ]]; then
        echo -e "${CYAN}Migrating to v2 format...${NC}"
        jq '.meetings = [.meetings[] | . + {attendees: (.attendees // []), series: (.series // null), archived: (.archived // false)}]' \
            "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
        echo -e "${GREEN}Migration complete.${NC}"
    fi
}

migrate_if_needed

# Meeting templates
get_template() {
    local template_name="${1:-default}"

    case "$template_name" in
        standup|daily)
            cat << 'TEMPLATE'
## Daily Standup

**Date:** {{DATE}}
**Time:** {{TIME}}
**Attendees:** {{ATTENDEES}}

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
**Attendees:** {{ATTENDEES}}

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
**Attendees:** {{ATTENDEES}}

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
**Attendees:** {{ATTENDEES}}

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
**Attendees:** {{ATTENDEES}}

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
**Attendees:** {{ATTENDEES}}

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

        weekly-sync|weekly)
            cat << 'TEMPLATE'
## Weekly Sync

**Date:** {{DATE}}
**Time:** {{TIME}}
**Attendees:** {{ATTENDEES}}

---

### Last Week Highlights
-

### This Week Focus
-

### Key Updates
-

### Blockers / Risks
-

### Action Items
- [ ]

### Announcements
-

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        interview)
            cat << 'TEMPLATE'
## Interview Notes

**Date:** {{DATE}}
**Candidate:** {{TITLE}}
**Position:**
**Interviewers:** {{ATTENDEES}}

---

### Background
-

### Technical Assessment
**Strengths:**
-

**Areas for Growth:**
-

### Culture Fit
-

### Questions Asked
1.

### Candidate Questions
-

### Overall Assessment
Rating: /5

### Recommendation
[ ] Strong Hire  [ ] Hire  [ ] No Hire  [ ] Strong No Hire

### Notes
-

---
*Generated with meeting-notes*
TEMPLATE
            ;;

        default|*)
            cat << 'TEMPLATE'
## {{TITLE}}

**Date:** {{DATE}}
**Time:** {{TIME}}
**Attendees:** {{ATTENDEES}}

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
    local title=""
    local attendees=""
    local series=""
    local template="${MEETING_TEMPLATE:-default}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --attendees|-a)
                attendees="$2"
                shift 2
                ;;
            --series|-s)
                series="$2"
                shift 2
                ;;
            --template|-t)
                template="$2"
                shift 2
                ;;
            *)
                if [[ -z "$title" ]]; then
                    title="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "Usage: meeting-notes.sh new \"Meeting Title\" [--attendees \"name1,name2\"] [--series \"name\"]"
        echo ""
        echo "Options:"
        echo "  --attendees, -a    Comma-separated list of attendees"
        echo "  --series, -s       Link to a meeting series"
        echo "  --template, -t     Use specific template"
        exit 1
    fi

    # Validate series if provided
    if [[ -n "$series" ]]; then
        local series_exists=$(jq -r --arg name "$series" '.series | map(select(.name == $name)) | length' "$SERIES_FILE")
        if [[ "$series_exists" -eq 0 ]]; then
            echo -e "${YELLOW}Series '$series' not found. Create it? (Y/n)${NC}"
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                add_series "$series"
            else
                series=""
            fi
        fi
    fi

    local next_id=$(jq -r '.next_id' "$INDEX_FILE")
    local note_file="$NOTES_DIR/meeting_${next_id}.md"

    # Format attendees for display
    local attendees_display=""
    if [[ -n "$attendees" ]]; then
        attendees_display=$(echo "$attendees" | tr ',' ', ')
    fi

    # Generate note from template
    local content=$(get_template "$template")
    content="${content//\{\{TITLE\}\}/$title}"
    content="${content//\{\{DATE\}\}/$TODAY}"
    content="${content//\{\{TIME\}\}/$(date +%H:%M)}"
    content="${content//\{\{ATTENDEES\}\}/$attendees_display}"

    echo "$content" > "$note_file"

    # Convert attendees to JSON array
    local attendees_json="[]"
    if [[ -n "$attendees" ]]; then
        attendees_json=$(echo "$attendees" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
    fi

    # Update index
    local series_json="null"
    if [[ -n "$series" ]]; then
        series_json="\"$series\""
    fi

    jq --arg title "$title" \
       --arg file "meeting_${next_id}.md" \
       --arg date "$NOW" \
       --arg template "$template" \
       --argjson attendees "$attendees_json" \
       --argjson series "$series_json" \
       --argjson id "$next_id" '
        .meetings += [{
            "id": $id,
            "title": $title,
            "file": $file,
            "template": $template,
            "created": $date,
            "modified": $date,
            "attendees": $attendees,
            "series": $series,
            "archived": false
        }] |
        .next_id = ($id + 1)
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    # Update series last meeting date
    if [[ -n "$series" ]]; then
        jq --arg name "$series" --arg date "$NOW" --argjson id "$next_id" '
            .series = [.series[] | if .name == $name then .last_meeting = $date | .meeting_ids = (.meeting_ids + [$id]) else . end]
        ' "$SERIES_FILE" > "$SERIES_FILE.tmp" && mv "$SERIES_FILE.tmp" "$SERIES_FILE"
    fi

    echo -e "${GREEN}Created meeting notes #$next_id:${NC} $title"
    echo -e "${CYAN}File:${NC} $note_file"
    echo -e "${CYAN}Template:${NC} $template"
    if [[ -n "$attendees" ]]; then
        echo -e "${CYAN}Attendees:${NC} $attendees_display"
    fi
    if [[ -n "$series" ]]; then
        echo -e "${CYAN}Series:${NC} $series"
    fi
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
    local count=10
    local filter_series=""
    local show_archived=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --series|-s)
                filter_series="$2"
                shift 2
                ;;
            --archived|-a)
                show_archived=true
                shift
                ;;
            [0-9]*)
                count="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    local query='.meetings'

    if [[ "$show_archived" == "true" ]]; then
        query="$query | map(select(.archived == true))"
    else
        query="$query | map(select(.archived != true))"
    fi

    if [[ -n "$filter_series" ]]; then
        query="$query | map(select(.series == \"$filter_series\"))"
    fi

    local total=$(jq "$query | length" "$INDEX_FILE")

    if [[ "$total" -eq 0 ]]; then
        if [[ "$show_archived" == "true" ]]; then
            echo "No archived meetings."
        elif [[ -n "$filter_series" ]]; then
            echo "No meetings in series '$filter_series'."
        else
            echo "No meeting notes yet."
            echo "Create one with: meeting-notes.sh new \"Meeting Title\""
        fi
        exit 0
    fi

    local header="Recent Meetings"
    if [[ "$show_archived" == "true" ]]; then
        header="Archived Meetings"
    elif [[ -n "$filter_series" ]]; then
        header="Series: $filter_series"
    fi

    echo -e "${BLUE}=== $header (showing $count of $total) ===${NC}"
    echo ""

    jq -r "$query | sort_by(.created) | reverse | .[0:$count] | .[] | \"\(.id)|\(.title)|\(.created)|\(.template)|\(.attendees | join(\", \"))|\(.series // \"\")\"" "$INDEX_FILE" | \
    while IFS='|' read -r id title created template attendees series; do
        # Truncate title if needed
        local display_title="$title"
        if [[ ${#display_title} -gt 45 ]]; then
            display_title="${display_title:0:42}..."
        fi

        echo -e "  ${YELLOW}[$id]${NC} ${GREEN}$display_title${NC}"
        echo -ne "      ${GRAY}$created${NC} ${MAGENTA}($template)${NC}"
        if [[ -n "$series" ]]; then
            echo -ne " ${CYAN}[$series]${NC}"
        fi
        echo ""
        if [[ -n "$attendees" ]]; then
            echo -e "      ${GRAY}Attendees: $attendees${NC}"
        fi
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
    local archived=$(echo "$meeting" | jq -r '.archived')
    local note_file="$NOTES_DIR/$file"

    if [[ "$archived" == "true" ]]; then
        note_file="$ARCHIVE_DIR/$file"
    fi

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
    local archived=$(echo "$meeting" | jq -r '.archived')
    local note_file="$NOTES_DIR/$file"

    if [[ "$archived" == "true" ]]; then
        echo -e "${YELLOW}Note: This meeting is archived. Unarchive to edit.${NC}"
        exit 1
    fi

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
        .meetings | map(select(.archived != true)) | map(select(.title | ascii_downcase | contains($q | ascii_downcase))) | .[] | "\(.id)|\(.title)|\(.created)"
    ' "$INDEX_FILE")

    if [[ -n "$title_matches" ]]; then
        echo -e "${CYAN}Title matches:${NC}"
        echo "$title_matches" | while IFS='|' read -r id title created; do
            echo -e "  ${YELLOW}[$id]${NC} $title ${GRAY}($created)${NC}"
            found=$((found + 1))
        done
        echo ""
    fi

    # Search in attendees
    local attendee_matches=$(jq -r --arg q "$query" '
        .meetings | map(select(.archived != true)) | map(select(.attendees | map(ascii_downcase) | any(contains($q | ascii_downcase)))) | .[] | "\(.id)|\(.title)|\(.attendees | join(", "))"
    ' "$INDEX_FILE")

    if [[ -n "$attendee_matches" ]]; then
        echo -e "${CYAN}Attendee matches:${NC}"
        echo "$attendee_matches" | while IFS='|' read -r id title attendees; do
            echo -e "  ${YELLOW}[$id]${NC} $title ${GRAY}(with: $attendees)${NC}"
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
                local id=$(jq -r --arg file "$filename" '.meetings[] | select(.file == $file and .archived != true) | .id' "$INDEX_FILE")
                local title=$(jq -r --arg file "$filename" '.meetings[] | select(.file == $file and .archived != true) | .title' "$INDEX_FILE")

                if [[ -n "$id" && "$id" != "null" ]]; then
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
    local filter_id=""
    local show_all=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)
                show_all=true
                shift
                ;;
            [0-9]*)
                filter_id="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

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
        local archived=$(echo "$meeting" | jq -r '.archived')
        local note_file="$NOTES_DIR/$file"

        if [[ "$archived" == "true" ]]; then
            note_file="$ARCHIVE_DIR/$file"
        fi

        echo -e "${GREEN}$title${NC} ${GRAY}(#$filter_id)${NC}"
        echo ""

        # Extract action items (lines starting with - [ ] or * [ ])
        local item_num=1
        grep -nE '^\s*[-*]\s*\[\s*\]' "$note_file" 2>/dev/null | while read line; do
            local content=$(echo "$line" | sed 's/^[0-9]*:\s*[-*]\s*\[\s*\]\s*//')
            echo -e "  ${YELLOW}$item_num.${NC} ○ $content"
            item_num=$((item_num + 1))
            found=$((found + 1))
        done

        # Also show checked items if --all
        if [[ "$show_all" == "true" ]]; then
            echo ""
            echo -e "${GRAY}Completed:${NC}"
            grep -E '^\s*[-*]\s*\[[xX]\]' "$note_file" 2>/dev/null | while read line; do
                local item="${line#*] }"
                echo -e "  ${GREEN}✓${NC} ${GRAY}$item${NC}"
            done
        fi
    else
        # Show all uncompleted action items from all meetings
        jq -r '.meetings | map(select(.archived != true)) | sort_by(.created) | reverse | .[] | "\(.id)|\(.title)|\(.file)"' "$INDEX_FILE" | \
        while IFS='|' read -r id title file; do
            local note_file="$NOTES_DIR/$file"

            if [[ -f "$note_file" ]]; then
                local items=$(grep -E '^\s*[-*]\s*\[\s*\]' "$note_file" 2>/dev/null)

                if [[ -n "$items" ]]; then
                    echo -e "${GREEN}$title${NC} ${GRAY}(#$id)${NC}"
                    echo "$items" | while read line; do
                        local content=$(echo "$line" | sed 's/^\s*[-*]\s*\[\s*\]\s*//')
                        echo -e "  ${YELLOW}○${NC} $content"
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

complete_action_item() {
    local meeting_id="$1"
    local action_num="$2"

    if [[ -z "$meeting_id" || -z "$action_num" ]]; then
        echo "Usage: meeting-notes.sh complete <meeting_id> <action_number>"
        echo ""
        echo "First run 'meeting-notes.sh action-items <meeting_id>' to see numbered items."
        exit 1
    fi

    # Get meeting info
    local meeting=$(jq -r --argjson id "$meeting_id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$meeting_id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local note_file="$NOTES_DIR/$file"

    if [[ ! -f "$note_file" ]]; then
        echo -e "${RED}Note file not found${NC}"
        exit 1
    fi

    # Find and mark the nth action item as complete
    local line_num=$(grep -nE '^\s*[-*]\s*\[\s*\]' "$note_file" | sed -n "${action_num}p" | cut -d: -f1)

    if [[ -z "$line_num" ]]; then
        echo -e "${RED}Action item #$action_num not found${NC}"
        exit 1
    fi

    # Replace [ ] with [x] on that line
    sed -i "${line_num}s/\[ \]/[x]/" "$note_file"

    local item_text=$(sed -n "${line_num}p" "$note_file" | sed 's/^.*\[x\]\s*//')
    echo -e "${GREEN}✓ Completed:${NC} $item_text"

    # Update modified time
    jq --argjson id "$meeting_id" --arg date "$(date '+%Y-%m-%d %H:%M')" '
        .meetings = [.meetings[] | if .id == $id then .modified = $date else . end]
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
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
    echo -e "  ${GREEN}weekly${NC}        Weekly team sync meeting"
    echo -e "  ${GREEN}interview${NC}     Interview notes with assessment"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  MEETING_TEMPLATE=standup meeting-notes.sh new \"Daily Standup\""
    echo "  meeting-notes.sh template standup"
    echo "  meeting-notes.sh new \"Meeting\" --template weekly"
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
            weekly|weekly-sync) title="Weekly Sync - $TODAY" ;;
            interview) title="Interview" ;;
            *) title="Meeting Notes" ;;
        esac
    fi

    MEETING_TEMPLATE="$template" new_meeting "$title"
}

# Series management
add_series() {
    local name="$1"
    local description="${2:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: meeting-notes.sh series add \"name\" [--description \"desc\"]"
        exit 1
    fi

    # Check if exists
    local exists=$(jq -r --arg name "$name" '.series | map(select(.name == $name)) | length' "$SERIES_FILE")
    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Series '$name' already exists.${NC}"
        exit 1
    fi

    jq --arg name "$name" --arg desc "$description" --arg date "$NOW" '
        .series += [{
            name: $name,
            description: $desc,
            created: $date,
            last_meeting: null,
            meeting_ids: []
        }]
    ' "$SERIES_FILE" > "$SERIES_FILE.tmp" && mv "$SERIES_FILE.tmp" "$SERIES_FILE"

    echo -e "${GREEN}Created series:${NC} $name"
}

list_series() {
    local filter="$1"

    if [[ -n "$filter" ]]; then
        # Show meetings in this series
        list_meetings --series "$filter"
        return
    fi

    local count=$(jq '.series | length' "$SERIES_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No meeting series yet."
        echo "Create one with: meeting-notes.sh series add \"Weekly Standup\""
        exit 0
    fi

    echo -e "${BLUE}=== Meeting Series ===${NC}"
    echo ""

    jq -r '.series[] | "\(.name)|\(.description)|\(.meeting_ids | length)|\(.last_meeting // "never")"' "$SERIES_FILE" | \
    while IFS='|' read -r name desc count last; do
        echo -e "  ${GREEN}$name${NC}"
        if [[ -n "$desc" ]]; then
            echo -e "    ${GRAY}$desc${NC}"
        fi
        echo -e "    ${CYAN}$count meetings${NC} - Last: ${GRAY}$last${NC}"
        echo ""
    done
}

remove_series() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: meeting-notes.sh series remove \"name\""
        exit 1
    fi

    # Check if exists
    local exists=$(jq -r --arg name "$name" '.series | map(select(.name == $name)) | length' "$SERIES_FILE")
    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Series '$name' not found.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Remove series '$name'?${NC}"
    echo "(Meetings will be unlinked but not deleted)"
    read -p "(y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Remove series
    jq --arg name "$name" '.series = [.series[] | select(.name != $name)]' "$SERIES_FILE" > "$SERIES_FILE.tmp" && mv "$SERIES_FILE.tmp" "$SERIES_FILE"

    # Unlink meetings
    jq --arg name "$name" '.meetings = [.meetings[] | if .series == $name then .series = null else . end]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Removed series:${NC} $name"
}

# Archive management
archive_meeting() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh archive <id>"
        exit 1
    fi

    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local title=$(echo "$meeting" | jq -r '.title')
    local archived=$(echo "$meeting" | jq -r '.archived')

    if [[ "$archived" == "true" ]]; then
        echo -e "${YELLOW}Meeting is already archived.${NC}"
        exit 0
    fi

    # Move file to archive
    if [[ -f "$NOTES_DIR/$file" ]]; then
        mv "$NOTES_DIR/$file" "$ARCHIVE_DIR/$file"
    fi

    # Update index
    jq --argjson id "$id" '.meetings = [.meetings[] | if .id == $id then .archived = true else . end]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Archived:${NC} $title"
}

unarchive_meeting() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh unarchive <id>"
        exit 1
    fi

    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local title=$(echo "$meeting" | jq -r '.title')
    local archived=$(echo "$meeting" | jq -r '.archived')

    if [[ "$archived" != "true" ]]; then
        echo -e "${YELLOW}Meeting is not archived.${NC}"
        exit 0
    fi

    # Move file back
    if [[ -f "$ARCHIVE_DIR/$file" ]]; then
        mv "$ARCHIVE_DIR/$file" "$NOTES_DIR/$file"
    fi

    # Update index
    jq --argjson id "$id" '.meetings = [.meetings[] | if .id == $id then .archived = false else . end]' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

    echo -e "${GREEN}Unarchived:${NC} $title"
}

# Export meeting
export_meeting() {
    local id=""
    local format="md"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format|-f)
                format="$2"
                shift 2
                ;;
            [0-9]*)
                id="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$id" ]]; then
        echo "Usage: meeting-notes.sh export <id> [--format md|html]"
        exit 1
    fi

    local meeting=$(jq -r --argjson id "$id" '.meetings[] | select(.id == $id)' "$INDEX_FILE")

    if [[ -z "$meeting" ]]; then
        echo -e "${RED}Meeting #$id not found${NC}"
        exit 1
    fi

    local file=$(echo "$meeting" | jq -r '.file')
    local title=$(echo "$meeting" | jq -r '.title')
    local archived=$(echo "$meeting" | jq -r '.archived')
    local note_file="$NOTES_DIR/$file"

    if [[ "$archived" == "true" ]]; then
        note_file="$ARCHIVE_DIR/$file"
    fi

    if [[ ! -f "$note_file" ]]; then
        echo -e "${RED}Note file not found${NC}"
        exit 1
    fi

    # Create safe filename
    local safe_title=$(echo "$title" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    local output_file="meeting_${id}_${safe_title}.${format}"

    if [[ "$format" == "html" ]]; then
        # Convert to HTML
        if command -v pandoc &> /dev/null; then
            pandoc -f markdown -t html --standalone -o "$output_file" "$note_file"
        else
            # Basic HTML conversion without pandoc
            echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>$title</title>" > "$output_file"
            echo "<style>body{font-family:sans-serif;max-width:800px;margin:auto;padding:20px;}" >> "$output_file"
            echo "h2{color:#333;}pre{background:#f4f4f4;padding:10px;}</style></head><body>" >> "$output_file"
            # Basic markdown to HTML (simplified)
            sed 's/^## \(.*\)/<h2>\1<\/h2>/g; s/^### \(.*\)/<h3>\1<\/h3>/g; s/^\*\*\(.*\)\*\*/<strong>\1<\/strong>/g; s/^- \(.*\)/<li>\1<\/li>/g; s/^$/<br>/g' "$note_file" >> "$output_file"
            echo "</body></html>" >> "$output_file"
        fi
    else
        # Just copy markdown
        cp "$note_file" "$output_file"
    fi

    echo -e "${GREEN}Exported to:${NC} $output_file"
}

# Statistics
show_stats() {
    echo -e "${BLUE}=== Meeting Statistics ===${NC}"
    echo ""

    local total=$(jq '.meetings | length' "$INDEX_FILE")
    local active=$(jq '.meetings | map(select(.archived != true)) | length' "$INDEX_FILE")
    local archived=$(jq '.meetings | map(select(.archived == true)) | length' "$INDEX_FILE")

    echo -e "${CYAN}Overview:${NC}"
    echo -e "  Total meetings: ${GREEN}$total${NC}"
    echo -e "  Active: ${GREEN}$active${NC}  |  Archived: ${GRAY}$archived${NC}"
    echo ""

    # Meetings this week/month
    local week_ago=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null)
    local month_ago=$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null)

    if [[ -n "$week_ago" ]]; then
        local this_week=$(jq -r --arg date "$week_ago" '.meetings | map(select(.created > $date and .archived != true)) | length' "$INDEX_FILE")
        local this_month=$(jq -r --arg date "$month_ago" '.meetings | map(select(.created > $date and .archived != true)) | length' "$INDEX_FILE")
        echo -e "${CYAN}Activity:${NC}"
        echo -e "  This week: ${GREEN}$this_week${NC} meetings"
        echo -e "  This month: ${GREEN}$this_month${NC} meetings"
        echo ""
    fi

    # Templates used
    echo -e "${CYAN}Templates Used:${NC}"
    jq -r '.meetings | group_by(.template) | map({template: .[0].template, count: length}) | sort_by(-.count) | .[:5] | .[] | "  \(.template): \(.count)"' "$INDEX_FILE"
    echo ""

    # Top attendees
    echo -e "${CYAN}Top Attendees:${NC}"
    jq -r '.meetings | map(.attendees) | flatten | group_by(.) | map({name: .[0], count: length}) | sort_by(-.count) | .[:5] | .[] | "  \(.name): \(.count) meetings"' "$INDEX_FILE" 2>/dev/null || echo "  No attendee data"
    echo ""

    # Action items
    local total_open=0
    local total_done=0
    for note_file in "$NOTES_DIR"/*.md; do
        if [[ -f "$note_file" ]]; then
            local open=$(grep -cE '^\s*[-*]\s*\[\s*\]' "$note_file" 2>/dev/null || echo 0)
            local done=$(grep -cE '^\s*[-*]\s*\[[xX]\]' "$note_file" 2>/dev/null || echo 0)
            total_open=$((total_open + open))
            total_done=$((total_done + done))
        fi
    done

    echo -e "${CYAN}Action Items:${NC}"
    echo -e "  Open: ${YELLOW}$total_open${NC}"
    echo -e "  Completed: ${GREEN}$total_done${NC}"
    if [[ $((total_open + total_done)) -gt 0 ]]; then
        local pct=$((total_done * 100 / (total_open + total_done)))
        echo -e "  Completion rate: ${GREEN}$pct%${NC}"
    fi
    echo ""

    # Series stats
    local series_count=$(jq '.series | length' "$SERIES_FILE")
    if [[ "$series_count" -gt 0 ]]; then
        echo -e "${CYAN}Meeting Series:${NC}"
        jq -r '.series | sort_by(-.meeting_ids | length) | .[:3] | .[] | "  \(.name): \(.meeting_ids | length) meetings"' "$SERIES_FILE"
    fi
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
    local series=$(echo "$meeting" | jq -r '.series')
    local archived=$(echo "$meeting" | jq -r '.archived')
    local note_file="$NOTES_DIR/$file"

    if [[ "$archived" == "true" ]]; then
        note_file="$ARCHIVE_DIR/$file"
    fi

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

    # Remove from series if applicable
    if [[ -n "$series" && "$series" != "null" ]]; then
        jq --arg name "$series" --argjson id "$id" '
            .series = [.series[] | if .name == $name then .meeting_ids = [.meeting_ids[] | select(. != $id)] else . end]
        ' "$SERIES_FILE" > "$SERIES_FILE.tmp" && mv "$SERIES_FILE.tmp" "$SERIES_FILE"
    fi

    echo -e "${RED}Deleted:${NC} $title"
}

show_help() {
    echo "Meeting Notes v2.0 - Template generator and meeting note manager"
    echo ""
    echo "Usage:"
    echo "  meeting-notes.sh new \"Title\" [options]     Create new meeting notes"
    echo "    --attendees, -a \"names\"                  Comma-separated attendees"
    echo "    --series, -s \"name\"                      Link to meeting series"
    echo "    --template, -t \"name\"                    Use specific template"
    echo ""
    echo "  meeting-notes.sh list [n] [options]        List recent meetings"
    echo "    --series \"name\"                          Filter by series"
    echo "    --archived                               Show archived meetings"
    echo ""
    echo "  meeting-notes.sh view <id>                 View meeting notes"
    echo "  meeting-notes.sh edit <id>                 Edit meeting notes"
    echo "  meeting-notes.sh search \"query\"            Search in notes"
    echo "  meeting-notes.sh remove <id>               Delete meeting notes"
    echo ""
    echo "  meeting-notes.sh action-items [id]         List action items"
    echo "    --all                                    Include completed items"
    echo "  meeting-notes.sh complete <id> <num>       Mark action item done"
    echo ""
    echo "  meeting-notes.sh templates                 List available templates"
    echo "  meeting-notes.sh template <name> [title]   Create with template"
    echo ""
    echo "  meeting-notes.sh series                    List meeting series"
    echo "  meeting-notes.sh series add \"name\"         Create new series"
    echo "  meeting-notes.sh series remove \"name\"      Delete a series"
    echo ""
    echo "  meeting-notes.sh archive <id>              Archive a meeting"
    echo "  meeting-notes.sh unarchive <id>            Restore from archive"
    echo ""
    echo "  meeting-notes.sh export <id> [--format]    Export meeting (md/html)"
    echo "  meeting-notes.sh stats                     Show statistics"
    echo "  meeting-notes.sh help                      Show this help"
    echo ""
    echo "Templates: default, standup, one-on-one, retrospective, brainstorm,"
    echo "           kickoff, decision, weekly, interview"
    echo ""
    echo "Examples:"
    echo "  meeting-notes.sh new \"Weekly Team Sync\" --attendees \"Alice, Bob\""
    echo "  meeting-notes.sh new \"Daily Standup\" --series \"Engineering Standup\""
    echo "  meeting-notes.sh template standup"
    echo "  meeting-notes.sh list --series \"Engineering Standup\""
    echo "  meeting-notes.sh complete 5 2"
    echo "  meeting-notes.sh export 10 --format html"
}

case "$1" in
    new|create|add)
        shift
        new_meeting "$@"
        ;;
    list|ls)
        shift
        list_meetings "$@"
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
        shift
        list_action_items "$@"
        ;;
    complete|done|check)
        complete_action_item "$2" "$3"
        ;;
    templates)
        list_templates
        ;;
    template|tpl)
        shift
        use_template "$@"
        ;;
    series)
        case "$2" in
            add|new|create)
                shift 2
                desc=""
                name=""
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --description|-d)
                            desc="$2"
                            shift 2
                            ;;
                        *)
                            name="$1"
                            shift
                            ;;
                    esac
                done
                add_series "$name" "$desc"
                ;;
            remove|rm|delete)
                remove_series "$3"
                ;;
            *)
                list_series "$2"
                ;;
        esac
        ;;
    archive)
        archive_meeting "$2"
        ;;
    unarchive|restore)
        unarchive_meeting "$2"
        ;;
    export)
        shift
        export_meeting "$@"
        ;;
    stats|statistics)
        show_stats
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
