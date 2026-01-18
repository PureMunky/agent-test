# Reminders

A quick reminder and alarm tool for personal productivity. Set time-based reminders with natural language syntax, including support for recurring reminders.

## Features

- **Flexible Time Parsing**: Set reminders using relative time (in 30m), absolute time (at 14:30), or dates (at 2026-01-20)
- **Recurring Reminders**: Create daily, weekly, or day-specific recurring reminders
- **Desktop Notifications**: Integrates with `notify-send` for desktop alerts
- **Snooze Support**: Postpone reminders with customizable snooze durations
- **Completion Tracking**: Track completed reminders with history

## Requirements

- `jq` - JSON processor (install with `sudo apt install jq`)
- `notify-send` (optional) - For desktop notifications

## Usage

### Adding Reminders

```bash
# Remind in relative time
./reminders.sh add "Take a break" in 30m
./reminders.sh add "Check email" in 2h
./reminders.sh add "Weekly review" in 1d

# Remind at specific time (today or tomorrow if past)
./reminders.sh add "Team meeting" at 14:30
./reminders.sh add "Lunch" at 12:00

# Remind on specific date
./reminders.sh add "Project deadline" at 2026-01-25
./reminders.sh add "Appointment" at 2026-02-15 09:30

# Remind tomorrow
./reminders.sh add "Morning standup" tomorrow
./reminders.sh add "Gym" tomorrow at 07:00

# Recurring reminders
./reminders.sh add "Daily standup" daily at 09:00
./reminders.sh add "Weekly report" weekly at 17:00
```

### Managing Reminders

```bash
# List all pending reminders
./reminders.sh list

# Check for due reminders (triggers notifications)
./reminders.sh check

# Mark reminder as done
./reminders.sh done 1

# Delete a reminder
./reminders.sh delete 1

# Snooze a reminder (default: 10 minutes)
./reminders.sh snooze 1
./reminders.sh snooze 1 30m
./reminders.sh snooze 1 1h
```

### History

```bash
# Show recently completed reminders
./reminders.sh completed
./reminders.sh completed 20    # Show last 20

# Clear completed history
./reminders.sh clear
```

## Time Format Reference

| Format | Example | Description |
|--------|---------|-------------|
| `in Xm` | `in 30m` | X minutes from now |
| `in Xh` | `in 2h` | X hours from now |
| `in Xd` | `in 1d` | X days from now |
| `at HH:MM` | `at 14:30` | Today at specified time (or tomorrow if past) |
| `at YYYY-MM-DD` | `at 2026-01-25` | Specific date at 9:00 AM |
| `at YYYY-MM-DD HH:MM` | `at 2026-01-25 14:00` | Specific date and time |
| `tomorrow` | `tomorrow` | Tomorrow at 9:00 AM |
| `tomorrow at HH:MM` | `tomorrow at 08:00` | Tomorrow at specified time |
| `daily at HH:MM` | `daily at 09:00` | Every day at specified time |
| `weekly at HH:MM` | `weekly at 17:00` | Every week at specified time |

## Automation

For automatic checking, add to crontab:

```bash
# Check every 5 minutes
*/5 * * * * /path/to/reminders.sh check
```

## Data Storage

Reminders are stored in `data/reminders.json` within the tool directory.

## Command Aliases

Several commands have aliases for convenience:

| Command | Aliases |
|---------|---------|
| `add` | `new`, `set` |
| `list` | `ls`, `show` |
| `check` | `due` |
| `done` | `complete`, `finish` |
| `delete` | `del`, `rm`, `remove` |
| `snooze` | `postpone`, `defer` |
| `completed` | `history` |
