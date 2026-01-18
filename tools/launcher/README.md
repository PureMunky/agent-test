# Launcher

Quick command palette for the productivity suite. Find, search, and run any tool from a single interface.

## Features

- **List all tools** - Browse the complete suite organized by category
- **Search** - Find tools by name, description, or category
- **Quick run** - Execute any tool directly with arguments
- **Aliases** - Create shortcuts for frequently used commands
- **Favorites** - Mark your most-used tools for quick access
- **History** - Track and re-run recent commands
- **Interactive mode** - Quick access menu with favorites and recent commands

## Usage

```bash
# Interactive mode - shows favorites, recent commands, and menu
./launcher.sh

# List all available tools
./launcher.sh list

# Search for tools
./launcher.sh search "time"
./launcher.sh search "notes"

# Run a tool directly
./launcher.sh run pomodoro start
./launcher.sh run tasks add "New task"
./launcher.sh run timelog status

# Get info about a tool
./launcher.sh info pomodoro
```

## Aliases

Create shortcuts for frequently used commands:

```bash
# Create an alias
./launcher.sh alias pt "pomodoro start"
./launcher.sh alias note "quicknotes add"
./launcher.sh alias td "tasks done"

# Use the alias
./launcher.sh run pt
./launcher.sh run note "Remember this"

# List aliases
./launcher.sh aliases

# Remove an alias
./launcher.sh unalias pt
```

## Favorites

Mark tools as favorites for quick access in interactive mode:

```bash
# Toggle a tool as favorite
./launcher.sh fav pomodoro
./launcher.sh fav tasks
./launcher.sh fav quicknotes

# Show all favorites
./launcher.sh favorites
```

## History

View and re-run recent commands:

```bash
# Show last 10 commands
./launcher.sh recent

# Show last 20 commands
./launcher.sh recent 20
```

## Interactive Mode

Running `./launcher.sh` without arguments opens interactive mode which shows:

1. Your favorite tools (starred)
2. Recent commands
3. Quick command menu

Type a tool name to run it, or use commands like `list`, `search`, or `quit`.

## Examples

```bash
# Quick workflow
./launcher.sh fav pomodoro            # Mark pomodoro as favorite
./launcher.sh fav tasks               # Mark tasks as favorite
./launcher.sh alias start-day "daily-summary show"  # Create morning alias
./launcher.sh                         # Open interactive mode

# Search and run
./launcher.sh search focus            # Find focus-related tools
./launcher.sh run focus-mode start    # Start focus mode

# Direct execution (shorthand)
./launcher.sh pomodoro status         # Runs: launcher.sh run pomodoro status
```

## Data Storage

Data is stored in the `data/` subdirectory:
- `aliases.json` - Custom command aliases
- `favorites.json` - Favorite tools list
- `history.json` - Command history (last 50 entries)
