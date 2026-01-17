# Tasks

A simple command-line task tracker.

## Requirements

- `jq` - JSON processor (install with `sudo apt install jq`)

## Usage

```bash
# Add a task
./tasks.sh add "Review pull request"
./tasks.sh add "Fix login bug"

# List all tasks
./tasks.sh list

# Mark a task as complete
./tasks.sh done 1

# Remove a task
./tasks.sh remove 2

# Clear all completed tasks
./tasks.sh clear
```

## Features

- Simple ID-based task management
- Separate pending/completed views
- Timestamps for creation and completion
- JSON storage for easy parsing

## Data

Tasks are stored in `data/tasks.json`.
