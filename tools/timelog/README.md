# Time Log v2.0

A comprehensive command-line time tracking tool for logging time spent on projects and activities, with support for billable hours, pause/resume, and detailed reporting.

## What's New in v2.0

- **Pause/Resume**: Pause timers during interruptions and resume later
- **Billable Hours**: Track billable time with configurable hourly rates
- **Tags**: Categorize entries with inline #tags in descriptions
- **Weekly Summary**: Visual weekly breakdown with progress bar
- **Edit/Delete**: Modify or remove time entries
- **Export**: Export data in JSON or CSV format
- **Filtering**: Find entries by project, tag, or date
- **Statistics**: Overall tracking stats and insights

## Usage

### Basic Timer Operations

```bash
# Start a timer
./timelog.sh start "project-name" ["optional description"]
./timelog.sh start "coding" "Working on API #backend"

# Pause the current timer (for interruptions)
./timelog.sh pause

# Resume a paused timer
./timelog.sh resume

# Stop the timer and log the time
./timelog.sh stop

# Check current timer status
./timelog.sh status
```

### Billable Time Tracking

```bash
# Start a billable timer
./timelog.sh start "consulting" "Client meeting" --billable

# Set hourly rate for a project
./timelog.sh rate "consulting" 150

# Log billable time manually
./timelog.sh log "consulting" 60 "Phone call" --billable

# View billable summary
./timelog.sh billable        # Last 30 days
./timelog.sh billable 90     # Last 90 days

# View all rates
./timelog.sh rates
```

### Manual Time Logging

For meetings or activities you didn't time:

```bash
./timelog.sh log "project" <minutes> ["description"] [--billable]

# Examples:
./timelog.sh log "meeting" 30 "Team standup #meetings"
./timelog.sh log "review" 45 "Code review for PR #123"
./timelog.sh log "client-work" 120 "Design review" --billable
```

### Reports and Summaries

```bash
# Today's time
./timelog.sh today

# Weekly summary with visual breakdown
./timelog.sh week

# Time report (default: 7 days)
./timelog.sh report

# Extended report
./timelog.sh report 30

# Overall statistics
./timelog.sh stats
```

### Managing Entries

```bash
# List all projects
./timelog.sh projects

# View all tags
./timelog.sh tags

# View a specific entry
./timelog.sh edit 5

# Edit an entry
./timelog.sh edit 5 project "new-project"
./timelog.sh edit 5 minutes 45
./timelog.sh edit 5 description "Updated description"
./timelog.sh edit 5 billable true

# Delete an entry
./timelog.sh delete 5
```

### Filtering Entries

```bash
# Filter by project
./timelog.sh filter --project "coding"
./timelog.sh filter -p "coding"

# Filter by tag
./timelog.sh filter --tag "#backend"
./timelog.sh filter -t "#meetings"

# Filter by date
./timelog.sh filter --date 2026-01-19
./timelog.sh filter -d 2026-01-19
```

### Export Data

```bash
# Export to JSON
./timelog.sh export json

# Export to CSV
./timelog.sh export csv
```

## Features

### Pause/Resume

Step away from your desk? Pause your timer:

```bash
./timelog.sh start "coding"
# ... work for a while ...
./timelog.sh pause
# Timer paused, go to lunch
./timelog.sh resume
# Continue working
./timelog.sh stop
```

The timer accumulates time across pause/resume cycles.

### Tags

Add hashtags to your descriptions for easy categorization:

```bash
./timelog.sh start "coding" "Feature X #backend #sprint5"
./timelog.sh log "meeting" 30 "Standup #daily #team"
```

Then view and filter by tags:

```bash
./timelog.sh tags           # List all tags
./timelog.sh filter -t "#backend"
```

### Weekly Summary

Get a visual overview of your week:

```
=== Weekly Summary ===
Week of 2026-01-13

Daily Hours:

  Mon 2026-01-13 ████████ 2h 0m
  Tue 2026-01-14 ████████████ 3h 15m
  Wed 2026-01-15 ██████████████████ 4h 30m
  Thu 2026-01-16 ████████████████ 4h 0m
  Fri 2026-01-17 ████████████ 3h 0m
  Sat 2026-01-18  0m
  Sun 2026-01-19  0m

Week Total: 16h 45m
  (42% of 40h target)

Top Projects This Week:

  coding               8h 30m
  meetings             4h 15m
  review               4h 0m
```

### Billable Tracking

Track client work and calculate earnings:

```bash
# Set up rates
./timelog.sh rate "consulting" 150
./timelog.sh rate "development" 125

# Track billable time
./timelog.sh start "consulting" --billable
./timelog.sh stop

# View billable summary
./timelog.sh billable
```

## Data Storage

Data is stored in `data/` directory:
- `timelog.csv` - Time entries (id, date, project, minutes, description, start_time, end_time, billable)
- `rates.json` - Hourly rates per project
- `config.json` - Configuration settings
- `active.json` - Current timer state (when running)

The CSV format makes it easy to export to spreadsheets or other tools.

## Command Shortcuts

| Command | Shortcut |
|---------|----------|
| `status` | `st` |
| `report` | `rep` |
| `today` | `td` |
| `week` | `wk` |
| `projects` | `proj` |
| `log` | `add` |
| `delete` | `del`, `rm` |
| `billable` | `bill` |

## Tips

- Use consistent project names for accurate reporting
- Add #tags to descriptions for better categorization
- Use `--billable` flag for client work
- Set hourly rates with `timelog.sh rate` for automatic billing calculations
- Use `pause` instead of `stop` if you plan to continue the same task
- Run `./timelog.sh` with no arguments to see today's summary
- Export data regularly for backup or external reporting
- The timer rounds to the nearest minute (minimum 1 minute)

## Migration from v1.0

The v2.0 data format adds two new fields: `id` and `billable`. Existing v1.0 data files will continue to work but won't have entry IDs for existing entries. New entries will automatically get IDs assigned.
