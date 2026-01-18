#!/bin/bash
#
# Energy Tracker - Track energy levels and mood throughout the day
#
# Usage:
#   energy.sh log [1-5] [mood] [note]  - Log energy level (1=low, 5=high)
#   energy.sh quick [1-5]              - Quick log without mood/note
#   energy.sh today                    - Show today's energy entries
#   energy.sh week                     - Show this week's summary
#   energy.sh patterns                 - Analyze energy patterns by time of day
#   energy.sh history [days]           - Show history for past N days
#   energy.sh stats                    - Show overall statistics
#   energy.sh export [format]          - Export data (csv/json)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
ENERGY_FILE="$DATA_DIR/energy.json"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%Y-%m-%d %H:%M')
HOUR=$(date +%H)

mkdir -p "$DATA_DIR"

# Initialize energy file if it doesn't exist
if [[ ! -f "$ENERGY_FILE" ]]; then
    echo '{"entries":[],"moods":["great","good","okay","tired","stressed","focused","creative","anxious","calm","energized"]}' > "$ENERGY_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Energy level to visual bar
energy_bar() {
    local level=$1
    local bar=""
    for i in $(seq 1 5); do
        if [[ $i -le $level ]]; then
            case $level in
                1|2) bar+="${RED}█${NC}" ;;
                3) bar+="${YELLOW}█${NC}" ;;
                4|5) bar+="${GREEN}█${NC}" ;;
            esac
        else
            bar+="${GRAY}░${NC}"
        fi
    done
    echo -e "$bar"
}

# Energy level description
energy_desc() {
    local level=$1
    case $level in
        1) echo "Very Low" ;;
        2) echo "Low" ;;
        3) echo "Moderate" ;;
        4) echo "High" ;;
        5) echo "Very High" ;;
    esac
}

# Get time period label
time_period() {
    local hour=$1
    if [[ $hour -ge 5 && $hour -lt 9 ]]; then
        echo "early_morning"
    elif [[ $hour -ge 9 && $hour -lt 12 ]]; then
        echo "morning"
    elif [[ $hour -ge 12 && $hour -lt 14 ]]; then
        echo "midday"
    elif [[ $hour -ge 14 && $hour -lt 17 ]]; then
        echo "afternoon"
    elif [[ $hour -ge 17 && $hour -lt 21 ]]; then
        echo "evening"
    else
        echo "night"
    fi
}

time_period_label() {
    local period=$1
    case $period in
        early_morning) echo "Early Morning (5-9)" ;;
        morning) echo "Morning (9-12)" ;;
        midday) echo "Midday (12-14)" ;;
        afternoon) echo "Afternoon (14-17)" ;;
        evening) echo "Evening (17-21)" ;;
        night) echo "Night (21-5)" ;;
    esac
}

log_energy() {
    local level=$1
    local mood=$2
    local note=$3

    if [[ -z "$level" ]] || [[ ! "$level" =~ ^[1-5]$ ]]; then
        echo -e "${RED}Error: Energy level must be 1-5${NC}"
        echo ""
        echo "Usage: energy.sh log <1-5> [mood] [note]"
        echo ""
        echo "Energy levels:"
        echo "  1 = Very Low  (exhausted, need rest)"
        echo "  2 = Low       (tired, sluggish)"
        echo "  3 = Moderate  (okay, functional)"
        echo "  4 = High      (good energy, productive)"
        echo "  5 = Very High (peak energy, focused)"
        echo ""
        echo "Example moods: great, good, okay, tired, stressed, focused, creative, anxious, calm, energized"
        exit 1
    fi

    local period=$(time_period $HOUR)

    jq --arg ts "$NOW" --argjson level "$level" --arg mood "$mood" --arg note "$note" --arg period "$period" --arg hour "$HOUR" '
        .entries += [{
            "timestamp": $ts,
            "level": $level,
            "mood": (if $mood == "" then null else $mood end),
            "note": (if $note == "" then null else $note end),
            "period": $period,
            "hour": ($hour | tonumber)
        }]
    ' "$ENERGY_FILE" > "$ENERGY_FILE.tmp" && mv "$ENERGY_FILE.tmp" "$ENERGY_FILE"

    echo -e "${GREEN}Energy logged!${NC}"
    echo ""
    echo -e "  Level: $(energy_bar $level) $(energy_desc $level)"
    [[ -n "$mood" ]] && echo -e "  Mood:  ${CYAN}$mood${NC}"
    [[ -n "$note" ]] && echo -e "  Note:  $note"
    echo -e "  Time:  ${GRAY}$NOW ($(time_period_label $period))${NC}"
}

quick_log() {
    local level=$1
    if [[ -z "$level" ]] || [[ ! "$level" =~ ^[1-5]$ ]]; then
        echo "Usage: energy.sh quick <1-5>"
        exit 1
    fi
    log_energy "$level" "" ""
}

show_today() {
    echo -e "${BLUE}=== Today's Energy Log ($TODAY) ===${NC}"
    echo ""

    local entries=$(jq -r --arg today "$TODAY" '[.entries[] | select(.timestamp | startswith($today))]' "$ENERGY_FILE")
    local count=$(echo "$entries" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo "No entries today. Log your energy with: energy.sh log <1-5> [mood] [note]"
        exit 0
    fi

    local avg=$(echo "$entries" | jq '[.[].level] | add / length | . * 10 | floor / 10')

    echo "$entries" | jq -r '.[] | "\(.timestamp | split(" ")[1]) \(.level) \(.mood // "-") \(.note // "")"' | while read time level mood note; do
        local bar=$(energy_bar $level)
        echo -e "  ${CYAN}$time${NC} $bar ${GRAY}$mood${NC}"
        [[ "$note" != "" ]] && echo -e "         ${GRAY}$note${NC}"
    done

    echo ""
    echo -e "  ${YELLOW}Average: $avg/5${NC}"

    # Show peak energy time
    local peak=$(echo "$entries" | jq -r 'max_by(.level) | "\(.timestamp | split(" ")[1]) (\(.level))"')
    echo -e "  ${GREEN}Peak:    $peak${NC}"
}

show_week() {
    echo -e "${BLUE}=== This Week's Energy Summary ===${NC}"
    echo ""

    local week_start=$(date -d "last sunday" +%Y-%m-%d 2>/dev/null || date -v -sun +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

    local days=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
    local current_day=$(date +%u)  # 1=Monday, 7=Sunday
    [[ $current_day -eq 7 ]] && current_day=0

    for i in $(seq 0 6); do
        local day_date=$(date -d "$week_start + $i days" +%Y-%m-%d 2>/dev/null || date -v +${i}d -j -f "%Y-%m-%d" "$week_start" +%Y-%m-%d 2>/dev/null)
        local day_entries=$(jq -r --arg d "$day_date" '[.entries[] | select(.timestamp | startswith($d))]' "$ENERGY_FILE")
        local day_count=$(echo "$day_entries" | jq 'length')

        local marker=" "
        [[ "$day_date" == "$TODAY" ]] && marker="${GREEN}>${NC}"

        if [[ "$day_count" -gt 0 ]]; then
            local avg=$(echo "$day_entries" | jq '[.[].level] | add / length | floor')
            local bar=$(energy_bar $avg)
            echo -e " $marker${days[$i]} $day_date  $bar  ($day_count entries)"
        else
            echo -e " $marker${days[$i]} $day_date  ${GRAY}░░░░░${NC}  ${GRAY}(no data)${NC}"
        fi
    done
}

show_patterns() {
    echo -e "${BLUE}=== Energy Patterns by Time of Day ===${NC}"
    echo ""

    local periods=("early_morning" "morning" "midday" "afternoon" "evening" "night")

    for period in "${periods[@]}"; do
        local period_entries=$(jq -r --arg p "$period" '[.entries[] | select(.period == $p)]' "$ENERGY_FILE")
        local count=$(echo "$period_entries" | jq 'length')

        local label=$(time_period_label $period)

        if [[ "$count" -gt 0 ]]; then
            local avg=$(echo "$period_entries" | jq '[.[].level] | add / length | . * 10 | floor / 10')
            local avg_int=$(echo "$period_entries" | jq '[.[].level] | add / length | floor')
            local bar=$(energy_bar $avg_int)
            printf "  %-20s %s  %.1f avg  (%d entries)\n" "$label" "$(echo -e $bar)" "$avg" "$count"
        else
            printf "  %-20s ${GRAY}░░░░░${NC}  ${GRAY}(no data)${NC}\n" "$label"
        fi
    done

    echo ""

    # Find best and worst times
    local best=$(jq -r '[.entries[] | {period, level}] | group_by(.period) | map({period: .[0].period, avg: ([.[].level] | add / length)}) | max_by(.avg) | .period' "$ENERGY_FILE")
    local worst=$(jq -r '[.entries[] | {period, level}] | group_by(.period) | map({period: .[0].period, avg: ([.[].level] | add / length)}) | min_by(.avg) | .period' "$ENERGY_FILE")

    if [[ "$best" != "null" ]]; then
        echo -e "  ${GREEN}Best time:  $(time_period_label $best)${NC}"
        echo -e "  ${YELLOW}Low time:   $(time_period_label $worst)${NC}"
        echo ""
        echo -e "  ${CYAN}Tip: Schedule important work during your peak energy time!${NC}"
    fi
}

show_history() {
    local days=${1:-7}

    echo -e "${BLUE}=== Energy History (Last $days days) ===${NC}"
    echo ""

    for i in $(seq $((days - 1)) -1 0); do
        local day_date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v -${i}d +%Y-%m-%d 2>/dev/null)
        local day_entries=$(jq -r --arg d "$day_date" '[.entries[] | select(.timestamp | startswith($d))]' "$ENERGY_FILE")
        local count=$(echo "$day_entries" | jq 'length')

        local marker=" "
        [[ "$day_date" == "$TODAY" ]] && marker="${GREEN}>${NC}"

        if [[ "$count" -gt 0 ]]; then
            local avg=$(echo "$day_entries" | jq '[.[].level] | add / length | floor')
            local bar=$(energy_bar $avg)
            local day_name=$(date -d "$day_date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$day_date" +%a 2>/dev/null)
            echo -e " $marker$day_name $day_date  $bar  ($count entries)"
        else
            local day_name=$(date -d "$day_date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$day_date" +%a 2>/dev/null)
            echo -e " $marker$day_name $day_date  ${GRAY}░░░░░${NC}  ${GRAY}(no data)${NC}"
        fi
    done
}

show_stats() {
    echo -e "${BLUE}=== Energy Statistics ===${NC}"
    echo ""

    local total=$(jq '.entries | length' "$ENERGY_FILE")

    if [[ "$total" -eq 0 ]]; then
        echo "No data yet. Start logging with: energy.sh log <1-5> [mood] [note]"
        exit 0
    fi

    local overall_avg=$(jq '[.entries[].level] | add / length | . * 100 | floor / 100' "$ENERGY_FILE")
    local first_entry=$(jq -r '.entries[0].timestamp | split(" ")[0]' "$ENERGY_FILE")
    local unique_days=$(jq -r '[.entries[].timestamp | split(" ")[0]] | unique | length' "$ENERGY_FILE")

    echo -e "  Total entries:      ${CYAN}$total${NC}"
    echo -e "  Days tracked:       ${CYAN}$unique_days${NC}"
    echo -e "  Overall average:    ${CYAN}$overall_avg/5${NC}"
    echo -e "  Tracking since:     ${CYAN}$first_entry${NC}"
    echo ""

    # Level distribution
    echo -e "${YELLOW}Level Distribution:${NC}"
    for level in $(seq 1 5); do
        local count=$(jq --argjson l $level '[.entries[] | select(.level == $l)] | length' "$ENERGY_FILE")
        local pct=$(echo "scale=0; $count * 100 / $total" | bc 2>/dev/null || echo "0")
        local bar_len=$((pct / 5))
        local bar=""
        for j in $(seq 1 $bar_len); do bar+="█"; done
        printf "  Level %d: %3d%% %s (%d)\n" "$level" "$pct" "$bar" "$count"
    done
    echo ""

    # Most common moods
    local moods=$(jq -r '[.entries[] | select(.mood != null) | .mood] | group_by(.) | map({mood: .[0], count: length}) | sort_by(-.count) | .[0:5]' "$ENERGY_FILE")
    local mood_count=$(echo "$moods" | jq 'length')

    if [[ "$mood_count" -gt 0 ]]; then
        echo -e "${YELLOW}Top Moods:${NC}"
        echo "$moods" | jq -r '.[] | "  \(.mood): \(.count)"'
    fi
}

export_data() {
    local format=${1:-csv}

    case $format in
        csv)
            echo "timestamp,level,mood,note,period,hour"
            jq -r '.entries[] | [.timestamp, .level, (.mood // ""), (.note // ""), .period, .hour] | @csv' "$ENERGY_FILE"
            ;;
        json)
            jq '.entries' "$ENERGY_FILE"
            ;;
        *)
            echo "Unknown format: $format"
            echo "Supported: csv, json"
            exit 1
            ;;
    esac
}

show_help() {
    echo "Energy Tracker - Track energy levels and mood throughout the day"
    echo ""
    echo "Usage:"
    echo "  energy.sh log <1-5> [mood] [note]  Log energy with optional mood and note"
    echo "  energy.sh quick <1-5>              Quick log (energy level only)"
    echo "  energy.sh today                    Show today's entries"
    echo "  energy.sh week                     Show this week's summary"
    echo "  energy.sh patterns                 Analyze patterns by time of day"
    echo "  energy.sh history [days]           Show history (default: 7 days)"
    echo "  energy.sh stats                    Show overall statistics"
    echo "  energy.sh export [csv|json]        Export data"
    echo "  energy.sh help                     Show this help"
    echo ""
    echo "Energy Levels:"
    echo "  1 = Very Low  (exhausted, need rest)"
    echo "  2 = Low       (tired, sluggish)"
    echo "  3 = Moderate  (okay, functional)"
    echo "  4 = High      (good energy, productive)"
    echo "  5 = Very High (peak energy, focused)"
    echo ""
    echo "Example Moods:"
    echo "  great, good, okay, tired, stressed, focused, creative, anxious, calm, energized"
    echo ""
    echo "Examples:"
    echo "  energy.sh log 4 focused \"After morning coffee\""
    echo "  energy.sh quick 3"
    echo "  energy.sh patterns"
}

case "$1" in
    log)
        shift
        log_energy "$1" "$2" "$3"
        ;;
    quick|q)
        quick_log "$2"
        ;;
    today|t)
        show_today
        ;;
    week|w)
        show_week
        ;;
    patterns|p)
        show_patterns
        ;;
    history|h)
        show_history "$2"
        ;;
    stats|s)
        show_stats
        ;;
    export|e)
        export_data "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_today
        ;;
    *)
        # If it's a number 1-5, treat as quick log
        if [[ "$1" =~ ^[1-5]$ ]]; then
            quick_log "$1"
        else
            echo "Unknown command: $1"
            echo "Run 'energy.sh help' for usage"
            exit 1
        fi
        ;;
esac
