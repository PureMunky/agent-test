# Deadlines

A command-line deadline and time-sensitive task tracker with priority levels, countdown displays, and snooze functionality.

## Features

- Track deadlines with due dates and priority levels
- Visual countdown showing days remaining
- Color-coded urgency (overdue, today, soon, later)
- Snooze deadlines to postpone due dates
- Filter by upcoming or overdue items
- Summary view for quick status check

## Installation

Requires `jq` for JSON processing:
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Usage

```bash
# Add a deadline
./deadlines.sh add "Submit quarterly report" 2026-01-25
./deadlines.sh add "Project milestone" 2026-02-01 high

# List all deadlines
./deadlines.sh list
./deadlines.sh list --all    # Include completed

# View upcoming deadlines
./deadlines.sh upcoming      # Next 7 days (default)
./deadlines.sh upcoming 14   # Next 14 days

# View overdue items
./deadlines.sh overdue

# Mark as complete
./deadlines.sh done 1

# Snooze a deadline
./deadlines.sh snooze 2      # Snooze by 1 day
./deadlines.sh snooze 2 7    # Snooze by 7 days

# Remove a deadline
./deadlines.sh remove 3

# Quick summary
./deadlines.sh summary

# Show help
./deadlines.sh help
```

## Priority Levels

- `high` - Critical deadlines (displayed in red)
- `medium` - Standard deadlines (default, displayed in yellow)
- `low` - Less urgent items (displayed in green)

## Visual Indicators

The tool uses color-coded countdown displays:
- **OVERDUE** (red, bold) - Past due date
- **DUE TODAY** (red, bold) - Due today
- **DUE TOMORROW** (yellow, bold) - Due tomorrow
- **X days left** (yellow) - 2-3 days remaining
- **X days left** (cyan) - 4-7 days remaining
- **X days left** (green) - More than 7 days

## Data Storage

Deadlines are stored in `data/deadlines.json` within the tool directory.

## Examples

```bash
# Track a project deadline
./deadlines.sh add "Complete MVP" 2026-02-15 high

# Track a personal reminder
./deadlines.sh add "Renew subscription" 2026-01-31 low

# Check what's coming up this week
./deadlines.sh upcoming 7

# Snooze something you can't do today
./deadlines.sh snooze 5 3  # Deadline #5 postponed by 3 days
```

## Integration with Other Tools

The deadlines tool complements the tasks tool in the productivity suite:
- Use **tasks** for general to-do items without specific due dates
- Use **deadlines** for time-sensitive items that must be completed by a certain date
