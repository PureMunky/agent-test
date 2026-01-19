#!/bin/bash
#
# World Clock - Time zone converter and world clock for remote collaboration
#
# Usage:
#   worldclock.sh                         - Show current time in saved locations
#   worldclock.sh now                     - Show current time in all saved locations
#   worldclock.sh add <name> <timezone>   - Add a location
#   worldclock.sh remove <name>           - Remove a location
#   worldclock.sh list                    - List saved locations
#   worldclock.sh convert <time> <from> to <to>  - Convert time between zones
#   worldclock.sh at <time> [from_tz]     - Show what time it is everywhere at given time
#   worldclock.sh meeting <time> [from_tz] - Find best meeting times
#   worldclock.sh zones [search]          - List available timezones
#   worldclock.sh diff <tz1> <tz2>        - Show time difference between zones
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOCATIONS_FILE="$DATA_DIR/locations.json"

mkdir -p "$DATA_DIR"

# Initialize locations file with some defaults if it doesn't exist
if [[ ! -f "$LOCATIONS_FILE" ]]; then
    cat > "$LOCATIONS_FILE" << 'EOF'
{
    "locations": [
        {"name": "Local", "timezone": "local", "emoji": "🏠"},
        {"name": "UTC", "timezone": "UTC", "emoji": "🌐"},
        {"name": "New York", "timezone": "America/New_York", "emoji": "🗽"},
        {"name": "London", "timezone": "Europe/London", "emoji": "🇬🇧"},
        {"name": "Tokyo", "timezone": "Asia/Tokyo", "emoji": "🇯🇵"}
    ],
    "default_format": "%H:%M",
    "show_date": true
}
EOF
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

# Get time in a specific timezone
get_time_in_tz() {
    local tz="$1"
    local format="${2:-%H:%M}"
    local input_time="$3"

    if [[ "$tz" == "local" ]]; then
        if [[ -n "$input_time" ]]; then
            date -d "$input_time" +"$format" 2>/dev/null
        else
            date +"$format"
        fi
    else
        if [[ -n "$input_time" ]]; then
            TZ="$tz" date -d "$input_time" +"$format" 2>/dev/null
        else
            TZ="$tz" date +"$format" 2>/dev/null
        fi
    fi
}

# Get date in a specific timezone
get_date_in_tz() {
    local tz="$1"

    if [[ "$tz" == "local" ]]; then
        date +"%a %b %d"
    else
        TZ="$tz" date +"%a %b %d" 2>/dev/null
    fi
}

# Validate timezone
validate_timezone() {
    local tz="$1"

    if [[ "$tz" == "local" ]] || [[ "$tz" == "UTC" ]]; then
        return 0
    fi

    # Check if timezone is valid by trying to use it
    if TZ="$tz" date &>/dev/null; then
        return 0
    fi

    return 1
}

# Get UTC offset for a timezone
get_utc_offset() {
    local tz="$1"

    if [[ "$tz" == "local" ]]; then
        date +%z
    else
        TZ="$tz" date +%z 2>/dev/null
    fi
}

# Format UTC offset for display
format_offset() {
    local offset="$1"
    # Convert +0530 to +5:30 format
    local sign="${offset:0:1}"
    local hours="${offset:1:2}"
    local mins="${offset:3:2}"

    # Remove leading zeros
    hours=$((10#$hours))

    if [[ "$mins" == "00" ]]; then
        echo "UTC${sign}${hours}"
    else
        echo "UTC${sign}${hours}:${mins}"
    fi
}

# Show current time in all locations
show_now() {
    local show_date=$(jq -r '.show_date // true' "$LOCATIONS_FILE")

    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}                    ${BOLD}WORLD CLOCK${NC}                            ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local local_date=$(date +"%A, %B %d, %Y")
    echo -e "  ${GRAY}$local_date${NC}"
    echo ""

    jq -r '.locations[] | "\(.emoji)|\(.name)|\(.timezone)"' "$LOCATIONS_FILE" | while IFS='|' read -r emoji name tz; do
        local time=$(get_time_in_tz "$tz" "%H:%M")
        local offset=$(get_utc_offset "$tz")
        local offset_fmt=$(format_offset "$offset")
        local date_str=""

        if [[ "$show_date" == "true" ]]; then
            date_str=$(get_date_in_tz "$tz")
        fi

        # Determine if it's work hours (9-18) for color coding
        local hour=$(get_time_in_tz "$tz" "%H")
        local color="$NC"
        if [[ $hour -ge 9 ]] && [[ $hour -lt 18 ]]; then
            color="$GREEN"
        elif [[ $hour -ge 18 ]] && [[ $hour -lt 22 ]]; then
            color="$YELLOW"
        else
            color="$GRAY"
        fi

        printf "  ${color}%s %-15s${NC} ${BOLD}%s${NC}  ${GRAY}%s  %s${NC}\n" "$emoji" "$name" "$time" "$offset_fmt" "$date_str"
    done

    echo ""
    echo -e "  ${GRAY}Legend: ${GREEN}■${NC} Work hours (9-18) ${YELLOW}■${NC} Evening ${GRAY}■${NC} Night${NC}"
    echo ""
}

# Add a location
add_location() {
    local name="$1"
    local tz="$2"
    local emoji="${3:-🌍}"

    if [[ -z "$name" ]] || [[ -z "$tz" ]]; then
        echo "Usage: worldclock.sh add <name> <timezone> [emoji]"
        echo ""
        echo "Examples:"
        echo "  worldclock.sh add Berlin Europe/Berlin"
        echo "  worldclock.sh add Sydney Australia/Sydney 🦘"
        echo ""
        echo "Run 'worldclock.sh zones' to see available timezones"
        exit 1
    fi

    # Validate timezone
    if ! validate_timezone "$tz"; then
        echo -e "${RED}Invalid timezone: $tz${NC}"
        echo "Run 'worldclock.sh zones $tz' to search for valid timezones"
        exit 1
    fi

    # Check if location already exists
    local exists=$(jq -r --arg name "$name" '.locations | map(select(.name == $name)) | length' "$LOCATIONS_FILE")

    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Location '$name' already exists. Updating...${NC}"
        jq --arg name "$name" --arg tz "$tz" --arg emoji "$emoji" '
            .locations = [.locations[] | if .name == $name then .timezone = $tz | .emoji = $emoji else . end]
        ' "$LOCATIONS_FILE" > "$LOCATIONS_FILE.tmp" && mv "$LOCATIONS_FILE.tmp" "$LOCATIONS_FILE"
    else
        jq --arg name "$name" --arg tz "$tz" --arg emoji "$emoji" '
            .locations += [{"name": $name, "timezone": $tz, "emoji": $emoji}]
        ' "$LOCATIONS_FILE" > "$LOCATIONS_FILE.tmp" && mv "$LOCATIONS_FILE.tmp" "$LOCATIONS_FILE"
    fi

    local current_time=$(get_time_in_tz "$tz" "%H:%M")
    echo -e "${GREEN}Added:${NC} $emoji $name ($tz)"
    echo -e "${CYAN}Current time:${NC} $current_time"
}

# Remove a location
remove_location() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: worldclock.sh remove <name>"
        exit 1
    fi

    local exists=$(jq -r --arg name "$name" '.locations | map(select(.name == $name)) | length' "$LOCATIONS_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Location '$name' not found${NC}"
        exit 1
    fi

    jq --arg name "$name" '.locations = [.locations[] | select(.name != $name)]' "$LOCATIONS_FILE" > "$LOCATIONS_FILE.tmp" && mv "$LOCATIONS_FILE.tmp" "$LOCATIONS_FILE"

    echo -e "${GREEN}Removed:${NC} $name"
}

# List saved locations
list_locations() {
    echo -e "${BLUE}=== Saved Locations ===${NC}"
    echo ""

    jq -r '.locations[] | "\(.emoji)|\(.name)|\(.timezone)"' "$LOCATIONS_FILE" | while IFS='|' read -r emoji name tz; do
        local offset=$(get_utc_offset "$tz")
        local offset_fmt=$(format_offset "$offset")
        printf "  %s %-15s  ${GRAY}%-25s %s${NC}\n" "$emoji" "$name" "$tz" "$offset_fmt"
    done
    echo ""
}

# Convert time between timezones
convert_time() {
    local time_str="$1"
    local from_tz="$2"
    local to_word="$3"
    local to_tz="$4"

    if [[ -z "$time_str" ]] || [[ -z "$from_tz" ]] || [[ -z "$to_tz" ]]; then
        echo "Usage: worldclock.sh convert <time> <from_timezone> to <to_timezone>"
        echo ""
        echo "Examples:"
        echo "  worldclock.sh convert 14:00 America/New_York to Europe/London"
        echo "  worldclock.sh convert \"2026-01-20 09:00\" UTC to Asia/Tokyo"
        exit 1
    fi

    # Resolve timezone names from saved locations
    from_tz=$(resolve_timezone "$from_tz")
    to_tz=$(resolve_timezone "$to_tz")

    # Validate timezones
    if ! validate_timezone "$from_tz"; then
        echo -e "${RED}Invalid source timezone: $from_tz${NC}"
        exit 1
    fi

    if ! validate_timezone "$to_tz"; then
        echo -e "${RED}Invalid target timezone: $to_tz${NC}"
        exit 1
    fi

    # Parse input time - if just HH:MM, assume today
    local full_time="$time_str"
    if [[ "$time_str" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        full_time="$(date +%Y-%m-%d) $time_str"
    fi

    # Convert the time
    local from_epoch=$(TZ="$from_tz" date -d "$full_time" +%s 2>/dev/null)

    if [[ -z "$from_epoch" ]]; then
        echo -e "${RED}Could not parse time: $time_str${NC}"
        exit 1
    fi

    local result_time=$(TZ="$to_tz" date -d "@$from_epoch" "+%H:%M" 2>/dev/null)
    local result_date=$(TZ="$to_tz" date -d "@$from_epoch" "+%a %b %d" 2>/dev/null)
    local from_time_display=$(TZ="$from_tz" date -d "@$from_epoch" "+%H:%M" 2>/dev/null)
    local from_date_display=$(TZ="$from_tz" date -d "@$from_epoch" "+%a %b %d" 2>/dev/null)

    echo ""
    echo -e "${CYAN}Time Conversion:${NC}"
    echo ""
    echo -e "  ${GRAY}From:${NC} ${BOLD}$from_time_display${NC} $from_date_display ($from_tz)"
    echo -e "  ${GRAY}To:${NC}   ${BOLD}${GREEN}$result_time${NC}${NC} $result_date ($to_tz)"
    echo ""
}

# Resolve location name to timezone
resolve_timezone() {
    local input="$1"

    # Check if it's a saved location name
    local saved_tz=$(jq -r --arg name "$input" '.locations[] | select(.name == $name) | .timezone' "$LOCATIONS_FILE" 2>/dev/null)

    if [[ -n "$saved_tz" ]] && [[ "$saved_tz" != "null" ]]; then
        echo "$saved_tz"
    else
        echo "$input"
    fi
}

# Show time at a specific time across all locations
show_at_time() {
    local time_str="$1"
    local from_tz="${2:-local}"

    if [[ -z "$time_str" ]]; then
        echo "Usage: worldclock.sh at <time> [from_timezone]"
        echo ""
        echo "Examples:"
        echo "  worldclock.sh at 14:00"
        echo "  worldclock.sh at \"2026-01-20 09:00\" America/New_York"
        exit 1
    fi

    from_tz=$(resolve_timezone "$from_tz")

    # Parse input time
    local full_time="$time_str"
    if [[ "$time_str" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        full_time="$(date +%Y-%m-%d) $time_str"
    fi

    local from_epoch=$(TZ="$from_tz" date -d "$full_time" +%s 2>/dev/null)

    if [[ -z "$from_epoch" ]]; then
        echo -e "${RED}Could not parse time: $time_str${NC}"
        exit 1
    fi

    local from_display=$(TZ="$from_tz" date -d "@$from_epoch" "+%H:%M on %a %b %d" 2>/dev/null)

    echo ""
    echo -e "${BOLD}${BLUE}When it's $from_display ($from_tz):${NC}"
    echo ""

    jq -r '.locations[] | "\(.emoji)|\(.name)|\(.timezone)"' "$LOCATIONS_FILE" | while IFS='|' read -r emoji name tz; do
        local result_time=$(TZ="$tz" date -d "@$from_epoch" "+%H:%M" 2>/dev/null)
        local result_date=$(TZ="$tz" date -d "@$from_epoch" "+%a %b %d" 2>/dev/null)

        # Color code by work hours
        local hour=$(TZ="$tz" date -d "@$from_epoch" "+%H" 2>/dev/null)
        local color="$NC"
        if [[ $hour -ge 9 ]] && [[ $hour -lt 18 ]]; then
            color="$GREEN"
        elif [[ $hour -ge 18 ]] && [[ $hour -lt 22 ]]; then
            color="$YELLOW"
        else
            color="$GRAY"
        fi

        printf "  ${color}%s %-15s${NC} ${BOLD}%s${NC}  ${GRAY}%s${NC}\n" "$emoji" "$name" "$result_time" "$result_date"
    done
    echo ""
}

# Find best meeting times
find_meeting_time() {
    local preferred_time="${1:-09:00}"
    local from_tz="${2:-local}"

    from_tz=$(resolve_timezone "$from_tz")

    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}              ${BOLD}MEETING TIME FINDER${NC}                          ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Finding overlap in work hours (9:00-18:00) across locations...${NC}"
    echo ""

    # Check a range of times and find the best overlap
    local best_overlap=0
    local best_time=""

    for hour in {8..20}; do
        local test_time=$(printf "%02d:00" $hour)
        local full_time="$(date +%Y-%m-%d) $test_time"
        local test_epoch=$(TZ="$from_tz" date -d "$full_time" +%s 2>/dev/null)

        local work_hours_count=0
        local total_locations=$(jq '.locations | length' "$LOCATIONS_FILE")

        while IFS='|' read -r emoji name tz; do
            local loc_hour=$(TZ="$tz" date -d "@$test_epoch" "+%H" 2>/dev/null)
            loc_hour=$((10#$loc_hour))  # Remove leading zero

            if [[ $loc_hour -ge 9 ]] && [[ $loc_hour -lt 18 ]]; then
                work_hours_count=$((work_hours_count + 1))
            fi
        done < <(jq -r '.locations[] | "\(.emoji)|\(.name)|\(.timezone)"' "$LOCATIONS_FILE")

        if [[ $work_hours_count -gt $best_overlap ]]; then
            best_overlap=$work_hours_count
            best_time="$test_time"
        fi
    done

    if [[ -n "$best_time" ]]; then
        echo -e "${GREEN}Best meeting time: $best_time ($from_tz)${NC}"
        echo -e "${GRAY}$best_overlap location(s) in work hours${NC}"
        echo ""
        show_at_time "$best_time" "$from_tz"
    else
        echo -e "${YELLOW}No ideal overlap found. Consider async communication.${NC}"
    fi
}

# List available timezones
list_zones() {
    local search="${1:-}"

    echo -e "${BLUE}=== Available Timezones ===${NC}"
    echo ""

    if [[ -n "$search" ]]; then
        echo -e "${CYAN}Searching for: $search${NC}"
        echo ""
        timedatectl list-timezones 2>/dev/null | grep -i "$search" | head -30 || \
        find /usr/share/zoneinfo -type f 2>/dev/null | sed 's|/usr/share/zoneinfo/||' | grep -v '^posix\|^right\|^+' | grep -i "$search" | sort | head -30
    else
        echo "Common timezones:"
        echo ""
        echo "  Americas:"
        echo "    America/New_York     (Eastern US)"
        echo "    America/Chicago      (Central US)"
        echo "    America/Denver       (Mountain US)"
        echo "    America/Los_Angeles  (Pacific US)"
        echo "    America/Toronto      (Canada Eastern)"
        echo "    America/Sao_Paulo    (Brazil)"
        echo ""
        echo "  Europe:"
        echo "    Europe/London        (UK)"
        echo "    Europe/Paris         (France, Central Europe)"
        echo "    Europe/Berlin        (Germany)"
        echo "    Europe/Moscow        (Russia)"
        echo ""
        echo "  Asia/Pacific:"
        echo "    Asia/Tokyo           (Japan)"
        echo "    Asia/Shanghai        (China)"
        echo "    Asia/Singapore       (Singapore)"
        echo "    Asia/Dubai           (UAE)"
        echo "    Asia/Kolkata         (India)"
        echo "    Australia/Sydney     (Australia Eastern)"
        echo ""
        echo "Search: worldclock.sh zones <search_term>"
    fi
    echo ""
}

# Show time difference between two timezones
show_diff() {
    local tz1="$1"
    local tz2="$2"

    if [[ -z "$tz1" ]] || [[ -z "$tz2" ]]; then
        echo "Usage: worldclock.sh diff <timezone1> <timezone2>"
        echo ""
        echo "Example: worldclock.sh diff America/New_York Europe/London"
        exit 1
    fi

    tz1=$(resolve_timezone "$tz1")
    tz2=$(resolve_timezone "$tz2")

    local offset1=$(get_utc_offset "$tz1")
    local offset2=$(get_utc_offset "$tz2")

    # Convert offsets to minutes
    local sign1="${offset1:0:1}"
    local hours1=$((10#${offset1:1:2}))
    local mins1=$((10#${offset1:3:2}))
    local total1=$((hours1 * 60 + mins1))
    [[ "$sign1" == "-" ]] && total1=$((total1 * -1))

    local sign2="${offset2:0:1}"
    local hours2=$((10#${offset2:1:2}))
    local mins2=$((10#${offset2:3:2}))
    local total2=$((hours2 * 60 + mins2))
    [[ "$sign2" == "-" ]] && total2=$((total2 * -1))

    local diff=$((total2 - total1))
    local diff_hours=$((diff / 60))
    local diff_mins=$((${diff#-} % 60))

    local diff_sign=""
    if [[ $diff -gt 0 ]]; then
        diff_sign="+"
    elif [[ $diff -lt 0 ]]; then
        diff_sign=""
    fi

    local time1=$(get_time_in_tz "$tz1" "%H:%M")
    local time2=$(get_time_in_tz "$tz2" "%H:%M")

    echo ""
    echo -e "${BLUE}Time Difference:${NC}"
    echo ""
    echo -e "  ${BOLD}$tz1${NC}: $time1 ($(format_offset "$offset1"))"
    echo -e "  ${BOLD}$tz2${NC}: $time2 ($(format_offset "$offset2"))"
    echo ""

    if [[ $diff_mins -eq 0 ]]; then
        echo -e "  ${CYAN}Difference: ${diff_sign}${diff_hours} hours${NC}"
    else
        echo -e "  ${CYAN}Difference: ${diff_sign}${diff_hours}h ${diff_mins}m${NC}"
    fi

    if [[ $diff -gt 0 ]]; then
        echo -e "  ${GRAY}$tz2 is ahead of $tz1${NC}"
    elif [[ $diff -lt 0 ]]; then
        echo -e "  ${GRAY}$tz2 is behind $tz1${NC}"
    else
        echo -e "  ${GRAY}Same time zone${NC}"
    fi
    echo ""
}

show_help() {
    echo "World Clock - Time zone converter for remote collaboration"
    echo ""
    echo "Usage:"
    echo "  worldclock.sh                         Show current time in saved locations"
    echo "  worldclock.sh now                     Same as above"
    echo "  worldclock.sh add <name> <tz> [emoji] Add a location"
    echo "  worldclock.sh remove <name>           Remove a location"
    echo "  worldclock.sh list                    List saved locations with timezones"
    echo ""
    echo "  worldclock.sh convert <time> <from> to <to>"
    echo "                                        Convert time between zones"
    echo "  worldclock.sh at <time> [from_tz]     Show time everywhere at given time"
    echo "  worldclock.sh meeting [time] [tz]     Find best meeting times"
    echo "  worldclock.sh diff <tz1> <tz2>        Show time difference"
    echo "  worldclock.sh zones [search]          List/search available timezones"
    echo ""
    echo "Examples:"
    echo "  worldclock.sh add Berlin Europe/Berlin 🇩🇪"
    echo "  worldclock.sh convert 14:00 America/New_York to Europe/London"
    echo "  worldclock.sh at 09:00 UTC"
    echo "  worldclock.sh meeting 10:00"
    echo "  worldclock.sh diff Tokyo London"
    echo ""
    echo "Time is color-coded: green=work hours, yellow=evening, gray=night"
}

case "$1" in
    now|"")
        show_now
        ;;
    add|new)
        add_location "$2" "$3" "$4"
        ;;
    remove|rm|delete)
        remove_location "$2"
        ;;
    list|ls)
        list_locations
        ;;
    convert|conv)
        convert_time "$2" "$3" "$4" "$5"
        ;;
    at|when)
        shift
        show_at_time "$@"
        ;;
    meeting|meet)
        find_meeting_time "$2" "$3"
        ;;
    diff|difference)
        show_diff "$2" "$3"
        ;;
    zones|tz|timezones)
        list_zones "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'worldclock.sh help' for usage"
        exit 1
        ;;
esac
