#!/bin/bash
#
# Weekly Planner - Weekly planning and review tool
#
# Usage:
#   weekly-planner.sh plan           - Create/view this week's plan
#   weekly-planner.sh review         - Weekly review with prompts
#   weekly-planner.sh goals          - Set weekly goals
#   weekly-planner.sh priorities     - List and manage priorities
#   weekly-planner.sh wins           - Record a win or achievement
#   weekly-planner.sh challenges     - Note a challenge or blocker
#   weekly-planner.sh next           - Plan for next week
#   weekly-planner.sh history [n]    - View past weeks' plans
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/data"
TODAY=$(date +%Y-%m-%d)
# Calculate week start (Monday)
WEEK_START=$(date -d "$TODAY - $(( ($(date +%u) - 1) )) days" +%Y-%m-%d 2>/dev/null || date -v-$(( $(date +%u) - 1 ))d +%Y-%m-%d 2>/dev/null)
WEEK_FILE="$DATA_DIR/week_${WEEK_START}.json"

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

# Initialize week file if it doesn't exist
init_week() {
    if [[ ! -f "$WEEK_FILE" ]]; then
        local week_end=$(date -d "$WEEK_START + 6 days" +%Y-%m-%d 2>/dev/null || date -v+6d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
        cat > "$WEEK_FILE" << EOF
{
    "week_start": "$WEEK_START",
    "week_end": "$week_end",
    "created": "$TODAY",
    "theme": "",
    "goals": [],
    "priorities": [],
    "wins": [],
    "challenges": [],
    "review": {
        "completed": false,
        "what_went_well": "",
        "what_could_improve": "",
        "lessons_learned": "",
        "energy_level": 0,
        "satisfaction": 0
    },
    "notes": ""
}
EOF
    fi
}

get_week_number() {
    date -d "$WEEK_START" +%V 2>/dev/null || date -jf "%Y-%m-%d" "$WEEK_START" +%V 2>/dev/null
}

show_plan() {
    init_week

    local week_num=$(get_week_number)
    local week_end=$(jq -r '.week_end' "$WEEK_FILE")

    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}              ${BOLD}WEEKLY PLAN - Week $week_num${NC}                         ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}║${NC}              ${CYAN}$WEEK_START to $week_end${NC}                       ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Theme
    local theme=$(jq -r '.theme // ""' "$WEEK_FILE")
    if [[ -n "$theme" && "$theme" != "" ]]; then
        echo -e "${MAGENTA}Theme:${NC} $theme"
        echo ""
    fi

    # Goals
    echo -e "${GREEN}Weekly Goals:${NC}"
    local goal_count=$(jq '.goals | length' "$WEEK_FILE")
    if [[ $goal_count -eq 0 ]]; then
        echo "  ${GRAY}No goals set. Add with: weekly-planner.sh goals add \"goal\"${NC}"
    else
        jq -r '.goals[] | "  [\(if .completed then "✓" else " " end)] \(.text)"' "$WEEK_FILE" | while read -r line; do
            if [[ "$line" == *"[✓]"* ]]; then
                echo -e "  ${GREEN}${line}${NC}"
            else
                echo -e "  ${NC}${line}"
            fi
        done
    fi
    echo ""

    # Priorities
    echo -e "${YELLOW}Top Priorities:${NC}"
    local priority_count=$(jq '.priorities | length' "$WEEK_FILE")
    if [[ $priority_count -eq 0 ]]; then
        echo "  ${GRAY}No priorities set. Add with: weekly-planner.sh priorities add \"priority\"${NC}"
    else
        local i=1
        jq -r '.priorities[]' "$WEEK_FILE" | while read -r priority; do
            echo -e "  ${YELLOW}$i.${NC} $priority"
            i=$((i + 1))
        done
    fi
    echo ""

    # Wins
    local win_count=$(jq '.wins | length' "$WEEK_FILE")
    if [[ $win_count -gt 0 ]]; then
        echo -e "${GREEN}Wins & Achievements:${NC}"
        jq -r '.wins[] | "  ★ \(.text) (\(.date))"' "$WEEK_FILE"
        echo ""
    fi

    # Challenges
    local challenge_count=$(jq '.challenges | length' "$WEEK_FILE")
    if [[ $challenge_count -gt 0 ]]; then
        echo -e "${RED}Challenges & Blockers:${NC}"
        jq -r '.challenges[] | "  ! \(.text) (\(.date))"' "$WEEK_FILE"
        echo ""
    fi

    # Progress from other tools
    show_week_progress
}

show_week_progress() {
    echo -e "${CYAN}This Week's Progress:${NC}"
    echo ""

    # Pomodoros
    local total_pomodoros=0
    local log_file="$SUITE_DIR/pomodoro/data/pomodoro_log.txt"
    if [[ -f "$log_file" ]]; then
        for ((i=0; i<7; i++)); do
            local date=$(date -d "$WEEK_START + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
            local count=$(grep "^$date" "$log_file" 2>/dev/null | wc -l)
            total_pomodoros=$((total_pomodoros + count))
        done
    fi
    echo "  Pomodoros: $total_pomodoros"

    # Time logged
    local total_minutes=0
    local timelog_file="$SUITE_DIR/timelog/data/timelog.csv"
    if [[ -f "$timelog_file" ]]; then
        for ((i=0; i<7; i++)); do
            local date=$(date -d "$WEEK_START + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
            local mins=$(grep "^$date" "$timelog_file" 2>/dev/null | awk -F, '{sum += $3} END {print sum+0}')
            total_minutes=$((total_minutes + mins))
        done
    fi
    local hours=$((total_minutes / 60))
    local mins=$((total_minutes % 60))
    echo "  Time tracked: ${hours}h ${mins}m"

    # Tasks completed
    local tasks_completed=0
    local tasks_file="$SUITE_DIR/tasks/data/tasks.json"
    if [[ -f "$tasks_file" ]]; then
        for ((i=0; i<7; i++)); do
            local date=$(date -d "$WEEK_START + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
            local count=$(jq -r --arg date "$date" '.tasks | map(select(.completed == true and (.completed_at | startswith($date)))) | length' "$tasks_file" 2>/dev/null || echo 0)
            tasks_completed=$((tasks_completed + count))
        done
    fi
    echo "  Tasks completed: $tasks_completed"

    # Habits
    local habits_done=0
    local habits_total=0
    local habits_file="$SUITE_DIR/habits/data/habits.json"
    if [[ -f "$habits_file" ]]; then
        local habits_list=$(jq -r '.habits[]' "$habits_file" 2>/dev/null)
        local habit_count=$(jq '.habits | length' "$habits_file" 2>/dev/null || echo 0)

        for ((i=0; i<7; i++)); do
            local date=$(date -d "$WEEK_START + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
            habits_total=$((habits_total + habit_count))

            local day_done=$(jq -r --arg date "$date" '
                [.habits[] as $h | if .completions[$h] != null and (.completions[$h] | index($date)) != null then 1 else 0 end] | add // 0
            ' "$habits_file" 2>/dev/null || echo 0)
            habits_done=$((habits_done + day_done))
        done
    fi

    local habits_pct=0
    if [[ $habits_total -gt 0 ]]; then
        habits_pct=$((habits_done * 100 / habits_total))
    fi
    echo "  Habits: ${habits_done}/${habits_total} (${habits_pct}%)"
    echo ""
}

manage_goals() {
    init_week
    local action="$1"
    shift

    case "$action" in
        add|a)
            local goal_text="$*"
            if [[ -z "$goal_text" ]]; then
                echo "Usage: weekly-planner.sh goals add \"your goal\""
                exit 1
            fi

            jq --arg text "$goal_text" '.goals += [{"text": $text, "completed": false}]' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
            echo -e "${GREEN}Goal added:${NC} $goal_text"
            ;;

        done|complete|d)
            local index="$1"
            if [[ -z "$index" ]]; then
                echo "Usage: weekly-planner.sh goals done <number>"
                exit 1
            fi

            local array_idx=$((index - 1))
            local goal_text=$(jq -r --argjson idx "$array_idx" '.goals[$idx].text // ""' "$WEEK_FILE")

            if [[ -z "$goal_text" || "$goal_text" == "" ]]; then
                echo -e "${RED}Goal #$index not found${NC}"
                exit 1
            fi

            jq --argjson idx "$array_idx" '.goals[$idx].completed = true' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
            echo -e "${GREEN}Completed:${NC} $goal_text"
            ;;

        remove|rm)
            local index="$1"
            if [[ -z "$index" ]]; then
                echo "Usage: weekly-planner.sh goals remove <number>"
                exit 1
            fi

            local array_idx=$((index - 1))
            jq --argjson idx "$array_idx" 'del(.goals[$idx])' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
            echo -e "${RED}Goal removed${NC}"
            ;;

        *)
            # List goals
            echo -e "${BLUE}Weekly Goals:${NC}"
            echo ""
            local count=$(jq '.goals | length' "$WEEK_FILE")
            if [[ $count -eq 0 ]]; then
                echo "  No goals set yet."
                echo ""
                echo "Add goals with: weekly-planner.sh goals add \"goal\""
            else
                local i=1
                jq -r '.goals[] | "\(.completed)|\(.text)"' "$WEEK_FILE" | while IFS='|' read -r completed text; do
                    if [[ "$completed" == "true" ]]; then
                        echo -e "  ${GREEN}$i. [✓] $text${NC}"
                    else
                        echo -e "  $i. [ ] $text"
                    fi
                    i=$((i + 1))
                done
            fi
            echo ""
            echo "Commands:"
            echo "  goals add \"text\"   - Add a goal"
            echo "  goals done <n>     - Mark goal as complete"
            echo "  goals remove <n>   - Remove a goal"
            ;;
    esac
}

manage_priorities() {
    init_week
    local action="$1"
    shift

    case "$action" in
        add|a)
            local priority_text="$*"
            if [[ -z "$priority_text" ]]; then
                echo "Usage: weekly-planner.sh priorities add \"priority\""
                exit 1
            fi

            local current_count=$(jq '.priorities | length' "$WEEK_FILE")
            if [[ $current_count -ge 3 ]]; then
                echo -e "${YELLOW}You already have 3 priorities. Remove one first or stay focused!${NC}"
                echo ""
                echo "Current priorities:"
                jq -r '.priorities[]' "$WEEK_FILE" | nl -s '. '
                exit 1
            fi

            jq --arg text "$priority_text" '.priorities += [$text]' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
            echo -e "${GREEN}Priority added:${NC} $priority_text"
            ;;

        remove|rm)
            local index="$1"
            if [[ -z "$index" ]]; then
                echo "Usage: weekly-planner.sh priorities remove <number>"
                exit 1
            fi

            local array_idx=$((index - 1))
            jq --argjson idx "$array_idx" 'del(.priorities[$idx])' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
            echo -e "${RED}Priority removed${NC}"
            ;;

        *)
            echo -e "${BLUE}Top Priorities (max 3):${NC}"
            echo ""
            local count=$(jq '.priorities | length' "$WEEK_FILE")
            if [[ $count -eq 0 ]]; then
                echo "  No priorities set."
                echo ""
                echo "Add with: weekly-planner.sh priorities add \"priority\""
            else
                jq -r '.priorities[]' "$WEEK_FILE" | nl -s '. '
            fi
            echo ""
            ;;
    esac
}

add_win() {
    init_week
    local win_text="$*"

    if [[ -z "$win_text" ]]; then
        echo "Usage: weekly-planner.sh wins \"describe your win\""
        exit 1
    fi

    jq --arg text "$win_text" --arg date "$TODAY" '.wins += [{"text": $text, "date": $date}]' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"

    echo -e "${GREEN}Win recorded!${NC} $win_text"
    echo ""
    echo -e "${GRAY}Keep celebrating your progress!${NC}"
}

add_challenge() {
    init_week
    local challenge_text="$*"

    if [[ -z "$challenge_text" ]]; then
        echo "Usage: weekly-planner.sh challenges \"describe the challenge\""
        exit 1
    fi

    jq --arg text "$challenge_text" --arg date "$TODAY" '.challenges += [{"text": $text, "date": $date}]' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"

    echo -e "${YELLOW}Challenge noted:${NC} $challenge_text"
    echo ""
    echo -e "${GRAY}Acknowledging challenges is the first step to overcoming them.${NC}"
}

do_review() {
    init_week

    local week_num=$(get_week_number)

    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}              ${BOLD}WEEKLY REVIEW - Week $week_num${NC}                       ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show summary first
    show_week_progress

    # Goals completion
    local goals_total=$(jq '.goals | length' "$WEEK_FILE")
    local goals_done=$(jq '[.goals[] | select(.completed == true)] | length' "$WEEK_FILE")

    if [[ $goals_total -gt 0 ]]; then
        echo -e "${GREEN}Goals: $goals_done / $goals_total completed${NC}"
        echo ""
    fi

    # Wins summary
    local wins_count=$(jq '.wins | length' "$WEEK_FILE")
    if [[ $wins_count -gt 0 ]]; then
        echo -e "${GREEN}Wins this week ($wins_count):${NC}"
        jq -r '.wins[] | "  ★ \(.text)"' "$WEEK_FILE"
        echo ""
    fi

    # Challenges summary
    local challenges_count=$(jq '.challenges | length' "$WEEK_FILE")
    if [[ $challenges_count -gt 0 ]]; then
        echo -e "${YELLOW}Challenges faced ($challenges_count):${NC}"
        jq -r '.challenges[] | "  ! \(.text)"' "$WEEK_FILE"
        echo ""
    fi

    echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo ""

    # Check if review already done
    local review_done=$(jq -r '.review.completed' "$WEEK_FILE")
    if [[ "$review_done" == "true" ]]; then
        echo -e "${GREEN}Review completed for this week.${NC}"
        echo ""
        echo "Previous reflections:"
        echo ""
        echo -e "${CYAN}What went well:${NC}"
        jq -r '.review.what_went_well // "N/A"' "$WEEK_FILE" | sed 's/^/  /'
        echo ""
        echo -e "${YELLOW}What could improve:${NC}"
        jq -r '.review.what_could_improve // "N/A"' "$WEEK_FILE" | sed 's/^/  /'
        echo ""
        echo -e "${MAGENTA}Lessons learned:${NC}"
        jq -r '.review.lessons_learned // "N/A"' "$WEEK_FILE" | sed 's/^/  /'
        echo ""
        return
    fi

    # Interactive review
    echo -e "${BOLD}Let's reflect on this week:${NC}"
    echo ""

    echo -e "${CYAN}What went well this week?${NC}"
    read -r -p "> " went_well
    echo ""

    echo -e "${YELLOW}What could have gone better?${NC}"
    read -r -p "> " could_improve
    echo ""

    echo -e "${MAGENTA}What did you learn?${NC}"
    read -r -p "> " lessons
    echo ""

    echo -e "${GREEN}Rate your energy level this week (1-5):${NC}"
    read -r -p "> " energy
    energy=${energy:-3}

    echo ""
    echo -e "${GREEN}Rate your overall satisfaction (1-5):${NC}"
    read -r -p "> " satisfaction
    satisfaction=${satisfaction:-3}

    # Save review
    jq --arg well "$went_well" \
       --arg improve "$could_improve" \
       --arg lessons "$lessons" \
       --argjson energy "$energy" \
       --argjson satisfaction "$satisfaction" '
        .review = {
            "completed": true,
            "what_went_well": $well,
            "what_could_improve": $improve,
            "lessons_learned": $lessons,
            "energy_level": $energy,
            "satisfaction": $satisfaction
        }
    ' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"

    echo ""
    echo -e "${GREEN}Review saved! Great job reflecting on your week.${NC}"
}

plan_next_week() {
    # Calculate next week's dates
    local next_week_start=$(date -d "$WEEK_START + 7 days" +%Y-%m-%d 2>/dev/null || date -v+7d -jf "%Y-%m-%d" "$WEEK_START" +%Y-%m-%d 2>/dev/null)
    local next_week_file="$DATA_DIR/week_${next_week_start}.json"

    echo ""
    echo -e "${BOLD}${BLUE}Plan for Next Week${NC}"
    echo -e "${CYAN}Week starting: $next_week_start${NC}"
    echo ""

    # Initialize next week file if needed
    if [[ ! -f "$next_week_file" ]]; then
        local next_week_end=$(date -d "$next_week_start + 6 days" +%Y-%m-%d 2>/dev/null || date -v+6d -jf "%Y-%m-%d" "$next_week_start" +%Y-%m-%d 2>/dev/null)
        cat > "$next_week_file" << EOF
{
    "week_start": "$next_week_start",
    "week_end": "$next_week_end",
    "created": "$TODAY",
    "theme": "",
    "goals": [],
    "priorities": [],
    "wins": [],
    "challenges": [],
    "review": {
        "completed": false,
        "what_went_well": "",
        "what_could_improve": "",
        "lessons_learned": "",
        "energy_level": 0,
        "satisfaction": 0
    },
    "notes": ""
}
EOF
        echo -e "${GREEN}Created plan for next week.${NC}"
        echo ""
    fi

    echo -e "${YELLOW}Set a theme for next week (optional):${NC}"
    read -r -p "> " theme

    if [[ -n "$theme" ]]; then
        jq --arg theme "$theme" '.theme = $theme' "$next_week_file" > "$next_week_file.tmp" && mv "$next_week_file.tmp" "$next_week_file"
    fi

    echo ""
    echo -e "${GREEN}Add goals for next week (empty line to finish):${NC}"
    while true; do
        read -r -p "> " goal
        if [[ -z "$goal" ]]; then
            break
        fi
        jq --arg text "$goal" '.goals += [{"text": $text, "completed": false}]' "$next_week_file" > "$next_week_file.tmp" && mv "$next_week_file.tmp" "$next_week_file"
        echo -e "  ${GREEN}+${NC} $goal"
    done

    echo ""
    echo -e "${YELLOW}Add top priorities for next week (max 3, empty to finish):${NC}"
    local priority_count=0
    while [[ $priority_count -lt 3 ]]; do
        read -r -p "> " priority
        if [[ -z "$priority" ]]; then
            break
        fi
        jq --arg text "$priority" '.priorities += [$text]' "$next_week_file" > "$next_week_file.tmp" && mv "$next_week_file.tmp" "$next_week_file"
        echo -e "  ${YELLOW}$((priority_count + 1)).${NC} $priority"
        priority_count=$((priority_count + 1))
    done

    echo ""
    echo -e "${GREEN}Next week planned!${NC}"
    echo "View it anytime with: weekly-planner.sh plan"
}

show_history() {
    local count=${1:-4}

    echo ""
    echo -e "${BOLD}${BLUE}Past Weeks${NC}"
    echo ""

    local week_files=$(ls -r "$DATA_DIR"/week_*.json 2>/dev/null | head -n "$count")

    if [[ -z "$week_files" ]]; then
        echo "No planning history found."
        exit 0
    fi

    echo "$week_files" | while read -r file; do
        local start=$(jq -r '.week_start' "$file")
        local end=$(jq -r '.week_end' "$file")
        local theme=$(jq -r '.theme // ""' "$file")
        local goals_total=$(jq '.goals | length' "$file")
        local goals_done=$(jq '[.goals[] | select(.completed == true)] | length' "$file")
        local wins=$(jq '.wins | length' "$file")
        local reviewed=$(jq -r '.review.completed' "$file")

        echo -e "${CYAN}Week: $start to $end${NC}"
        if [[ -n "$theme" && "$theme" != "" ]]; then
            echo "  Theme: $theme"
        fi
        echo "  Goals: $goals_done / $goals_total completed"
        echo "  Wins: $wins"
        if [[ "$reviewed" == "true" ]]; then
            local satisfaction=$(jq -r '.review.satisfaction' "$file")
            echo -e "  Review: ${GREEN}Complete${NC} (satisfaction: $satisfaction/5)"
        else
            echo -e "  Review: ${GRAY}Not done${NC}"
        fi
        echo ""
    done
}

set_theme() {
    init_week
    local theme="$*"

    if [[ -z "$theme" ]]; then
        local current=$(jq -r '.theme // ""' "$WEEK_FILE")
        if [[ -n "$current" && "$current" != "" ]]; then
            echo -e "Current theme: ${MAGENTA}$current${NC}"
        else
            echo "No theme set."
        fi
        echo ""
        echo "Set with: weekly-planner.sh theme \"your theme\""
        exit 0
    fi

    jq --arg theme "$theme" '.theme = $theme' "$WEEK_FILE" > "$WEEK_FILE.tmp" && mv "$WEEK_FILE.tmp" "$WEEK_FILE"
    echo -e "${GREEN}Theme set:${NC} $theme"
}

show_help() {
    echo "Weekly Planner - Weekly planning and review tool"
    echo ""
    echo "Usage:"
    echo "  weekly-planner.sh                 Show this week's plan"
    echo "  weekly-planner.sh plan            Show this week's plan"
    echo "  weekly-planner.sh theme \"text\"    Set a theme for the week"
    echo "  weekly-planner.sh goals           View/manage weekly goals"
    echo "  weekly-planner.sh goals add \"g\"   Add a goal"
    echo "  weekly-planner.sh goals done <n>  Complete a goal"
    echo "  weekly-planner.sh priorities      View/manage priorities"
    echo "  weekly-planner.sh priorities add  Add a priority (max 3)"
    echo "  weekly-planner.sh wins \"win\"      Record a win"
    echo "  weekly-planner.sh challenges \"c\"  Note a challenge"
    echo "  weekly-planner.sh review          Weekly review prompts"
    echo "  weekly-planner.sh next            Plan next week"
    echo "  weekly-planner.sh history [n]     View past weeks"
    echo "  weekly-planner.sh help            Show this help"
    echo ""
    echo "Examples:"
    echo "  weekly-planner.sh theme \"Deep Work Week\""
    echo "  weekly-planner.sh goals add \"Complete project proposal\""
    echo "  weekly-planner.sh wins \"Shipped new feature!\""
    echo "  weekly-planner.sh priorities add \"Focus on documentation\""
    echo ""
    echo "Tips:"
    echo "  - Set 3-5 goals per week for focus"
    echo "  - Keep priorities to 3 max (rule of three)"
    echo "  - Record wins daily to build momentum"
    echo "  - Do reviews on Friday or Sunday"
}

case "$1" in
    plan|p|"")
        show_plan
        ;;
    theme|t)
        shift
        set_theme "$@"
        ;;
    goals|g)
        shift
        manage_goals "$@"
        ;;
    priorities|pri)
        shift
        manage_priorities "$@"
        ;;
    wins|win|w)
        shift
        add_win "$@"
        ;;
    challenges|challenge|c)
        shift
        add_challenge "$@"
        ;;
    review|r)
        do_review
        ;;
    next|n)
        plan_next_week
        ;;
    history|h)
        show_history "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'weekly-planner.sh help' for usage"
        exit 1
        ;;
esac
