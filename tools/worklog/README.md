# Work Log

A daily work journal for tracking accomplishments, blockers, and goals. Perfect for preparing daily standups, tracking your progress over time, and documenting wins for performance reviews.

## Features

- **Work Entries**: Log what you're working on throughout the day
- **Accomplishments**: Track wins and completed work
- **Blockers**: Document issues blocking your progress with resolution tracking
- **Goals**: Set goals for tomorrow or upcoming work
- **Standup Format**: Auto-generate daily standup summaries
- **Search**: Find past entries by keyword
- **Export**: Export logs to markdown for sharing

## Installation

Requires `jq` for JSON processing:
```bash
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

## Usage

### Logging Work

```bash
# Log a work entry
./worklog.sh add "Reviewed PR #123"
./worklog.sh add "Working on user authentication"

# Log an accomplishment
./worklog.sh done "Deployed v2.0 to production"
./worklog.sh done "Fixed critical login bug"

# Log a blocker
./worklog.sh blocker "Waiting on API access from team X"
./worklog.sh blocker "Build failing on CI"

# Resolve a blocker
./worklog.sh resolve 1

# Set a goal
./worklog.sh goal "Finish code review for feature Y"
./worklog.sh goal "Write tests for new module"
```

### Viewing Logs

```bash
# Show today's log
./worklog.sh today

# Generate standup format (yesterday/today/blockers)
./worklog.sh standup

# Show this week's summary
./worklog.sh week

# Review last n days (default: 7)
./worklog.sh review
./worklog.sh review 14
```

### Searching and Exporting

```bash
# Search all entries
./worklog.sh search "deployment"
./worklog.sh search "bug"

# Export to markdown
./worklog.sh export md 7      # Last 7 days
./worklog.sh export markdown  # Default 7 days
```

## Command Aliases

Many commands have shorter aliases:

| Command | Aliases |
|---------|---------|
| `add` | `log` |
| `done` | `accomplished`, `win` |
| `blocker` | `blocked`, `block` |
| `resolve` | `unblock` |
| `goal` | `plan`, `tomorrow` |
| `today` | `show` |
| `standup` | `stand`, `daily` |
| `week` | `weekly` |
| `review` | `history` |
| `search` | `find` |

## Data Storage

Logs are stored in `data/logs/` as JSON files, one per day:

```
data/logs/
  2026-01-18.json
  2026-01-17.json
  ...
```

Each file contains:
```json
{
    "date": "2026-01-18",
    "entries": [
        {"text": "Work entry", "time": "09:30"}
    ],
    "accomplishments": [
        {"text": "Completed feature", "time": "14:00"}
    ],
    "blockers": [
        {"text": "Issue description", "time": "11:00", "resolved": false}
    ],
    "goals": [
        {"text": "Goal for tomorrow", "completed": false}
    ]
}
```

## Tips

1. **Start your day** by running `worklog.sh standup` to see yesterday's work and today's goals
2. **Log as you work** - quick entries help you remember what you did
3. **End your day** by setting goals for tomorrow with `worklog.sh goal`
4. **Weekly review** - use `worklog.sh week` to see your accomplishments
5. **Export for 1:1s** - use `worklog.sh export md 14` before manager meetings

## Examples

### Typical Day

```bash
# Morning - check standup
./worklog.sh standup

# Throughout the day
./worklog.sh add "Starting work on feature #42"
./worklog.sh blocker "Need design review before proceeding"
./worklog.sh add "Pair programming with Alex on auth"
./worklog.sh done "Merged PR for user settings"

# End of day
./worklog.sh goal "Complete feature #42"
./worklog.sh goal "Write unit tests"
```

### Standup Output

```
=== Daily Standup ===

Yesterday:
  • Merged PR for user settings
  • Pair programming with Alex on auth

Today:
  • Complete feature #42
  • Write unit tests

Blockers:
  • Need design review before proceeding
```
