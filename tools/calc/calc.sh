#!/bin/bash
#
# Calc - Quick calculator and unit converter
#
# Usage:
#   calc.sh <expression>              - Evaluate math expression
#   calc.sh conv <value> <from> <to>  - Convert units
#   calc.sh date <operation>          - Date/time calculations
#   calc.sh percent <value> <of>      - Calculate percentages
#   calc.sh tip <amount> [percent]    - Calculate tip and total
#   calc.sh split <amount> <people>   - Split bill
#   calc.sh units                     - List available units
#   calc.sh history                   - Show calculation history
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
HISTORY_FILE="$DATA_DIR/history.csv"

mkdir -p "$DATA_DIR"

# Initialize history file
if [[ ! -f "$HISTORY_FILE" ]]; then
    echo "timestamp,type,expression,result" > "$HISTORY_FILE"
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

# Check for bc availability
HAS_BC=false
if command -v bc &> /dev/null; then
    HAS_BC=true
fi

# Calculate using bc or awk fallback
do_calc() {
    local expr="$1"
    local scale="${2:-6}"
    if [[ "$HAS_BC" == "true" ]]; then
        echo "scale=$scale; $expr" | bc -l 2>/dev/null
    else
        awk "BEGIN {printf \"%.${scale}f\", $expr}" 2>/dev/null
    fi
}

# Save to history
save_history() {
    local type="$1"
    local expr="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "\"$timestamp\",\"$type\",\"$expr\",\"$result\"" >> "$HISTORY_FILE"
}

# Evaluate mathematical expression using bc or awk
calc_expr() {
    local expr="$*"

    if [[ -z "$expr" ]]; then
        echo "Usage: calc.sh <expression>"
        echo ""
        echo "Examples:"
        echo "  calc.sh 2 + 2"
        echo "  calc.sh '(5 * 3) + 10'"
        echo "  calc.sh '100 / 7'"
        echo "  calc.sh 'sqrt(144)'"
        echo "  calc.sh '2^10'"
        exit 1
    fi

    # Clean up expression - allow common formats
    expr=$(echo "$expr" | sed 's/x/*/g' | sed 's/÷/\//g' | sed 's/×/*/g')

    # Handle percentage syntax like "20% of 150"
    if [[ "$expr" =~ ^([0-9.]+)%\ *of\ *([0-9.]+)$ ]]; then
        local percent="${BASH_REMATCH[1]}"
        local total="${BASH_REMATCH[2]}"
        local result=$(do_calc "$total * $percent / 100" 2)
        echo -e "${GREEN}$result${NC}"
        save_history "percent" "$expr" "$result"
        return
    fi

    # Translate common operators for awk/bc
    local calc_expr="$expr"
    # Convert ^ to ** for bc or handle with awk pow()
    if [[ "$HAS_BC" == "true" ]]; then
        calc_expr=$(echo "$calc_expr" | sed 's/\^/**/g')
    else
        # For awk, convert sqrt() and ^
        calc_expr=$(echo "$calc_expr" | sed 's/sqrt(\([^)]*\))/(\1)^0.5/g')
        calc_expr=$(echo "$calc_expr" | sed 's/\^/**2/g' | sed 's/\*\*2/**/g')
    fi

    # Calculate
    local result=$(do_calc "$calc_expr" 10)

    if [[ -z "$result" ]]; then
        echo -e "${RED}Error: Invalid expression${NC}"
        exit 1
    fi

    # Clean up result - remove trailing zeros after decimal
    if [[ "$result" == *"."* ]]; then
        result=$(echo "$result" | sed 's/0*$//' | sed 's/\.$//')
    fi
    # Handle very small numbers (0.something)
    if [[ "$result" == "."* ]]; then
        result="0$result"
    fi

    echo -e "${GREEN}$result${NC}"
    save_history "calc" "$expr" "$result"
}

# Unit conversion definitions
declare -A LENGTH_UNITS=(
    ["m"]=1
    ["meter"]=1
    ["meters"]=1
    ["km"]=1000
    ["kilometer"]=1000
    ["kilometers"]=1000
    ["cm"]=0.01
    ["centimeter"]=0.01
    ["centimeters"]=0.01
    ["mm"]=0.001
    ["millimeter"]=0.001
    ["millimeters"]=0.001
    ["mi"]=1609.344
    ["mile"]=1609.344
    ["miles"]=1609.344
    ["yd"]=0.9144
    ["yard"]=0.9144
    ["yards"]=0.9144
    ["ft"]=0.3048
    ["foot"]=0.3048
    ["feet"]=0.3048
    ["in"]=0.0254
    ["inch"]=0.0254
    ["inches"]=0.0254
)

declare -A WEIGHT_UNITS=(
    ["kg"]=1
    ["kilogram"]=1
    ["kilograms"]=1
    ["g"]=0.001
    ["gram"]=0.001
    ["grams"]=0.001
    ["mg"]=0.000001
    ["milligram"]=0.000001
    ["milligrams"]=0.000001
    ["lb"]=0.453592
    ["lbs"]=0.453592
    ["pound"]=0.453592
    ["pounds"]=0.453592
    ["oz"]=0.0283495
    ["ounce"]=0.0283495
    ["ounces"]=0.0283495
    ["st"]=6.35029
    ["stone"]=6.35029
)

declare -A DATA_UNITS=(
    ["b"]=1
    ["byte"]=1
    ["bytes"]=1
    ["kb"]=1024
    ["kilobyte"]=1024
    ["kilobytes"]=1024
    ["mb"]=1048576
    ["megabyte"]=1048576
    ["megabytes"]=1048576
    ["gb"]=1073741824
    ["gigabyte"]=1073741824
    ["gigabytes"]=1073741824
    ["tb"]=1099511627776
    ["terabyte"]=1099511627776
    ["terabytes"]=1099511627776
    ["pb"]=1125899906842624
    ["petabyte"]=1125899906842624
)

declare -A TIME_UNITS=(
    ["s"]=1
    ["sec"]=1
    ["second"]=1
    ["seconds"]=1
    ["min"]=60
    ["minute"]=60
    ["minutes"]=60
    ["h"]=3600
    ["hr"]=3600
    ["hour"]=3600
    ["hours"]=3600
    ["d"]=86400
    ["day"]=86400
    ["days"]=86400
    ["w"]=604800
    ["week"]=604800
    ["weeks"]=604800
)

declare -A VOLUME_UNITS=(
    ["l"]=1
    ["liter"]=1
    ["liters"]=1
    ["litre"]=1
    ["litres"]=1
    ["ml"]=0.001
    ["milliliter"]=0.001
    ["milliliters"]=0.001
    ["gal"]=3.78541
    ["gallon"]=3.78541
    ["gallons"]=3.78541
    ["qt"]=0.946353
    ["quart"]=0.946353
    ["quarts"]=0.946353
    ["pt"]=0.473176
    ["pint"]=0.473176
    ["pints"]=0.473176
    ["cup"]=0.236588
    ["cups"]=0.236588
    ["floz"]=0.0295735
    ["fl_oz"]=0.0295735
)

# Temperature conversion (special handling)
convert_temp() {
    local value="$1"
    local from="${2,,}"
    local to="${3,,}"

    # Normalize unit names
    [[ "$from" == "celsius" ]] && from="c"
    [[ "$from" == "fahrenheit" ]] && from="f"
    [[ "$from" == "kelvin" ]] && from="k"
    [[ "$to" == "celsius" ]] && to="c"
    [[ "$to" == "fahrenheit" ]] && to="f"
    [[ "$to" == "kelvin" ]] && to="k"

    local result

    if [[ "$from" == "$to" ]]; then
        result="$value"
    elif [[ "$from" == "c" && "$to" == "f" ]]; then
        result=$(do_calc "($value * 9/5) + 32" 2)
    elif [[ "$from" == "f" && "$to" == "c" ]]; then
        result=$(do_calc "($value - 32) * 5/9" 2)
    elif [[ "$from" == "c" && "$to" == "k" ]]; then
        result=$(do_calc "$value + 273.15" 2)
    elif [[ "$from" == "k" && "$to" == "c" ]]; then
        result=$(do_calc "$value - 273.15" 2)
    elif [[ "$from" == "f" && "$to" == "k" ]]; then
        result=$(do_calc "(($value - 32) * 5/9) + 273.15" 2)
    elif [[ "$from" == "k" && "$to" == "f" ]]; then
        result=$(do_calc "(($value - 273.15) * 9/5) + 32" 2)
    else
        echo -e "${RED}Unknown temperature units.${NC}"
        echo "Use: c, f, k (or celsius, fahrenheit, kelvin)"
        return 1
    fi

    echo "$result"
}

# Get unit category and base multiplier
get_unit_info() {
    local unit="${1,,}"

    if [[ -n "${LENGTH_UNITS[$unit]}" ]]; then
        echo "length ${LENGTH_UNITS[$unit]}"
    elif [[ -n "${WEIGHT_UNITS[$unit]}" ]]; then
        echo "weight ${WEIGHT_UNITS[$unit]}"
    elif [[ -n "${DATA_UNITS[$unit]}" ]]; then
        echo "data ${DATA_UNITS[$unit]}"
    elif [[ -n "${TIME_UNITS[$unit]}" ]]; then
        echo "time ${TIME_UNITS[$unit]}"
    elif [[ -n "${VOLUME_UNITS[$unit]}" ]]; then
        echo "volume ${VOLUME_UNITS[$unit]}"
    elif [[ "$unit" =~ ^(c|f|k|celsius|fahrenheit|kelvin)$ ]]; then
        echo "temperature special"
    else
        echo ""
    fi
}

# Convert between units
convert_units() {
    local value="$1"
    local from="$2"
    local to="$3"

    if [[ -z "$value" ]] || [[ -z "$from" ]] || [[ -z "$to" ]]; then
        echo "Usage: calc.sh conv <value> <from-unit> <to-unit>"
        echo ""
        echo "Examples:"
        echo "  calc.sh conv 100 km miles"
        echo "  calc.sh conv 72 f c"
        echo "  calc.sh conv 1024 mb gb"
        echo "  calc.sh conv 180 min hours"
        echo "  calc.sh conv 150 lbs kg"
        echo ""
        echo "Run 'calc.sh units' to see all available units"
        exit 1
    fi

    local from_lower="${from,,}"
    local to_lower="${to,,}"

    # Get unit info
    local from_info=$(get_unit_info "$from_lower")
    local to_info=$(get_unit_info "$to_lower")

    if [[ -z "$from_info" ]]; then
        echo -e "${RED}Unknown unit: $from${NC}"
        echo "Run 'calc.sh units' to see available units"
        exit 1
    fi

    if [[ -z "$to_info" ]]; then
        echo -e "${RED}Unknown unit: $to${NC}"
        echo "Run 'calc.sh units' to see available units"
        exit 1
    fi

    local from_cat=$(echo "$from_info" | cut -d' ' -f1)
    local from_mult=$(echo "$from_info" | cut -d' ' -f2)
    local to_cat=$(echo "$to_info" | cut -d' ' -f1)
    local to_mult=$(echo "$to_info" | cut -d' ' -f2)

    # Check same category
    if [[ "$from_cat" != "$to_cat" ]]; then
        echo -e "${RED}Cannot convert $from_cat to $to_cat${NC}"
        exit 1
    fi

    local result

    # Handle temperature specially
    if [[ "$from_cat" == "temperature" ]]; then
        result=$(convert_temp "$value" "$from_lower" "$to_lower")
    else
        # Standard conversion: value * from_multiplier / to_multiplier
        result=$(do_calc "$value * $from_mult / $to_mult" 6)

        # Clean up result
        if [[ "$result" == *"."* ]]; then
            result=$(echo "$result" | sed 's/0*$//' | sed 's/\.$//')
        fi
        if [[ "$result" == "."* ]]; then
            result="0$result"
        fi
    fi

    echo -e "${CYAN}$value $from${NC} = ${GREEN}$result $to${NC}"
    save_history "convert" "$value $from to $to" "$result $to"
}

# Date calculations
date_calc() {
    local operation="$1"
    shift
    local args="$*"

    case "$operation" in
        diff|between)
            # Calculate days between two dates
            local date1="$1"
            local date2="${2:-$(date +%Y-%m-%d)}"

            if [[ -z "$date1" ]]; then
                echo "Usage: calc.sh date diff <date1> [date2]"
                echo "  If date2 is omitted, uses today"
                echo ""
                echo "Examples:"
                echo "  calc.sh date diff 2024-01-01"
                echo "  calc.sh date diff 2024-01-01 2024-12-31"
                exit 1
            fi

            local sec1=$(date -d "$date1" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$date1" +%s 2>/dev/null)
            local sec2=$(date -d "$date2" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$date2" +%s 2>/dev/null)

            if [[ -z "$sec1" ]] || [[ -z "$sec2" ]]; then
                echo -e "${RED}Invalid date format. Use YYYY-MM-DD${NC}"
                exit 1
            fi

            local diff_sec=$((sec2 - sec1))
            local diff_days=$((diff_sec / 86400))
            local diff_weeks=$((diff_days / 7))
            local diff_months=$(( (diff_days * 12) / 365 ))

            [[ $diff_days -lt 0 ]] && diff_days=$((-diff_days))

            echo -e "${CYAN}From:${NC} $date1"
            echo -e "${CYAN}To:${NC}   $date2"
            echo ""
            echo -e "${GREEN}$diff_days days${NC}"
            echo -e "${GRAY}  (~$diff_weeks weeks, ~$diff_months months)${NC}"
            save_history "date_diff" "$date1 to $date2" "$diff_days days"
            ;;

        add|plus)
            # Add time to a date
            local amount="$1"
            local unit="${2:-days}"
            local from_date="${3:-$(date +%Y-%m-%d)}"

            if [[ -z "$amount" ]]; then
                echo "Usage: calc.sh date add <amount> <unit> [from-date]"
                echo ""
                echo "Examples:"
                echo "  calc.sh date add 30 days"
                echo "  calc.sh date add 2 weeks 2024-06-01"
                echo "  calc.sh date add 3 months"
                exit 1
            fi

            local result_date
            # Try GNU date first, then BSD date
            result_date=$(date -d "$from_date + $amount $unit" +%Y-%m-%d 2>/dev/null)
            if [[ -z "$result_date" ]]; then
                # BSD date (macOS)
                local days=$amount
                case "$unit" in
                    week|weeks) days=$((amount * 7)) ;;
                    month|months) days=$((amount * 30)) ;;
                    year|years) days=$((amount * 365)) ;;
                esac
                result_date=$(date -j -v+${days}d -f "%Y-%m-%d" "$from_date" +%Y-%m-%d 2>/dev/null)
            fi

            if [[ -z "$result_date" ]]; then
                echo -e "${RED}Error calculating date${NC}"
                exit 1
            fi

            echo -e "${CYAN}$from_date${NC} + $amount $unit = ${GREEN}$result_date${NC}"
            echo -e "${GRAY}$(date -d "$result_date" '+%A, %B %d, %Y' 2>/dev/null || date -j -f "%Y-%m-%d" "$result_date" '+%A, %B %d, %Y' 2>/dev/null)${NC}"
            save_history "date_add" "$from_date + $amount $unit" "$result_date"
            ;;

        sub|minus)
            # Subtract time from a date
            local amount="$1"
            local unit="${2:-days}"
            local from_date="${3:-$(date +%Y-%m-%d)}"

            if [[ -z "$amount" ]]; then
                echo "Usage: calc.sh date sub <amount> <unit> [from-date]"
                exit 1
            fi

            local result_date
            result_date=$(date -d "$from_date - $amount $unit" +%Y-%m-%d 2>/dev/null)
            if [[ -z "$result_date" ]]; then
                local days=$amount
                case "$unit" in
                    week|weeks) days=$((amount * 7)) ;;
                    month|months) days=$((amount * 30)) ;;
                    year|years) days=$((amount * 365)) ;;
                esac
                result_date=$(date -j -v-${days}d -f "%Y-%m-%d" "$from_date" +%Y-%m-%d 2>/dev/null)
            fi

            if [[ -z "$result_date" ]]; then
                echo -e "${RED}Error calculating date${NC}"
                exit 1
            fi

            echo -e "${CYAN}$from_date${NC} - $amount $unit = ${GREEN}$result_date${NC}"
            save_history "date_sub" "$from_date - $amount $unit" "$result_date"
            ;;

        now|today)
            local format="${1:-%Y-%m-%d %H:%M:%S}"
            date +"$format"
            ;;

        week)
            # Show week number
            local for_date="${1:-$(date +%Y-%m-%d)}"
            local week_num=$(date -d "$for_date" +%V 2>/dev/null || date -j -f "%Y-%m-%d" "$for_date" +%V 2>/dev/null)
            echo -e "Week ${GREEN}$week_num${NC} of $(date -d "$for_date" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$for_date" +%Y 2>/dev/null)"
            ;;

        *)
            echo "Usage: calc.sh date <operation>"
            echo ""
            echo "Operations:"
            echo "  diff <date1> [date2]         Days between dates"
            echo "  add <amount> <unit> [date]   Add time to date"
            echo "  sub <amount> <unit> [date]   Subtract time from date"
            echo "  week [date]                  Show week number"
            echo "  now                          Current date/time"
            echo ""
            echo "Examples:"
            echo "  calc.sh date diff 2024-01-01"
            echo "  calc.sh date add 90 days"
            echo "  calc.sh date sub 2 weeks 2024-12-25"
            ;;
    esac
}

# Calculate percentage
calc_percent() {
    local value="$1"
    local of_val="$2"

    if [[ -z "$value" ]] || [[ -z "$of_val" ]]; then
        echo "Usage: calc.sh percent <value> <of-total>"
        echo ""
        echo "Examples:"
        echo "  calc.sh percent 25 200     # 25 is what % of 200?"
        echo "  calc.sh percent 15 60      # 15 is what % of 60?"
        exit 1
    fi

    local result=$(do_calc "($value / $of_val) * 100" 2)
    echo -e "${CYAN}$value${NC} is ${GREEN}$result%${NC} of ${CYAN}$of_val${NC}"
    save_history "percent" "$value of $of_val" "$result%"
}

# Calculate tip
calc_tip() {
    local amount="$1"
    local percent="${2:-20}"

    if [[ -z "$amount" ]]; then
        echo "Usage: calc.sh tip <amount> [percent]"
        echo "  Default tip is 20%"
        echo ""
        echo "Examples:"
        echo "  calc.sh tip 45.50"
        echo "  calc.sh tip 85 15"
        exit 1
    fi

    local tip=$(do_calc "$amount * $percent / 100" 2)
    local total=$(do_calc "$amount + $tip" 2)

    echo -e "${BLUE}=== Tip Calculator ===${NC}"
    echo ""
    echo -e "${CYAN}Bill:${NC}  \$$amount"
    echo -e "${CYAN}Tip (${percent}%):${NC} \$${GREEN}$tip${NC}"
    echo -e "${CYAN}Total:${NC} \$${GREEN}$total${NC}"
    save_history "tip" "$amount @ $percent%" "tip: $tip, total: $total"
}

# Split bill
calc_split() {
    local amount="$1"
    local people="$2"
    local tip_percent="${3:-20}"

    if [[ -z "$amount" ]] || [[ -z "$people" ]]; then
        echo "Usage: calc.sh split <amount> <people> [tip-percent]"
        echo ""
        echo "Examples:"
        echo "  calc.sh split 120 4"
        echo "  calc.sh split 85.50 3 18"
        exit 1
    fi

    local tip=$(do_calc "$amount * $tip_percent / 100" 2)
    local total=$(do_calc "$amount + $tip" 2)
    local per_person=$(do_calc "$total / $people" 2)

    echo -e "${BLUE}=== Bill Split ===${NC}"
    echo ""
    echo -e "${CYAN}Bill:${NC}       \$$amount"
    echo -e "${CYAN}Tip ($tip_percent%):${NC}   \$$tip"
    echo -e "${CYAN}Total:${NC}      \$$total"
    echo -e "${CYAN}People:${NC}     $people"
    echo ""
    echo -e "${GREEN}Each pays:${NC}  \$${BOLD}$per_person${NC}"
    save_history "split" "$amount / $people (+ $tip_percent% tip)" "$per_person each"
}

# List available units
list_units() {
    echo -e "${BLUE}=== Available Units ===${NC}"
    echo ""

    echo -e "${YELLOW}Length:${NC}"
    echo "  m, km, cm, mm, mi (miles), yd (yards), ft (feet), in (inches)"
    echo ""

    echo -e "${YELLOW}Weight/Mass:${NC}"
    echo "  kg, g, mg, lb/lbs (pounds), oz (ounces), st (stone)"
    echo ""

    echo -e "${YELLOW}Data Size:${NC}"
    echo "  b (bytes), kb, mb, gb, tb, pb"
    echo ""

    echo -e "${YELLOW}Time:${NC}"
    echo "  s/sec (seconds), min (minutes), h/hr (hours), d (days), w (weeks)"
    echo ""

    echo -e "${YELLOW}Volume:${NC}"
    echo "  l/liter, ml, gal (gallon), qt (quart), pt (pint), cup, floz"
    echo ""

    echo -e "${YELLOW}Temperature:${NC}"
    echo "  c (celsius), f (fahrenheit), k (kelvin)"
    echo ""

    echo -e "${CYAN}Examples:${NC}"
    echo "  calc.sh conv 100 km miles"
    echo "  calc.sh conv 72 f c"
    echo "  calc.sh conv 500 gb tb"
}

# Show history
show_history() {
    local count=${1:-10}

    echo -e "${BLUE}=== Calculation History (Last $count) ===${NC}"
    echo ""

    local line_count=$(tail -n +2 "$HISTORY_FILE" 2>/dev/null | wc -l)

    if [[ $line_count -eq 0 ]]; then
        echo "No calculations yet."
        exit 0
    fi

    tail -n +2 "$HISTORY_FILE" | tail -n "$count" | tac | while IFS=, read -r timestamp type expr result; do
        # Remove quotes
        timestamp=$(echo "$timestamp" | tr -d '"')
        type=$(echo "$type" | tr -d '"')
        expr=$(echo "$expr" | tr -d '"')
        result=$(echo "$result" | tr -d '"')

        local short_time=$(echo "$timestamp" | cut -d' ' -f2 | cut -d: -f1-2)
        echo -e "  ${GRAY}$short_time${NC} ${CYAN}[$type]${NC} $expr = ${GREEN}$result${NC}"
    done
}

# Clear history
clear_history() {
    echo "timestamp,type,expression,result" > "$HISTORY_FILE"
    echo -e "${GREEN}History cleared.${NC}"
}

# Show help
show_help() {
    echo "Calc - Quick calculator and unit converter"
    echo ""
    echo "Usage:"
    echo "  calc.sh <expression>              Evaluate math expression"
    echo "  calc.sh conv <val> <from> <to>    Convert units"
    echo "  calc.sh date <operation>          Date calculations"
    echo "  calc.sh percent <val> <total>     What % is val of total"
    echo "  calc.sh tip <amount> [%]          Calculate tip (default 20%)"
    echo "  calc.sh split <amount> <people>   Split bill with tip"
    echo "  calc.sh units                     List available units"
    echo "  calc.sh history [n]               Show last n calculations"
    echo "  calc.sh clear                     Clear history"
    echo "  calc.sh help                      Show this help"
    echo ""
    echo "Math Examples:"
    echo "  calc.sh 2 + 2"
    echo "  calc.sh '(100 - 20) / 4'"
    echo "  calc.sh 'sqrt(144)'"
    echo "  calc.sh '2^10'"
    echo "  calc.sh '20% of 150'"
    echo ""
    echo "Conversion Examples:"
    echo "  calc.sh conv 100 km miles"
    echo "  calc.sh conv 72 f c"
    echo "  calc.sh conv 1024 mb gb"
    echo ""
    echo "Date Examples:"
    echo "  calc.sh date diff 2024-01-01"
    echo "  calc.sh date add 30 days"
    echo "  calc.sh date week"
}

# Main command parsing
case "$1" in
    conv|convert)
        shift
        convert_units "$@"
        ;;
    date)
        shift
        date_calc "$@"
        ;;
    percent|pct|%)
        shift
        calc_percent "$@"
        ;;
    tip)
        shift
        calc_tip "$@"
        ;;
    split)
        shift
        calc_split "$@"
        ;;
    units)
        list_units
        ;;
    history|hist)
        show_history "$2"
        ;;
    clear)
        clear_history
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        # Assume it's a math expression
        calc_expr "$@"
        ;;
esac
