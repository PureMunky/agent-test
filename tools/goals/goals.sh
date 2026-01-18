#!/bin/bash
#
# Goals - Long-term goal setting and progress tracking
#
# Usage:
#   goals.sh add "goal title" [deadline]       - Add a new goal (deadline: YYYY-MM-DD)
#   goals.sh list                              - List all active goals
#   goals.sh show <id>                         - Show goal details
#   goals.sh progress <id> <percent>           - Update goal progress (0-100)
#   goals.sh milestone <id> "milestone desc"   - Add a milestone to a goal
#   goals.sh check <id> <milestone_id>         - Mark a milestone complete
#   goals.sh note <id> "note text"             - Add a note to a goal
#   goals.sh complete <id>                     - Mark goal as achieved
#   goals.sh abandon <id>                      - Archive an abandoned goal
#   goals.sh archive                           - Show archived goals
#   goals.sh stats                             - Show goal statistics
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
GOALS_FILE="$DATA_DIR/goals.json"

mkdir -p "$DATA_DIR"

# Initialize goals file if it doesn't exist
if [[ ! -f "$GOALS_FILE" ]]; then
    echo '{"goals":[],"next_id":1,"archived":[]}' > "$GOALS_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

TODAY=$(date +%Y-%m-%d)

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Progress bar function
progress_bar() {
    local percent=$1
    local width=20
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"
}

# Calculate days remaining
days_remaining() {
    local deadline="$1"
    if [[ -z "$deadline" ]] || [[ "$deadline" == "null" ]]; then
        echo "no deadline"
        return
    fi

    local deadline_epoch=$(date -d "$deadline" +%s 2>/dev/null)
    local today_epoch=$(date -d "$TODAY" +%s 2>/dev/null)

    if [[ -z "$deadline_epoch" ]]; then
        echo "invalid date"
        return
    fi

    local diff=$(( (deadline_epoch - today_epoch) / 86400 ))

    if [[ $diff -lt 0 ]]; then
        echo "${RED}${diff#-} days overdue${NC}"
    elif [[ $diff -eq 0 ]]; then
        echo "${YELLOW}due today${NC}"
    elif [[ $diff -eq 1 ]]; then
        echo "1 day left"
    else
        echo "$diff days left"
    fi
}

add_goal() {
    local title="$1"
    local deadline="$2"

    if [[ -z "$title" ]]; then
        echo "Usage: goals.sh add \"goal title\" [deadline YYYY-MM-DD]"
        exit 1
    fi

    # Validate deadline if provided
    if [[ -n "$deadline" ]]; then
        if ! date -d "$deadline" &>/dev/null; then
            echo -e "${RED}Invalid date format. Use YYYY-MM-DD${NC}"
            exit 1
        fi
    fi

    local next_id=$(jq -r '.next_id' "$GOALS_FILE")
    local created=$(date '+%Y-%m-%d %H:%M')

    jq --arg title "$title" \
       --arg deadline "$deadline" \
       --arg created "$created" \
       --argjson id "$next_id" '
        .goals += [{
            "id": $id,
            "title": $title,
            "deadline": (if $deadline == "" then null else $deadline end),
            "created": $created,
            "progress": 0,
            "milestones": [],
            "notes": [],
            "status": "active"
        }] |
        .next_id = ($id + 1)
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    echo -e "${GREEN}Goal #$next_id added:${NC} $title"
    if [[ -n "$deadline" ]]; then
        echo -e "${CYAN}Deadline:${NC} $deadline ($(days_remaining "$deadline"))"
    fi
    echo ""
    echo "Add milestones with: goals.sh milestone $next_id \"milestone description\""
}

list_goals() {
    local goals=$(jq -r '.goals | map(select(.status == "active")) | length' "$GOALS_FILE")

    if [[ "$goals" -eq 0 ]]; then
        echo "No active goals."
        echo "Add one with: goals.sh add \"Your goal\" [deadline]"
        exit 0
    fi

    echo -e "${BLUE}=== Active Goals ===${NC}"
    echo ""

    jq -r '.goals | map(select(.status == "active")) | .[] | "\(.id)|\(.title)|\(.progress)|\(.deadline)|\(.milestones | map(select(.done == true)) | length)|\(.milestones | length)"' "$GOALS_FILE" | \
    while IFS='|' read -r id title progress deadline done_milestones total_milestones; do
        echo -e "${WHITE}#$id${NC} $title"

        # Progress bar
        printf "    "
        progress_bar "$progress"
        echo ""

        # Deadline info
        if [[ -n "$deadline" ]] && [[ "$deadline" != "null" ]]; then
            echo -e "    ${CYAN}Deadline:${NC} $deadline ($(days_remaining "$deadline"))"
        fi

        # Milestones summary
        if [[ "$total_milestones" -gt 0 ]]; then
            echo -e "    ${CYAN}Milestones:${NC} $done_milestones/$total_milestones completed"
        fi

        echo ""
    done
}

show_goal() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: goals.sh show <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id)) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Goal #$id not found${NC}"
        exit 1
    fi

    local goal=$(jq --argjson id "$id" '.goals[] | select(.id == $id)' "$GOALS_FILE")

    local title=$(echo "$goal" | jq -r '.title')
    local progress=$(echo "$goal" | jq -r '.progress')
    local deadline=$(echo "$goal" | jq -r '.deadline')
    local created=$(echo "$goal" | jq -r '.created')
    local status=$(echo "$goal" | jq -r '.status')

    echo -e "${BLUE}=== Goal #$id ===${NC}"
    echo ""
    echo -e "${WHITE}$title${NC}"
    echo ""

    # Progress bar
    printf "Progress: "
    progress_bar "$progress"
    echo ""
    echo ""

    echo -e "${CYAN}Status:${NC} $status"
    echo -e "${CYAN}Created:${NC} $created"

    if [[ -n "$deadline" ]] && [[ "$deadline" != "null" ]]; then
        echo -e "${CYAN}Deadline:${NC} $deadline ($(days_remaining "$deadline"))"
    fi

    # Show milestones
    local milestones=$(echo "$goal" | jq -r '.milestones | length')
    if [[ "$milestones" -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Milestones:${NC}"
        echo "$goal" | jq -r '.milestones[] | "\(.id)|\(.description)|\(.done)|\(.completed_at)"' | \
        while IFS='|' read -r mid desc done completed_at; do
            if [[ "$done" == "true" ]]; then
                echo -e "  ${GREEN}[✓]${NC} ${GRAY}#$mid${NC} $desc ${GRAY}($completed_at)${NC}"
            else
                echo -e "  ${GRAY}[ ]${NC} ${GRAY}#$mid${NC} $desc"
            fi
        done
    fi

    # Show notes
    local notes=$(echo "$goal" | jq -r '.notes | length')
    if [[ "$notes" -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Notes:${NC}"
        echo "$goal" | jq -r '.notes[] | "  [\(.date)] \(.text)"'
    fi
}

update_progress() {
    local id=$1
    local percent=$2

    if [[ -z "$id" ]] || [[ -z "$percent" ]]; then
        echo "Usage: goals.sh progress <id> <percent>"
        exit 1
    fi

    # Validate percent
    if ! [[ "$percent" =~ ^[0-9]+$ ]] || [[ "$percent" -lt 0 ]] || [[ "$percent" -gt 100 ]]; then
        echo -e "${RED}Progress must be 0-100${NC}"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id and .status == "active")) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Active goal #$id not found${NC}"
        exit 1
    fi

    jq --argjson id "$id" --argjson progress "$percent" '
        .goals = [.goals[] | if .id == $id then .progress = $progress else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    local title=$(jq -r --argjson id "$id" '.goals[] | select(.id == $id) | .title' "$GOALS_FILE")

    echo -e "${GREEN}Updated progress:${NC} $title"
    printf "  "
    progress_bar "$percent"
    echo ""

    if [[ "$percent" -eq 100 ]]; then
        echo ""
        echo -e "${YELLOW}Goal at 100%! Mark complete with: goals.sh complete $id${NC}"
    fi
}

add_milestone() {
    local id=$1
    shift
    local description="$*"

    if [[ -z "$id" ]] || [[ -z "$description" ]]; then
        echo "Usage: goals.sh milestone <goal_id> \"milestone description\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id and .status == "active")) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Active goal #$id not found${NC}"
        exit 1
    fi

    # Get next milestone ID for this goal
    local next_mid=$(jq -r --argjson id "$id" '.goals[] | select(.id == $id) | .milestones | length + 1' "$GOALS_FILE")

    jq --argjson id "$id" --argjson mid "$next_mid" --arg desc "$description" '
        .goals = [.goals[] | if .id == $id then
            .milestones += [{
                "id": $mid,
                "description": $desc,
                "done": false,
                "completed_at": null
            }]
        else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    echo -e "${GREEN}Milestone #$next_mid added to goal #$id:${NC} $description"
}

check_milestone() {
    local goal_id=$1
    local milestone_id=$2

    if [[ -z "$goal_id" ]] || [[ -z "$milestone_id" ]]; then
        echo "Usage: goals.sh check <goal_id> <milestone_id>"
        exit 1
    fi

    local exists=$(jq --argjson gid "$goal_id" --argjson mid "$milestone_id" '
        .goals | map(select(.id == $gid)) | .[0].milestones | map(select(.id == $mid)) | length
    ' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Milestone not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    jq --argjson gid "$goal_id" --argjson mid "$milestone_id" --arg ts "$timestamp" '
        .goals = [.goals[] | if .id == $gid then
            .milestones = [.milestones[] | if .id == $mid then
                .done = true | .completed_at = $ts
            else . end]
        else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    local desc=$(jq -r --argjson gid "$goal_id" --argjson mid "$milestone_id" '
        .goals[] | select(.id == $gid) | .milestones[] | select(.id == $mid) | .description
    ' "$GOALS_FILE")

    echo -e "${GREEN}✓ Milestone completed:${NC} $desc"

    # Calculate and show suggested progress
    local total=$(jq -r --argjson gid "$goal_id" '.goals[] | select(.id == $gid) | .milestones | length' "$GOALS_FILE")
    local done=$(jq -r --argjson gid "$goal_id" '.goals[] | select(.id == $gid) | .milestones | map(select(.done == true)) | length' "$GOALS_FILE")
    local suggested=$((done * 100 / total))

    echo -e "${CYAN}Milestones:${NC} $done/$total completed"
    echo -e "${YELLOW}Suggested progress:${NC} $suggested%"
    echo "Update with: goals.sh progress $goal_id $suggested"
}

add_note() {
    local id=$1
    shift
    local note="$*"

    if [[ -z "$id" ]] || [[ -z "$note" ]]; then
        echo "Usage: goals.sh note <goal_id> \"note text\""
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id)) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Goal #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d')

    jq --argjson id "$id" --arg note "$note" --arg date "$timestamp" '
        .goals = [.goals[] | if .id == $id then
            .notes += [{"date": $date, "text": $note}]
        else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    echo -e "${GREEN}Note added to goal #$id${NC}"
}

complete_goal() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: goals.sh complete <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id and .status == "active")) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Active goal #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    jq --argjson id "$id" --arg ts "$timestamp" '
        .goals = [.goals[] | if .id == $id then
            .status = "completed" | .completed_at = $ts | .progress = 100
        else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    local title=$(jq -r --argjson id "$id" '.goals[] | select(.id == $id) | .title' "$GOALS_FILE")

    echo -e "${GREEN}🎉 Goal achieved:${NC} $title"
    echo -e "${CYAN}Completed at:${NC} $timestamp"
}

abandon_goal() {
    local id=$1

    if [[ -z "$id" ]]; then
        echo "Usage: goals.sh abandon <id>"
        exit 1
    fi

    local exists=$(jq --argjson id "$id" '.goals | map(select(.id == $id and .status == "active")) | length' "$GOALS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Active goal #$id not found${NC}"
        exit 1
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M')

    jq --argjson id "$id" --arg ts "$timestamp" '
        .goals = [.goals[] | if .id == $id then
            .status = "abandoned" | .abandoned_at = $ts
        else . end]
    ' "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"

    local title=$(jq -r --argjson id "$id" '.goals[] | select(.id == $id) | .title' "$GOALS_FILE")

    echo -e "${YELLOW}Goal archived:${NC} $title"
}

show_archive() {
    local completed=$(jq -r '.goals | map(select(.status == "completed")) | length' "$GOALS_FILE")
    local abandoned=$(jq -r '.goals | map(select(.status == "abandoned")) | length' "$GOALS_FILE")

    if [[ "$completed" -eq 0 ]] && [[ "$abandoned" -eq 0 ]]; then
        echo "No archived goals."
        exit 0
    fi

    echo -e "${BLUE}=== Archived Goals ===${NC}"
    echo ""

    if [[ "$completed" -gt 0 ]]; then
        echo -e "${GREEN}Completed ($completed):${NC}"
        jq -r '.goals | map(select(.status == "completed")) | .[] | "  #\(.id) \(.title) - completed \(.completed_at)"' "$GOALS_FILE"
        echo ""
    fi

    if [[ "$abandoned" -gt 0 ]]; then
        echo -e "${GRAY}Abandoned ($abandoned):${NC}"
        jq -r '.goals | map(select(.status == "abandoned")) | .[] | "  #\(.id) \(.title) - abandoned \(.abandoned_at)"' "$GOALS_FILE"
    fi
}

show_stats() {
    echo -e "${BLUE}=== Goal Statistics ===${NC}"
    echo ""

    local active=$(jq -r '.goals | map(select(.status == "active")) | length' "$GOALS_FILE")
    local completed=$(jq -r '.goals | map(select(.status == "completed")) | length' "$GOALS_FILE")
    local abandoned=$(jq -r '.goals | map(select(.status == "abandoned")) | length' "$GOALS_FILE")
    local total=$((active + completed + abandoned))

    echo -e "${CYAN}Total goals created:${NC} $total"
    echo -e "${GREEN}Completed:${NC} $completed"
    echo -e "${YELLOW}Active:${NC} $active"
    echo -e "${GRAY}Abandoned:${NC} $abandoned"

    if [[ $total -gt 0 ]]; then
        local completion_rate=$((completed * 100 / total))
        echo ""
        echo -e "${CYAN}Completion rate:${NC} $completion_rate%"
    fi

    # Average progress of active goals
    if [[ "$active" -gt 0 ]]; then
        local avg_progress=$(jq -r '.goals | map(select(.status == "active")) | map(.progress) | add / length | floor' "$GOALS_FILE")
        echo -e "${CYAN}Average progress (active):${NC} $avg_progress%"

        # Goals due soon
        local due_soon=$(jq -r --arg today "$TODAY" --arg week "$(date -d '+7 days' +%Y-%m-%d)" '
            .goals | map(select(.status == "active" and .deadline != null and .deadline <= $week and .deadline >= $today)) | length
        ' "$GOALS_FILE")

        if [[ "$due_soon" -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}Goals due within 7 days:${NC} $due_soon"
        fi

        # Overdue goals
        local overdue=$(jq -r --arg today "$TODAY" '
            .goals | map(select(.status == "active" and .deadline != null and .deadline < $today)) | length
        ' "$GOALS_FILE")

        if [[ "$overdue" -gt 0 ]]; then
            echo -e "${RED}Overdue goals:${NC} $overdue"
        fi
    fi
}

show_help() {
    echo "Goals - Long-term goal setting and progress tracking"
    echo ""
    echo "Usage:"
    echo "  goals.sh add \"title\" [deadline]     Add a new goal (YYYY-MM-DD)"
    echo "  goals.sh list                       List all active goals"
    echo "  goals.sh show <id>                  Show goal details"
    echo "  goals.sh progress <id> <percent>    Update progress (0-100)"
    echo "  goals.sh milestone <id> \"desc\"      Add a milestone"
    echo "  goals.sh check <id> <milestone_id>  Mark milestone complete"
    echo "  goals.sh note <id> \"text\"           Add a note"
    echo "  goals.sh complete <id>              Mark goal as achieved"
    echo "  goals.sh abandon <id>               Archive abandoned goal"
    echo "  goals.sh archive                    Show archived goals"
    echo "  goals.sh stats                      Show statistics"
    echo "  goals.sh help                       Show this help"
    echo ""
    echo "Examples:"
    echo "  goals.sh add \"Learn Spanish\" 2026-06-30"
    echo "  goals.sh milestone 1 \"Complete beginner course\""
    echo "  goals.sh milestone 1 \"Have 10 minute conversation\""
    echo "  goals.sh check 1 1"
    echo "  goals.sh progress 1 25"
}

case "$1" in
    add|new)
        add_goal "$2" "$3"
        ;;
    list|ls)
        list_goals
        ;;
    show|view)
        show_goal "$2"
        ;;
    progress|prog|update)
        update_progress "$2" "$3"
        ;;
    milestone|ms)
        shift
        add_milestone "$@"
        ;;
    check|done|mark)
        check_milestone "$2" "$3"
        ;;
    note)
        shift
        add_note "$@"
        ;;
    complete|achieve)
        complete_goal "$2"
        ;;
    abandon|drop)
        abandon_goal "$2"
        ;;
    archive|archived)
        show_archive
        ;;
    stats|statistics)
        show_stats
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_goals
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'goals.sh help' for usage"
        exit 1
        ;;
esac
