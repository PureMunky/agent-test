# Pomodoro Timer

An enhanced command-line Pomodoro timer for focused work sessions with project tracking, statistics, and customizable settings.

## Usage

```bash
# Start a pomodoro for a specific project
./pomodoro.sh start coding

# Start with custom durations
./pomodoro.sh start "project-x" --work 50 --break 10

# View today's sessions
./pomodoro.sh status

# Show statistics for the last 30 days
./pomodoro.sh stats 30

# View history
./pomodoro.sh history 7

# List all projects with time spent
./pomodoro.sh projects

# Pause and resume
./pomodoro.sh pause
./pomodoro.sh resume

# Stop/cancel current session
./pomodoro.sh stop

# Take a long break
./pomodoro.sh long-break

# View/modify configuration
./pomodoro.sh config
./pomodoro.sh config work_minutes 30
```

## Features

- **Project tracking**: Associate each pomodoro with a project for better time insights
- **Pause/Resume**: Interrupt your timer and continue later
- **Statistics**: View daily, weekly, and per-project statistics with visual breakdowns
- **Configurable**: Customize work duration, break length, and auto-start behavior
- **Long break reminders**: Automatic prompts for long breaks after 4 sessions
- **Desktop notifications**: Optional notify-send integration
- **Session history**: Track all completed pomodoros with timestamps
- **Backwards compatible**: Old command style (`pomodoro.sh 25 5`) still works

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `work_minutes` | 25 | Default work session duration |
| `short_break` | 5 | Short break duration |
| `long_break` | 15 | Long break duration |
| `sessions_until_long_break` | 4 | Sessions before suggesting long break |
| `auto_start_break` | false | Automatically start breaks without prompting |
| `sound_enabled` | true | Play terminal bell on completion |
| `desktop_notification` | true | Show desktop notifications (requires notify-send) |

## Commands

| Command | Description |
|---------|-------------|
| `start [project] [options]` | Start a new pomodoro session |
| `stop` | Stop/cancel current session |
| `pause` | Pause the running timer |
| `resume` | Resume a paused timer |
| `status` | Show today's completed pomodoros |
| `history [days]` | Show session history (default: 7 days) |
| `stats [days]` | Show detailed statistics (default: 7 days) |
| `projects` | List all projects with total time |
| `config [key] [value]` | View or modify settings |
| `long-break` | Start a long break timer |
| `help` | Show help message |

## Examples

```bash
# Daily workflow
./pomodoro.sh start coding           # Start working on code
# ... 25 minutes later, break prompt appears
./pomodoro.sh start writing          # Work on documentation
./pomodoro.sh stats                  # See today's progress

# Check what you've worked on
./pomodoro.sh projects               # See time by project

# Customize for longer focus sessions
./pomodoro.sh config work_minutes 45
./pomodoro.sh config auto_start_break true
```

## Data Storage

- Session logs: `data/pomodoro_log.csv`
- Configuration: `data/config.json`
- Active session state: `data/active.json`

## Integration

The pomodoro tool can be used alongside other suite tools:
- Use with `timelog` for detailed time tracking
- Use with `tasks` to track which tasks you're working on
- Check `daily-summary` to see pomodoro data aggregated with other metrics
