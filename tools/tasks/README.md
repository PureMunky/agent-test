# Tasks

A simple command-line task tracker with priority levels and due dates.

## Requirements

- `jq` - JSON processor (install with `sudo apt install jq`)

## Usage

```bash
# Add a task (simple)
./tasks.sh add "Review pull request"

# Add a task with priority and due date
./tasks.sh add "Fix critical bug" -p high -d 2026-01-20
./tasks.sh add "Update documentation" -p low

# List all tasks
./tasks.sh list

# List with filters
./tasks.sh list --overdue     # Show overdue tasks
./tasks.sh list --today       # Show tasks due today
./tasks.sh list --priority    # Sort by priority
./tasks.sh list --high        # Show high priority only

# Mark a task as complete
./tasks.sh done 1

# Reopen a completed task
./tasks.sh undone 1

# Edit task description
./tasks.sh edit 1 "New description"

# Set/change priority
./tasks.sh priority 1 high    # Set to high priority
./tasks.sh priority 1 med     # Set to medium priority
./tasks.sh priority 1 low     # Set to low priority

# Set/change due date
./tasks.sh due 1 2026-01-25   # Set due date
./tasks.sh due 1 clear        # Remove due date

# Remove a task
./tasks.sh remove 2

# Clear all completed tasks
./tasks.sh clear
```

## Features

- **Priority levels**: high (!!), medium (!), low (-) with color coding
- **Due dates**: with smart display (OVERDUE, TODAY, Tomorrow, day name)
- **Overdue warnings**: alerts when listing tasks with overdue items
- **Filtering**: view overdue, today's, or high-priority tasks
- **Sorting**: sort tasks by priority
- **Edit tasks**: modify description, priority, or due date after creation
- **Undo completion**: reopen tasks marked as done
- Simple ID-based task management
- Separate pending/completed views
- Timestamps for creation and completion
- JSON storage for easy parsing

## Priority Indicators

- `!!` (red) - High priority
- `!` (yellow) - Medium priority
- `-` (gray) - Low priority

## Due Date Display

- `[OVERDUE: date]` (red) - Past due
- `[TODAY]` (yellow) - Due today
- `[Tomorrow]` (cyan) - Due tomorrow
- `[Mon]` (cyan) - Due within 7 days (shows day name)
- `[2026-01-25]` (gray) - Due later

## Examples

```bash
# Morning workflow - see what's urgent
./tasks.sh list --overdue
./tasks.sh list --today

# Planning - add tasks with context
./tasks.sh add "Deploy to production" -p high -d 2026-01-20
./tasks.sh add "Write tests for new feature" -p med -d 2026-01-22
./tasks.sh add "Refactor old code" -p low

# View by priority
./tasks.sh list --priority
```

## Data

Tasks are stored in `data/tasks.json`.
