# GenPass - Secure Password & Secret Generator

A command-line tool for generating secure passwords, PINs, tokens, UUIDs, and passphrases with built-in vault storage.

## Features

- Generate secure passwords with customizable length
- Multiple generation types (PIN, alphanumeric, hex, base64, UUID, tokens, passphrases)
- Batch generation for creating multiple secrets at once
- Built-in vault for saving and retrieving generated secrets
- Password strength analysis
- Clipboard integration (xclip, pbcopy, wl-copy)
- Cryptographically secure random generation via /dev/urandom

## Installation

The tool is ready to use. Make sure it's executable:

```bash
chmod +x genpass.sh
```

## Usage

### Basic Password Generation

```bash
# Generate a 16-character password (default)
./genpass.sh

# Generate a password of specific length
./genpass.sh 24

# Generate a 32-character password
./genpass.sh 32
```

### Specialized Generators

```bash
# Generate a numeric PIN (default 6 digits)
./genpass.sh pin
./genpass.sh pin 8

# Generate letters only
./genpass.sh alpha 20

# Generate alphanumeric (no special chars)
./genpass.sh alnum 16

# Generate hexadecimal string
./genpass.sh hex 64

# Generate base64 string
./genpass.sh base64 44

# Generate UUID v4
./genpass.sh uuid

# Generate API-style token
./genpass.sh token
./genpass.sh token sk     # With prefix: sk_xxxxxxxx...

# Generate word-based passphrase
./genpass.sh passphrase        # 4 words default
./genpass.sh passphrase 6      # 6 words
```

### Batch Generation

Generate multiple secrets at once:

```bash
# Generate 5 passwords (default)
./genpass.sh batch password 5

# Generate 10 passwords of 24 characters
./genpass.sh batch password 10 24

# Generate 5 UUIDs
./genpass.sh batch uuid 5

# Generate 10 PINs of 6 digits
./genpass.sh batch pin 10 6
```

### Vault Operations

Save and retrieve generated secrets:

```bash
# Generate and save to vault
./genpass.sh 24
./genpass.sh save my-api-key

# List all saved secrets
./genpass.sh vault

# Retrieve a secret
./genpass.sh get my-api-key

# Delete a secret
./genpass.sh delete my-api-key
```

### Password Strength Analysis

```bash
# Analyze the last generated password
./genpass.sh strength

# Analyze a specific password
./genpass.sh strength "MyP@ssw0rd123"
```

## Output Examples

```
# Password
Kx9$mNp2+Qw#fL7s

# PIN
847291

# UUID
550e8400-e29b-41d4-a716-446655440000

# Token
sk_aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2u

# Passphrase
Falcon-thunder-Crystal-voyage-42
```

## Security Notes

- Uses `/dev/urandom` for cryptographically secure random generation
- Passwords >= 8 characters include at least one character from each type
- Vault stores secrets in plaintext - use for convenience, not high-security storage
- Generated values are optionally copied to clipboard for convenience

## Dependencies

- **Required**: bash, standard Unix utilities
- **Optional**: jq (for vault operations), xclip/pbcopy/wl-copy (clipboard), bc (entropy calculation)
