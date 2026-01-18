#!/bin/bash
#
# GenPass - Secure password and secret generator
#
# Usage:
#   genpass.sh                       - Generate a default 16-char password
#   genpass.sh <length>              - Generate password of specific length
#   genpass.sh pin <length>          - Generate numeric PIN (default: 6)
#   genpass.sh alpha <length>        - Letters only (default: 16)
#   genpass.sh alnum <length>        - Alphanumeric only (default: 16)
#   genpass.sh hex <length>          - Hexadecimal (default: 32)
#   genpass.sh base64 <length>       - Base64 string (default: 32)
#   genpass.sh uuid                  - Generate UUID v4
#   genpass.sh token                 - Generate API-style token
#   genpass.sh passphrase [words]    - Generate word-based passphrase
#   genpass.sh batch <type> <count>  - Generate multiple at once
#   genpass.sh save <name>           - Save last generated to vault
#   genpass.sh vault                 - List saved secrets
#   genpass.sh get <name>            - Retrieve secret from vault
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
VAULT_FILE="$DATA_DIR/vault.json"
LAST_FILE="$DATA_DIR/last.txt"
WORDS_FILE="$DATA_DIR/wordlist.txt"

mkdir -p "$DATA_DIR"

# Initialize vault if it doesn't exist
if [[ ! -f "$VAULT_FILE" ]]; then
    echo '{"secrets":[]}' > "$VAULT_FILE"
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

# Character sets
CHARS_LOWER="abcdefghijklmnopqrstuvwxyz"
CHARS_UPPER="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
CHARS_DIGITS="0123456789"
CHARS_SPECIAL="!@#\$%^&*()_+-=[]{}|;:,.<>?"
CHARS_SPECIAL_SAFE="!@#%^*_+-="
CHARS_HEX="0123456789abcdef"

# Common word list for passphrases (embedded for portability)
COMMON_WORDS=(
    "apple" "banana" "orange" "grape" "lemon" "mango" "cherry" "peach"
    "ocean" "river" "mountain" "forest" "desert" "island" "valley" "meadow"
    "tiger" "eagle" "dolphin" "wolf" "falcon" "panther" "cobra" "hawk"
    "crystal" "thunder" "shadow" "diamond" "silver" "golden" "cosmic" "stellar"
    "brave" "swift" "silent" "wild" "bright" "dark" "noble" "fierce"
    "castle" "bridge" "tower" "garden" "harbor" "canyon" "glacier" "volcano"
    "rocket" "comet" "nebula" "quasar" "photon" "laser" "plasma" "fusion"
    "cipher" "matrix" "vector" "quantum" "binary" "neural" "crypto" "omega"
    "storm" "flame" "frost" "spark" "blaze" "surge" "pulse" "wave"
    "quest" "voyage" "venture" "mission" "journey" "odyssey" "saga" "legend"
    "anchor" "compass" "beacon" "lantern" "prism" "mirror" "echo" "whisper"
    "zenith" "apex" "summit" "pinnacle" "vertex" "peak" "crest" "crown"
)

# Check for jq
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq not installed. Vault features disabled."
        return 1
    fi
    return 0
}

# Generate random bytes using /dev/urandom
random_bytes() {
    local count="$1"
    head -c "$count" /dev/urandom 2>/dev/null || openssl rand "$count" 2>/dev/null
}

# Generate password from character set
generate_from_charset() {
    local length="$1"
    local charset="$2"
    local charset_len=${#charset}
    local result=""

    # Read random bytes and map to charset
    local bytes=$(random_bytes "$length" | od -An -tu1 | tr -d ' \n')
    local i=0

    while [[ ${#result} -lt $length ]]; do
        # Get next byte value
        local byte=$(echo "$bytes" | cut -c$((i*3+1))-$((i*3+3)) | tr -d ' ')
        if [[ -z "$byte" ]]; then
            # Need more random bytes
            bytes=$(random_bytes "$length" | od -An -tu1 | tr -d ' \n')
            i=0
            continue
        fi

        # Map to charset index
        local idx=$((byte % charset_len))
        result+="${charset:$idx:1}"
        ((i++))
    done

    echo "$result"
}

# Generate strong password (includes all character types)
generate_password() {
    local length="${1:-16}"

    if [[ $length -lt 8 ]]; then
        echo -e "${YELLOW}Warning: Passwords under 8 characters are weak${NC}" >&2
    fi

    local all_chars="${CHARS_LOWER}${CHARS_UPPER}${CHARS_DIGITS}${CHARS_SPECIAL_SAFE}"
    local password=""

    # Ensure at least one of each type for passwords >= 8
    if [[ $length -ge 8 ]]; then
        password+=$(generate_from_charset 1 "$CHARS_LOWER")
        password+=$(generate_from_charset 1 "$CHARS_UPPER")
        password+=$(generate_from_charset 1 "$CHARS_DIGITS")
        password+=$(generate_from_charset 1 "$CHARS_SPECIAL_SAFE")
        password+=$(generate_from_charset $((length - 4)) "$all_chars")

        # Shuffle the password
        password=$(echo "$password" | fold -w1 | shuf | tr -d '\n')
    else
        password=$(generate_from_charset "$length" "$all_chars")
    fi

    echo "$password"
}

# Generate PIN
generate_pin() {
    local length="${1:-6}"
    generate_from_charset "$length" "$CHARS_DIGITS"
}

# Generate alphabetic only
generate_alpha() {
    local length="${1:-16}"
    generate_from_charset "$length" "${CHARS_LOWER}${CHARS_UPPER}"
}

# Generate alphanumeric
generate_alnum() {
    local length="${1:-16}"
    generate_from_charset "$length" "${CHARS_LOWER}${CHARS_UPPER}${CHARS_DIGITS}"
}

# Generate hex string
generate_hex() {
    local length="${1:-32}"
    random_bytes $((length / 2 + 1)) | xxd -p | tr -d '\n' | head -c "$length"
    echo
}

# Generate base64 string
generate_base64() {
    local length="${1:-32}"
    random_bytes $((length * 3 / 4 + 3)) | base64 | tr -d '\n' | head -c "$length"
    echo
}

# Generate UUID v4
generate_uuid() {
    # Generate 16 random bytes
    local hex=$(random_bytes 16 | xxd -p | tr -d '\n')

    # Format as UUID with version 4 and variant bits set
    local p1="${hex:0:8}"
    local p2="${hex:8:4}"
    local p3="4${hex:13:3}"  # Version 4
    local p4=$(printf '%x' $(( (0x${hex:16:2} & 0x3f) | 0x80 )))${hex:18:2}  # Variant
    local p5="${hex:20:12}"

    echo "${p1}-${p2}-${p3}-${p4}-${p5}"
}

# Generate API-style token
generate_token() {
    local prefix="${1:-}"
    local token=$(generate_alnum 32)

    if [[ -n "$prefix" ]]; then
        echo "${prefix}_${token}"
    else
        echo "$token"
    fi
}

# Generate word-based passphrase
generate_passphrase() {
    local word_count="${1:-4}"
    local separator="${2:--}"
    local words=()
    local word_list_size=${#COMMON_WORDS[@]}

    for ((i=0; i<word_count; i++)); do
        # Get random index
        local idx=$(( $(od -An -tu4 -N4 /dev/urandom | tr -d ' ') % word_list_size ))
        local word="${COMMON_WORDS[$idx]}"

        # Capitalize first letter randomly
        if [[ $(( $(od -An -tu1 -N1 /dev/urandom | tr -d ' ') % 2 )) -eq 1 ]]; then
            word="${word^}"
        fi

        words+=("$word")
    done

    # Join with separator and optionally add numbers
    local result=$(IFS="$separator"; echo "${words[*]}")

    # Add a random 2-digit number at the end for extra entropy
    local num=$(printf "%02d" $(( $(od -An -tu2 -N2 /dev/urandom | tr -d ' ') % 100 )))

    echo "${result}${separator}${num}"
}

# Save to last file and optionally copy to clipboard
save_last() {
    local value="$1"
    local type="$2"

    echo "$value" > "$LAST_FILE"

    # Try to copy to clipboard
    if command -v xclip &> /dev/null; then
        echo -n "$value" | xclip -selection clipboard 2>/dev/null
        echo -e "${GRAY}(copied to clipboard)${NC}"
    elif command -v pbcopy &> /dev/null; then
        echo -n "$value" | pbcopy 2>/dev/null
        echo -e "${GRAY}(copied to clipboard)${NC}"
    elif command -v wl-copy &> /dev/null; then
        echo -n "$value" | wl-copy 2>/dev/null
        echo -e "${GRAY}(copied to clipboard)${NC}"
    fi
}

# Output result
output_result() {
    local value="$1"
    local type="${2:-password}"

    echo -e "${GREEN}${value}${NC}"
    save_last "$value" "$type"
}

# Generate batch
generate_batch() {
    local type="${1:-password}"
    local count="${2:-5}"
    local length="${3:-16}"

    echo -e "${BLUE}=== Generating $count ${type}s ===${NC}"
    echo ""

    for ((i=1; i<=count; i++)); do
        local result=""
        case "$type" in
            password|pass) result=$(generate_password "$length") ;;
            pin) result=$(generate_pin "$length") ;;
            alpha) result=$(generate_alpha "$length") ;;
            alnum) result=$(generate_alnum "$length") ;;
            hex) result=$(generate_hex "$length") ;;
            base64) result=$(generate_base64 "$length") ;;
            uuid) result=$(generate_uuid) ;;
            token) result=$(generate_token) ;;
            passphrase|phrase) result=$(generate_passphrase "$length") ;;
            *) result=$(generate_password "$length") ;;
        esac

        printf "  ${GRAY}%2d.${NC} ${GREEN}%s${NC}\n" "$i" "$result"
    done

    echo ""
}

# Save to vault
save_to_vault() {
    local name="$1"

    if ! check_jq; then
        echo -e "${RED}Error: jq required for vault operations${NC}"
        exit 1
    fi

    if [[ -z "$name" ]]; then
        echo "Usage: genpass.sh save <name>"
        echo "Saves the last generated secret to the vault"
        exit 1
    fi

    if [[ ! -f "$LAST_FILE" ]]; then
        echo -e "${RED}No secret to save. Generate one first.${NC}"
        exit 1
    fi

    local value=$(cat "$LAST_FILE")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if name already exists
    local exists=$(jq -r --arg name "$name" '.secrets | map(select(.name == $name)) | length' "$VAULT_FILE")

    if [[ "$exists" -gt 0 ]]; then
        echo -e "${YELLOW}Warning: '$name' already exists. Overwriting.${NC}"
        jq --arg name "$name" '.secrets = [.secrets[] | select(.name != $name)]' "$VAULT_FILE" > "$VAULT_FILE.tmp" && mv "$VAULT_FILE.tmp" "$VAULT_FILE"
    fi

    jq --arg name "$name" --arg value "$value" --arg ts "$timestamp" '
        .secrets += [{
            "name": $name,
            "value": $value,
            "created": $ts
        }]
    ' "$VAULT_FILE" > "$VAULT_FILE.tmp" && mv "$VAULT_FILE.tmp" "$VAULT_FILE"

    echo -e "${GREEN}Saved to vault:${NC} $name"
}

# List vault contents
list_vault() {
    if ! check_jq; then
        echo -e "${RED}Error: jq required for vault operations${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Secret Vault ===${NC}"
    echo ""

    local count=$(jq '.secrets | length' "$VAULT_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "Vault is empty."
        echo "Save a secret with: genpass.sh save <name>"
        exit 0
    fi

    jq -r '.secrets[] | "\(.name)|\(.created)|\(.value)"' "$VAULT_FILE" | while IFS='|' read -r name created value; do
        # Mask value for display
        local masked="${value:0:4}****${value: -4}"
        echo -e "  ${GREEN}$name${NC}"
        echo -e "    ${GRAY}Created: $created${NC}"
        echo -e "    ${GRAY}Value: $masked${NC}"
        echo ""
    done

    echo -e "${CYAN}Retrieve with: genpass.sh get <name>${NC}"
}

# Get secret from vault
get_from_vault() {
    local name="$1"

    if ! check_jq; then
        echo -e "${RED}Error: jq required for vault operations${NC}"
        exit 1
    fi

    if [[ -z "$name" ]]; then
        echo "Usage: genpass.sh get <name>"
        exit 1
    fi

    local value=$(jq -r --arg name "$name" '.secrets[] | select(.name == $name) | .value' "$VAULT_FILE")

    if [[ -z "$value" ]]; then
        echo -e "${RED}Secret not found:${NC} $name"
        echo ""
        echo "Available secrets:"
        jq -r '.secrets[].name' "$VAULT_FILE" | while read n; do
            echo "  - $n"
        done
        exit 1
    fi

    echo -e "${GREEN}$value${NC}"
    save_last "$value" "vault"
}

# Delete from vault
delete_from_vault() {
    local name="$1"

    if ! check_jq; then
        echo -e "${RED}Error: jq required for vault operations${NC}"
        exit 1
    fi

    if [[ -z "$name" ]]; then
        echo "Usage: genpass.sh delete <name>"
        exit 1
    fi

    local exists=$(jq -r --arg name "$name" '.secrets | map(select(.name == $name)) | length' "$VAULT_FILE")

    if [[ "$exists" -eq 0 ]]; then
        echo -e "${RED}Secret not found:${NC} $name"
        exit 1
    fi

    jq --arg name "$name" '.secrets = [.secrets[] | select(.name != $name)]' "$VAULT_FILE" > "$VAULT_FILE.tmp" && mv "$VAULT_FILE.tmp" "$VAULT_FILE"

    echo -e "${RED}Deleted:${NC} $name"
}

# Show strength analysis
analyze_strength() {
    local password="${1:-}"

    if [[ -z "$password" ]]; then
        if [[ -f "$LAST_FILE" ]]; then
            password=$(cat "$LAST_FILE")
        else
            echo "Usage: genpass.sh strength <password>"
            exit 1
        fi
    fi

    local length=${#password}
    local has_lower=0 has_upper=0 has_digit=0 has_special=0
    local charset_size=0

    [[ "$password" =~ [a-z] ]] && has_lower=1 && ((charset_size+=26))
    [[ "$password" =~ [A-Z] ]] && has_upper=1 && ((charset_size+=26))
    [[ "$password" =~ [0-9] ]] && has_digit=1 && ((charset_size+=10))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && has_special=1 && ((charset_size+=32))

    # Calculate entropy (bits)
    local entropy=$(echo "scale=2; l($charset_size^$length)/l(2)" | bc -l 2>/dev/null || echo "N/A")

    local score=$((has_lower + has_upper + has_digit + has_special))
    local rating=""
    local color=""

    if [[ $length -ge 16 && $score -ge 4 ]]; then
        rating="EXCELLENT"
        color="$GREEN"
    elif [[ $length -ge 12 && $score -ge 3 ]]; then
        rating="STRONG"
        color="$GREEN"
    elif [[ $length -ge 8 && $score -ge 3 ]]; then
        rating="GOOD"
        color="$YELLOW"
    elif [[ $length -ge 8 && $score -ge 2 ]]; then
        rating="FAIR"
        color="$YELLOW"
    else
        rating="WEAK"
        color="$RED"
    fi

    echo -e "${BLUE}=== Password Strength Analysis ===${NC}"
    echo ""
    echo -e "  Password: ${GRAY}${password:0:4}****${password: -4}${NC}"
    echo -e "  Length: $length characters"
    echo ""
    echo -e "  Character types:"
    [[ $has_lower -eq 1 ]] && echo -e "    ${GREEN}[x]${NC} Lowercase" || echo -e "    ${GRAY}[ ]${NC} Lowercase"
    [[ $has_upper -eq 1 ]] && echo -e "    ${GREEN}[x]${NC} Uppercase" || echo -e "    ${GRAY}[ ]${NC} Uppercase"
    [[ $has_digit -eq 1 ]] && echo -e "    ${GREEN}[x]${NC} Numbers" || echo -e "    ${GRAY}[ ]${NC} Numbers"
    [[ $has_special -eq 1 ]] && echo -e "    ${GREEN}[x]${NC} Special characters" || echo -e "    ${GRAY}[ ]${NC} Special characters"
    echo ""
    echo -e "  Entropy: ~${entropy} bits"
    echo -e "  Rating: ${color}${rating}${NC}"
    echo ""
}

show_help() {
    echo "GenPass - Secure password and secret generator"
    echo ""
    echo "Usage:"
    echo "  genpass.sh                        Generate 16-char password"
    echo "  genpass.sh <length>               Generate password of length"
    echo "  genpass.sh pin [length]           Numeric PIN (default: 6)"
    echo "  genpass.sh alpha [length]         Letters only (default: 16)"
    echo "  genpass.sh alnum [length]         Alphanumeric (default: 16)"
    echo "  genpass.sh hex [length]           Hex string (default: 32)"
    echo "  genpass.sh base64 [length]        Base64 string (default: 32)"
    echo "  genpass.sh uuid                   UUID v4"
    echo "  genpass.sh token [prefix]         API-style token"
    echo "  genpass.sh passphrase [words]     Word-based passphrase"
    echo ""
    echo "Batch generation:"
    echo "  genpass.sh batch <type> <count> [length]"
    echo ""
    echo "Vault operations:"
    echo "  genpass.sh save <name>            Save last generated"
    echo "  genpass.sh vault                  List saved secrets"
    echo "  genpass.sh get <name>             Retrieve secret"
    echo "  genpass.sh delete <name>          Delete from vault"
    echo ""
    echo "Analysis:"
    echo "  genpass.sh strength [password]    Analyze password strength"
    echo ""
    echo "Examples:"
    echo "  genpass.sh 24                     24-char password"
    echo "  genpass.sh pin 8                  8-digit PIN"
    echo "  genpass.sh passphrase 5           5-word passphrase"
    echo "  genpass.sh batch password 10 20   10 passwords of 20 chars"
    echo "  genpass.sh token sk               Token with 'sk' prefix"
    echo "  genpass.sh save my-api-key        Save to vault"
}

# Main command handling
case "$1" in
    pin)
        result=$(generate_pin "${2:-6}")
        output_result "$result" "pin"
        ;;
    alpha)
        result=$(generate_alpha "${2:-16}")
        output_result "$result" "alpha"
        ;;
    alnum|alphanumeric)
        result=$(generate_alnum "${2:-16}")
        output_result "$result" "alnum"
        ;;
    hex)
        result=$(generate_hex "${2:-32}")
        output_result "$result" "hex"
        ;;
    base64|b64)
        result=$(generate_base64 "${2:-32}")
        output_result "$result" "base64"
        ;;
    uuid|guid)
        result=$(generate_uuid)
        output_result "$result" "uuid"
        ;;
    token|api)
        result=$(generate_token "$2")
        output_result "$result" "token"
        ;;
    passphrase|phrase|words)
        result=$(generate_passphrase "${2:-4}" "${3:--}")
        output_result "$result" "passphrase"
        ;;
    batch)
        generate_batch "$2" "$3" "$4"
        ;;
    save)
        save_to_vault "$2"
        ;;
    vault|list)
        list_vault
        ;;
    get|retrieve)
        get_from_vault "$2"
        ;;
    delete|remove|rm)
        delete_from_vault "$2"
        ;;
    strength|analyze)
        shift
        analyze_strength "$*"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        # Default: generate 16-char password
        result=$(generate_password 16)
        output_result "$result" "password"
        ;;
    *)
        # Check if it's a number (password length)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            result=$(generate_password "$1")
            output_result "$result" "password"
        else
            echo "Unknown command: $1"
            echo "Run 'genpass.sh help' for usage"
            exit 1
        fi
        ;;
esac
