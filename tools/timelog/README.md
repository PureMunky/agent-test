# Time Log

A command-line time tracking tool for logging time spent on projects and activities.

## Features

- Start/stop timers for active work sessions
- Manual time logging for meetings, calls, etc.
- Reports by project and by day
- CSV-based storage for easy export
- Tracks multiple projects

## Usage

### Start a Timer

```bash
./timelog.sh start "project-name" ["optional description"]

# Examples:
./timelog.sh start "coding"
./timelog.sh start "client-work" "Working on API integration"
```

### Stop the Timer

```bash
./timelog.sh stop
```

### Check Current Timer

```bash
./timelog.sh status
```

### Log Time Manually

For meetings or activities you didn't time:

```bash
./timelog.sh log "project" <minutes> ["description"]

# Examples:
./timelog.sh log "meeting" 30 "Team standup"
./timelog.sh log "review" 45 "Code review for PR #123"
```

### View Reports

```bash
# Today's time
./timelog.sh today

# Last 7 days (default)
./timelog.sh report

# Last 30 days
./timelog.sh report 30
```

### List Projects

```bash
./timelog.sh projects
```

## Data Storage

Time entries are stored in `data/timelog.csv` with the following columns:
- date
- project
- minutes
- description
- start_time
- end_time

The CSV format makes it easy to export to spreadsheets or other tools.

## Shortcuts

| Command | Shortcut |
|---------|----------|
| `status` | `st` |
| `report` | `rep` |
| `today` | `td` |
| `projects` | `proj` |
| `log` | `add` |

## Tips

- Use consistent project names for accurate reporting
- Log meetings and calls manually after they happen
- Run `./timelog.sh` with no arguments to see today's summary
- The timer rounds to the nearest minute (minimum 1 minute)
