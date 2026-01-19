#!/bin/bash
#
# Habits - Enhanced daily habit tracker
#
# Usage:
#   habits.sh add "habit name" [--weekly N]   - Add a new habit (optional weekly target)
#   habits.sh check "habit" [date] [--note "text"] - Mark habit done with optional note
#   habits.sh uncheck "habit" [date]          - Unmark habit for a date
#   habits.sh list                            - Show all habits with today's status
#   habits.sh status [days]                   - Show habit grid (default: 7 days)
#   habits.sh streak "habit"                  - Show current streak for a habit
#   habits.sh stats [habit]                   - Show statistics (all or specific habit)
#   habits.sh notes "habit" [N]               - Show last N notes for a habit
#   habits.sh remove "habit"                  - Remove a habit
#   habits.sh rename "old" "new"              - Rename a habit
#   habits.sh edit "habit"                    - Edit habit settings
#   habits.sh export [file]                   - Export data to JSON
#   habits.sh import <file>                   - Import data from JSON
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
HABITS_FILE="$DATA_DIR/habits.json"
TODAY=$(date +%Y-%m-%d)

mkdir -p "$DATA_DIR"

# Initialize habits file if it doesn't exist (v2 format)
if [[ ! -f "$HABITS_FILE" ]]; then
    echo '{"version":"2.0","habits":[],"completions":{},"notes":{},"settings":{}}' > "$HABITS_FILE"
fi

# Migrate from v1 format if needed
migrate_if_needed() {
    local version=$(jq -r '.version // "1.0"' "$HABITS_FILE")
    if [[ "$version" == "1.0" ]] || [[ "$version" == "null" ]]; then
        # Migrate to v2 format
        jq '. + {"version":"2.0","notes":{},"settings":{}}' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"
    fi
}

migrate_if_needed

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

add_habit() {
    local name=""
    local weekly_target=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --weekly|-w)
                weekly_target="$2"
                shift 2
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                else
                    name="$name $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh add \"habit name\" [--weekly N]"
        echo ""
        echo "Options:"
        echo "  --weekly, -w N   Set weekly target (e.g., 3 times per week)"
        echo ""
        echo "Examples:"
        echo "  habits.sh add \"exercise\"              # Daily habit"
        echo "  habits.sh add \"deep work\" --weekly 5  # 5 times per week"
        exit 1
    fi

    # Validate weekly target
    if [[ -n "$weekly_target" ]] && ! [[ "$weekly_target" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Weekly target must be a positive number${NC}"
        exit 1
    fi

    # Check if habit already exists
    local exists=$(jq -r --arg name "$name" '.habits | map(select(.name == $name or . == $name)) | length' "$HABITS_FILE")

    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Habit '$name' already exists.${NC}"
        exit 1
    fi

    # Add as object with settings
    local created=$(date '+%Y-%m-%d')
    jq --arg name "$name" --argjson weekly "$weekly_target" --arg created "$created" '
        .habits += [{
            "name": $name,
            "weekly_target": (if $weekly > 0 then $weekly else null end),
            "created": $created,
            "active": true
        }]
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}Added habit:${NC} $name"
    if [[ "$weekly_target" -gt 0 ]]; then
        echo -e "${CYAN}Weekly target:${NC} $weekly_target times per week"
    fi
}

check_habit() {
    local name=""
    local date="$TODAY"
    local note=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --note|-n)
                note="$2"
                shift 2
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                elif [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    date="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh check \"habit\" [date] [--note \"text\"]"
        echo ""
        echo "Options:"
        echo "  --note, -n \"text\"   Add a note for this check-in"
        echo ""
        echo "Examples:"
        echo "  habits.sh check \"exercise\""
        echo "  habits.sh check \"exercise\" --note \"30 min run\""
        echo "  habits.sh check \"exercise\" 2026-01-15 --note \"Gym workout\""
        exit 1
    fi

    # Validate date format
    if ! date -d "$date" &>/dev/null 2>&1; then
        echo -e "${RED}Invalid date format: $date${NC}"
        exit 1
    fi

    # Check if habit exists (support both old string format and new object format)
    local exists=$(jq -r --arg name "$name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        echo "Add it first with: habits.sh add \"$name\""
        exit 1
    fi

    # Add completion
    jq --arg name "$name" --arg date "$date" '
        if .completions[$name] == null then
            .completions[$name] = []
        end |
        if (.completions[$name] | index($date)) == null then
            .completions[$name] += [$date]
        end |
        .completions[$name] |= sort
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    # Add note if provided
    if [[ -n "$note" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        jq --arg name "$name" --arg date "$date" --arg note "$note" --arg ts "$timestamp" '
            if .notes[$name] == null then
                .notes[$name] = []
            end |
            .notes[$name] += [{
                "date": $date,
                "note": $note,
                "timestamp": $ts
            }]
        ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"
    fi

    echo -e "${GREEN}✓${NC} Marked '$name' done for $date"
    if [[ -n "$note" ]]; then
        echo -e "${CYAN}Note:${NC} $note"
    fi
}

uncheck_habit() {
    local name="$1"
    local date="${2:-$TODAY}"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh uncheck \"habit\" [date]"
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    # Remove completion
    jq --arg name "$name" --arg date "$date" '
        if .completions[$name] != null then
            .completions[$name] -= [$date]
        end
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${YELLOW}✗${NC} Unmarked '$name' for $date"
}

get_habit_name() {
    local habit="$1"
    # Handle both string and object formats
    if echo "$habit" | jq -e 'type == "object"' &>/dev/null; then
        echo "$habit" | jq -r '.name'
    else
        echo "$habit"
    fi
}

get_habit_names() {
    jq -r '.habits[] | if type == "object" then .name else . end' "$HABITS_FILE" 2>/dev/null
}

list_habits() {
    local habits=$(get_habit_names)

    if [[ -z "$habits" ]]; then
        echo "No habits tracked yet."
        echo "Add one with: habits.sh add \"exercise\""
        exit 0
    fi

    echo -e "${BLUE}=== Today's Habits ($TODAY) ===${NC}"
    echo ""

    local done_count=0
    local total_count=0

    while IFS= read -r habit; do
        total_count=$((total_count + 1))
        local completed=$(jq -r --arg name "$habit" --arg date "$TODAY" '
            if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                "yes"
            else
                "no"
            end
        ' "$HABITS_FILE")

        local streak=$(calculate_streak "$habit")

        # Get weekly target if set
        local weekly_target=$(jq -r --arg name "$habit" '
            .habits[] | select(
                (type == "object" and .name == $name)
            ) | .weekly_target // 0
        ' "$HABITS_FILE" 2>/dev/null)

        local weekly_info=""
        if [[ -n "$weekly_target" ]] && [[ "$weekly_target" != "null" ]] && [[ "$weekly_target" -gt 0 ]]; then
            local week_count=$(get_week_completions "$habit")
            weekly_info=" ${CYAN}[$week_count/$weekly_target this week]${NC}"
        fi

        if [[ "$completed" == "yes" ]]; then
            echo -e "  ${GREEN}[✓]${NC} $habit ${GRAY}(${streak} day streak)${NC}$weekly_info"
            done_count=$((done_count + 1))
        else
            echo -e "  ${GRAY}[ ]${NC} $habit ${GRAY}(${streak} day streak)${NC}$weekly_info"
        fi
    done <<< "$habits"

    echo ""
    echo -e "${CYAN}Progress:${NC} $done_count/$total_count completed"
}

get_week_completions() {
    local name="$1"
    # Get Monday of current week
    local day_of_week=$(date +%u)
    local days_since_monday=$((day_of_week - 1))
    local monday=$(date -d "$TODAY - $days_since_monday days" +%Y-%m-%d 2>/dev/null || date -v-${days_since_monday}d +%Y-%m-%d 2>/dev/null)

    local count=0
    for ((i = 0; i < 7; i++)); do
        local check_date=$(date -d "$monday + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -jf "%Y-%m-%d" "$monday" +%Y-%m-%d 2>/dev/null)
        if [[ "$check_date" > "$TODAY" ]]; then
            break
        fi
        local completed=$(jq -r --arg name "$name" --arg date "$check_date" '
            if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                "yes"
            else
                "no"
            end
        ' "$HABITS_FILE")
        if [[ "$completed" == "yes" ]]; then
            count=$((count + 1))
        fi
    done
    echo $count
}

calculate_streak() {
    local name="$1"
    local streak=0
    local check_date="$TODAY"

    while true; do
        local completed=$(jq -r --arg name "$name" --arg date "$check_date" '
            if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                "yes"
            else
                "no"
            end
        ' "$HABITS_FILE")

        if [[ "$completed" == "yes" ]]; then
            streak=$((streak + 1))
            check_date=$(date -d "$check_date - 1 day" +%Y-%m-%d 2>/dev/null || date -v-1d -jf "%Y-%m-%d" "$check_date" +%Y-%m-%d 2>/dev/null)
        else
            break
        fi
    done

    echo $streak
}

show_streak() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh streak \"habit\""
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    local streak=$(calculate_streak "$name")
    local total=$(jq -r --arg name "$name" '.completions[$name] // [] | length' "$HABITS_FILE")

    echo -e "${BLUE}=== Streak: $name ===${NC}"
    echo ""
    echo -e "${GREEN}Current streak:${NC} $streak days"
    echo -e "${CYAN}Total completions:${NC} $total"

    # Show longest streak
    local completions=$(jq -r --arg name "$name" '.completions[$name] // [] | .[]' "$HABITS_FILE" | sort)

    if [[ -n "$completions" ]]; then
        local longest=0
        local current=0
        local prev_date=""

        while IFS= read -r date; do
            if [[ -z "$prev_date" ]]; then
                current=1
            else
                local expected=$(date -d "$prev_date + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -jf "%Y-%m-%d" "$prev_date" +%Y-%m-%d 2>/dev/null)
                if [[ "$date" == "$expected" ]]; then
                    current=$((current + 1))
                else
                    current=1
                fi
            fi

            if [[ $current -gt $longest ]]; then
                longest=$current
            fi

            prev_date="$date"
        done <<< "$completions"

        echo -e "${MAGENTA}Longest streak:${NC} $longest days"
    fi
}

show_status() {
    local days=${1:-7}

    local habits=$(get_habit_names)

    if [[ -z "$habits" ]]; then
        echo "No habits tracked yet."
        echo "Add one with: habits.sh add \"exercise\""
        exit 0
    fi

    echo -e "${BLUE}=== Habit Tracker (Last $days days) ===${NC}"
    echo ""

    # Print header with dates
    printf "%-20s" ""
    for ((i = days - 1; i >= 0; i--)); do
        local date=$(date -d "$TODAY - $i days" +%d 2>/dev/null || date -v-${i}d +%d 2>/dev/null)
        printf "%3s" "$date"
    done
    echo ""

    # Print day names
    printf "%-20s" ""
    for ((i = days - 1; i >= 0; i--)); do
        local day=$(date -d "$TODAY - $i days" +%a 2>/dev/null || date -v-${i}d +%a 2>/dev/null)
        printf "%3s" "${day:0:2}"
    done
    echo ""
    echo ""

    # Print each habit
    while IFS= read -r habit; do
        local display_name="$habit"
        if [[ ${#display_name} -gt 18 ]]; then
            display_name="${display_name:0:17}…"
        fi
        printf "%-20s" "$display_name"

        for ((i = days - 1; i >= 0; i--)); do
            local check_date=$(date -d "$TODAY - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
            local completed=$(jq -r --arg name "$habit" --arg date "$check_date" '
                if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                    "yes"
                else
                    "no"
                end
            ' "$HABITS_FILE")

            if [[ "$completed" == "yes" ]]; then
                printf " ${GREEN}●${NC} "
            else
                printf " ${GRAY}○${NC} "
            fi
        done

        # Show streak
        local streak=$(calculate_streak "$habit")
        if [[ $streak -gt 0 ]]; then
            printf " ${YELLOW}%d${NC}" $streak
        fi

        echo ""
    done <<< "$habits"

    echo ""
    echo -e "${GRAY}● = done, ○ = missed, number = current streak${NC}"
}

show_stats() {
    local habit_filter="$1"

    echo -e "${BLUE}=== Habit Statistics ===${NC}"
    echo ""

    local habits=$(get_habit_names)

    if [[ -z "$habits" ]]; then
        echo "No habits tracked yet."
        exit 0
    fi

    # If specific habit requested
    if [[ -n "$habit_filter" ]]; then
        local exists=$(jq -r --arg name "$habit_filter" '
            .habits | map(select(
                (type == "string" and . == $name) or
                (type == "object" and .name == $name)
            )) | length
        ' "$HABITS_FILE")

        if [[ "$exists" -eq 0 ]]; then
            echo -e "${RED}Habit '$habit_filter' not found.${NC}"
            exit 1
        fi
        habits="$habit_filter"
    fi

    while IFS= read -r habit; do
        echo -e "${BOLD}$habit${NC}"
        echo ""

        local total=$(jq -r --arg name "$habit" '.completions[$name] // [] | length' "$HABITS_FILE")
        local streak=$(calculate_streak "$habit")

        # Calculate longest streak
        local completions=$(jq -r --arg name "$habit" '.completions[$name] // [] | .[]' "$HABITS_FILE" | sort)
        local longest=0
        local current=0
        local prev_date=""

        if [[ -n "$completions" ]]; then
            while IFS= read -r date; do
                if [[ -z "$prev_date" ]]; then
                    current=1
                else
                    local expected=$(date -d "$prev_date + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -jf "%Y-%m-%d" "$prev_date" +%Y-%m-%d 2>/dev/null)
                    if [[ "$date" == "$expected" ]]; then
                        current=$((current + 1))
                    else
                        current=1
                    fi
                fi
                if [[ $current -gt $longest ]]; then
                    longest=$current
                fi
                prev_date="$date"
            done <<< "$completions"
        fi

        echo -e "  ${GREEN}Total completions:${NC}  $total"
        echo -e "  ${CYAN}Current streak:${NC}     $streak days"
        echo -e "  ${MAGENTA}Longest streak:${NC}     $longest days"

        # Calculate completion rate for last 30 days
        local completed_30=0
        for ((i = 0; i < 30; i++)); do
            local check_date=$(date -d "$TODAY - $i days" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null)
            local is_completed=$(jq -r --arg name "$habit" --arg date "$check_date" '
                if .completions[$name] != null and (.completions[$name] | index($date)) != null then
                    "yes"
                else
                    "no"
                end
            ' "$HABITS_FILE")
            if [[ "$is_completed" == "yes" ]]; then
                completed_30=$((completed_30 + 1))
            fi
        done
        local rate_30=$(echo "scale=0; $completed_30 * 100 / 30" | bc)
        echo -e "  ${YELLOW}Last 30 days:${NC}       $completed_30/30 (${rate_30}%)"

        # Calculate best day of week
        local best_day=""
        local best_count=0
        for day_num in 1 2 3 4 5 6 7; do
            local day_name=""
            case $day_num in
                1) day_name="Mon" ;;
                2) day_name="Tue" ;;
                3) day_name="Wed" ;;
                4) day_name="Thu" ;;
                5) day_name="Fri" ;;
                6) day_name="Sat" ;;
                7) day_name="Sun" ;;
            esac

            local count=$(jq -r --arg name "$habit" '.completions[$name] // []' "$HABITS_FILE" | \
                jq -r '.[]' | while read -r d; do
                    date -d "$d" +%u 2>/dev/null || date -jf "%Y-%m-%d" "$d" +%u 2>/dev/null
                done | grep -c "^$day_num$" 2>/dev/null || echo 0)

            if [[ "$count" -gt "$best_count" ]]; then
                best_count=$count
                best_day=$day_name
            fi
        done

        if [[ -n "$best_day" ]] && [[ "$best_count" -gt 0 ]]; then
            echo -e "  ${BLUE}Best day:${NC}           $best_day ($best_count completions)"
        fi

        # Show weekly target progress if set
        local weekly_target=$(jq -r --arg name "$habit" '
            .habits[] | select(
                (type == "object" and .name == $name)
            ) | .weekly_target // 0
        ' "$HABITS_FILE" 2>/dev/null)

        if [[ -n "$weekly_target" ]] && [[ "$weekly_target" != "null" ]] && [[ "$weekly_target" -gt 0 ]]; then
            local week_count=$(get_week_completions "$habit")
            echo -e "  ${CYAN}This week:${NC}          $week_count/$weekly_target"
        fi

        # Count notes
        local note_count=$(jq -r --arg name "$habit" '.notes[$name] // [] | length' "$HABITS_FILE")
        if [[ "$note_count" -gt 0 ]]; then
            echo -e "  ${GRAY}Notes:${NC}              $note_count"
        fi

        echo ""
    done <<< "$habits"
}

show_notes() {
    local name="$1"
    local limit="${2:-10}"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh notes \"habit\" [limit]"
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Notes: $name ===${NC}"
    echo ""

    local notes=$(jq -r --arg name "$name" --argjson limit "$limit" '
        .notes[$name] // [] | sort_by(.timestamp) | reverse | .[:$limit] | .[] |
        "\(.date)|\(.note)"
    ' "$HABITS_FILE")

    if [[ -z "$notes" ]]; then
        echo "No notes recorded for this habit."
        echo ""
        echo "Add notes when checking in:"
        echo "  habits.sh check \"$name\" --note \"Your note here\""
        exit 0
    fi

    echo "$notes" | while IFS='|' read -r date note; do
        echo -e "  ${YELLOW}$date${NC} - $note"
    done
}

remove_habit() {
    local name="$*"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh remove \"habit\""
        exit 1
    fi

    # Check if habit exists
    local exists=$(jq -r --arg name "$name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    jq --arg name "$name" '
        .habits = [.habits[] | select(
            (type == "string" and . != $name) and
            (type != "object" or .name != $name)
        )] |
        del(.completions[$name]) |
        del(.notes[$name])
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${RED}Removed habit:${NC} $name"
}

rename_habit() {
    local old_name="$1"
    local new_name="$2"

    if [[ -z "$old_name" ]] || [[ -z "$new_name" ]]; then
        echo "Usage: habits.sh rename \"old name\" \"new name\""
        exit 1
    fi

    # Check if old habit exists
    local exists=$(jq -r --arg name "$old_name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Habit '$old_name' not found.${NC}"
        exit 1
    fi

    # Check if new name already exists
    local new_exists=$(jq -r --arg name "$new_name" '
        .habits | map(select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )) | length
    ' "$HABITS_FILE")

    if [[ "$new_exists" -gt 0 ]]; then
        echo -e "${YELLOW}Habit '$new_name' already exists.${NC}"
        exit 1
    fi

    jq --arg old "$old_name" --arg new "$new_name" '
        .habits = [.habits[] |
            if type == "string" and . == $old then $new
            elif type == "object" and .name == $old then .name = $new
            else . end
        ] |
        if .completions[$old] != null then
            .completions[$new] = .completions[$old] |
            del(.completions[$old])
        end |
        if .notes[$old] != null then
            .notes[$new] = .notes[$old] |
            del(.notes[$old])
        end
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}Renamed:${NC} '$old_name' → '$new_name'"
}

edit_habit() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: habits.sh edit \"habit\""
        exit 1
    fi

    # Check if habit exists
    local habit=$(jq -r --arg name "$name" '
        .habits[] | select(
            (type == "string" and . == $name) or
            (type == "object" and .name == $name)
        )
    ' "$HABITS_FILE")

    if [[ -z "$habit" ]]; then
        echo -e "${RED}Habit '$name' not found.${NC}"
        exit 1
    fi

    local current_weekly=$(jq -r --arg name "$name" '
        .habits[] | select(
            (type == "object" and .name == $name)
        ) | .weekly_target // 0
    ' "$HABITS_FILE" 2>/dev/null)

    echo -e "${BLUE}=== Edit Habit: $name ===${NC}"
    echo ""
    echo "Press Enter to keep current value."
    echo ""

    read -p "Weekly target [$current_weekly]: " new_weekly
    new_weekly="${new_weekly:-$current_weekly}"

    # Validate
    if ! [[ "$new_weekly" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Weekly target must be a number${NC}"
        exit 1
    fi

    # Update habit - convert to object format if needed
    jq --arg name "$name" --argjson weekly "$new_weekly" '
        .habits = [.habits[] |
            if (type == "string" and . == $name) then
                {"name": $name, "weekly_target": (if $weekly > 0 then $weekly else null end), "active": true}
            elif (type == "object" and .name == $name) then
                .weekly_target = (if $weekly > 0 then $weekly else null end)
            else . end
        ]
    ' "$HABITS_FILE" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo ""
    echo -e "${GREEN}Habit updated.${NC}"
}

export_habits() {
    local output_file="${1:-habits_export.json}"

    local habit_count=$(jq '.habits | length' "$HABITS_FILE")

    if [[ "$habit_count" -eq 0 ]]; then
        echo "No habits to export."
        exit 0
    fi

    cp "$HABITS_FILE" "$output_file"

    local completion_count=$(jq '[.completions | to_entries[] | .value | length] | add // 0' "$HABITS_FILE")
    local note_count=$(jq '[.notes | to_entries[] | .value | length] | add // 0' "$HABITS_FILE")

    echo -e "${GREEN}Exported to:${NC} $output_file"
    echo ""
    echo -e "  ${CYAN}Habits:${NC}      $habit_count"
    echo -e "  ${CYAN}Completions:${NC} $completion_count"
    echo -e "  ${CYAN}Notes:${NC}       $note_count"
}

import_habits() {
    local input_file="$1"

    if [[ -z "$input_file" ]]; then
        echo "Usage: habits.sh import <file>"
        exit 1
    fi

    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}File not found:${NC} $input_file"
        exit 1
    fi

    # Validate JSON
    if ! jq empty "$input_file" 2>/dev/null; then
        echo -e "${RED}Invalid JSON file${NC}"
        exit 1
    fi

    local habit_count=$(jq '.habits | length' "$input_file")
    echo "Found $habit_count habits to import."

    read -p "This will MERGE with existing data. Continue? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    # Merge habits
    jq -s '
        .[0] as $existing | .[1] as $import |
        {
            version: "2.0",
            habits: (($existing.habits + $import.habits) | unique),
            completions: ($existing.completions * $import.completions |
                to_entries | map({key: .key, value: (.value | unique | sort)}) | from_entries),
            notes: ($existing.notes * $import.notes |
                to_entries | map({key: .key, value: (.value | unique_by(.timestamp))}) | from_entries),
            settings: ($existing.settings * ($import.settings // {}))
        }
    ' "$HABITS_FILE" "$input_file" > "$HABITS_FILE.tmp" && mv "$HABITS_FILE.tmp" "$HABITS_FILE"

    echo -e "${GREEN}Import complete.${NC}"
}

show_help() {
    echo "Habits - Enhanced daily habit tracker"
    echo ""
    echo "Usage:"
    echo "  habits.sh add \"habit\" [--weekly N]     Add a habit (optional weekly target)"
    echo "  habits.sh check \"habit\" [date] [-n \"note\"]  Mark done with optional note"
    echo "  habits.sh uncheck \"habit\" [date]       Unmark habit for a date"
    echo "  habits.sh list                          Show today's habits"
    echo "  habits.sh status [days]                 Show habit grid (default: 7)"
    echo "  habits.sh streak \"habit\"                Show streak for a habit"
    echo "  habits.sh stats [habit]                 Show statistics"
    echo "  habits.sh notes \"habit\" [N]             Show last N notes"
    echo "  habits.sh remove \"habit\"                Remove a habit"
    echo "  habits.sh rename \"old\" \"new\"            Rename a habit"
    echo "  habits.sh edit \"habit\"                  Edit habit settings"
    echo "  habits.sh export [file]                 Export to JSON"
    echo "  habits.sh import <file>                 Import from JSON"
    echo "  habits.sh help                          Show this help"
    echo ""
    echo "Examples:"
    echo "  habits.sh add \"exercise\""
    echo "  habits.sh add \"deep work\" --weekly 5"
    echo "  habits.sh check \"exercise\" --note \"30 min run\""
    echo "  habits.sh stats exercise"
}

case "$1" in
    add)
        shift
        add_habit "$@"
        ;;
    check|done|mark)
        shift
        check_habit "$@"
        ;;
    uncheck|undo|unmark)
        shift
        uncheck_habit "$@"
        ;;
    list|ls)
        list_habits
        ;;
    status|grid|show)
        show_status "$2"
        ;;
    streak)
        shift
        show_streak "$@"
        ;;
    stats|statistics)
        show_stats "$2"
        ;;
    notes|note)
        show_notes "$2" "$3"
        ;;
    remove|rm|delete)
        shift
        remove_habit "$@"
        ;;
    rename|mv)
        rename_habit "$2" "$3"
        ;;
    edit)
        shift
        edit_habit "$@"
        ;;
    export)
        export_habits "$2"
        ;;
    import)
        import_habits "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_habits
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'habits.sh help' for usage"
        exit 1
        ;;
esac
