# Clipboard History Manager

A command-line tool for managing clipboard history. Capture, search, and retrieve past clipboard contents with tagging and export support.

## Features

- Save clipboard contents to searchable history
- Tag entries for easy categorization
- Search through clipboard history by keyword or tag
- Retrieve past clipboard entries back to the clipboard
- Export history to text files
- Cross-platform clipboard support (X11, Wayland, macOS)
- Configurable history size

## Requirements

One of the following clipboard utilities:
- `xclip` (X11)
- `xsel` (X11)
- `wl-clipboard` (Wayland)
- `pbcopy/pbpaste` (macOS)

## Installation

```bash
# Make the script executable
chmod +x clipboard.sh

# Optional: Create a symlink for easy access
ln -s /path/to/clipboard.sh ~/.local/bin/clipboard
```

## Usage

```bash
# Save current clipboard to history
clipboard save
clipboard save work          # Save with 'work' tag

# Add text directly to history
clipboard add "some text"
clipboard add -t important "text with tag"
echo "piped data" | clipboard add

# List recent entries
clipboard list              # Show last 10 entries
clipboard list 25           # Show last 25 entries

# Retrieve an entry
clipboard get 3             # Copy entry #3 to clipboard
clipboard show 3            # Display full content of entry #3

# Search history
clipboard search password
clipboard search "api key"

# Manage history
clipboard delete 5          # Delete entry #5
clipboard clear             # Clear all history
clipboard export            # Export to clipboard_export_*.txt
clipboard export backup.txt # Export to specific file

# View statistics
clipboard stats
```

## Commands

| Command | Description |
|---------|-------------|
| `save [tag]` | Save current clipboard contents to history |
| `capture [tag]` | Alias for save |
| `add [-t tag] <text>` | Add text directly to history |
| `list [n]` | List last n entries (default: 10) |
| `get <n>` | Copy entry #n back to clipboard |
| `show <n>` | Display full content of entry #n |
| `search <term>` | Search history by keyword or tag |
| `delete <n>` | Delete entry #n from history |
| `clear` | Clear all clipboard history |
| `export [file]` | Export history to a text file |
| `stats` | Show history statistics |

## Configuration

Environment variables for customization:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLIPBOARD_DATA_DIR` | `~/.local/share/clipboard-history` | Data storage directory |
| `CLIPBOARD_MAX_ENTRIES` | `100` | Maximum entries to keep |

Example:
```bash
# Keep 500 entries
export CLIPBOARD_MAX_ENTRIES=500

# Use custom storage location
export CLIPBOARD_DATA_DIR="$HOME/clipboard-data"
```

## Data Storage

History is stored in `~/.local/share/clipboard-history/history.txt` using base64 encoding to safely handle multi-line content and special characters.

Each entry contains:
- Unique ID
- Timestamp
- Optional tag
- Base64-encoded content

## Examples

### Workflow: Saving Important Snippets

```bash
# Copy some code, then save with tag
clipboard save code

# Later, find it
clipboard search code
clipboard get 3
```

### Workflow: Quick Text Collection

```bash
# Collect multiple items
clipboard save
# ... copy something else ...
clipboard save
# ... copy another thing ...
clipboard save

# Review what you collected
clipboard list
```

### Workflow: Export Before Clearing

```bash
# Export everything before cleanup
clipboard export my_clipboard_backup.txt
clipboard clear
```

## Tips

1. **Automatic Capture**: Set up a keyboard shortcut to run `clipboard save` after copying
2. **Tagged Workflow**: Use consistent tags like `work`, `personal`, `code` for easy searching
3. **Pipe Support**: Use with other commands: `cat file.txt | clipboard add -t backup`
4. **Quick Access**: Use `clipboard get 1` to restore the most recently saved item
