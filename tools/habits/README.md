# Habits - Enhanced Daily Habit Tracker

A powerful command-line tool for tracking daily habits with streaks, statistics, notes, weekly targets, and data portability.

## Features

- Track multiple daily habits with visual grid display
- **NEW: Weekly targets** - Set habits for N times per week (not just daily)
- **NEW: Check-in notes** - Add context when marking habits complete
- **NEW: Statistics** - Completion rates, best days, weekly progress
- **NEW: Export/Import** - Backup and restore your habit data
- Streak tracking with current and longest streak display
- Automatic migration from v1 data format
- Mark habits for past dates (backfill)
- Rename and remove habits while preserving history

## Installation

Requires `jq` for JSON processing:
```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Add a new habit
```bash
# Daily habit
./habits.sh add "exercise"
./habits.sh add "read 30 minutes"

# Weekly target (e.g., 5 times per week)
./habits.sh add "deep work" --weekly 5
./habits.sh add "gym" -w 3
```

### Mark habits as done
```bash
# Mark for today
./habits.sh check "exercise"

# Mark with a note
./habits.sh check "exercise" --note "30 min morning run"

# Mark for a specific date with note
./habits.sh check "exercise" 2026-01-15 --note "Gym workout"
```

### Unmark a habit
```bash
./habits.sh uncheck "exercise"
./habits.sh uncheck "exercise" 2026-01-15
```

### View today's habits
```bash
./habits.sh list
```
Output:
```
=== Today's Habits (2026-01-19) ===

  [✓] exercise (5 day streak)
  [ ] read 30 minutes (0 day streak)
  [✓] deep work (3 day streak) [3/5 this week]

Progress: 2/3 completed
```

### View habit grid
```bash
# Last 7 days (default)
./habits.sh status

# Last 14 days
./habits.sh status 14
```
Output:
```
=== Habit Tracker (Last 7 days) ===

                     13 14 15 16 17 18 19
                     Mo Tu We Th Fr Sa Su

exercise              ●  ●  ●  ●  ●  ○  ●  5
read 30 minutes       ○  ●  ●  ○  ○  ○  ○  0
deep work             ●  ●  ●  ○  ●  ○  ●  3

● = done, ○ = missed, number = current streak
```

### View statistics
```bash
# All habits
./habits.sh stats

# Specific habit
./habits.sh stats exercise
```
Output:
```
=== Habit Statistics ===

exercise

  Total completions:  42
  Current streak:     5 days
  Longest streak:     21 days
  Last 30 days:       24/30 (80%)
  Best day:           Mon (8 completions)
  Notes:              12

deep work

  Total completions:  15
  Current streak:     3 days
  Longest streak:     7 days
  Last 30 days:       12/30 (40%)
  Best day:           Tue (4 completions)
  This week:          3/5
```

### View check-in notes
```bash
# Last 10 notes (default)
./habits.sh notes "exercise"

# Last 5 notes
./habits.sh notes "exercise" 5
```
Output:
```
=== Notes: exercise ===

  2026-01-19 - 30 min morning run
  2026-01-18 - Rest day, light stretching
  2026-01-17 - Gym: leg day
  2026-01-16 - 5K run in the park
```

### View streak details
```bash
./habits.sh streak "exercise"
```
Output:
```
=== Streak: exercise ===

Current streak: 5 days
Total completions: 42
Longest streak: 21 days
```

### Edit habit settings
```bash
./habits.sh edit "deep work"
```
Allows you to change the weekly target for a habit.

### Manage habits
```bash
# Rename a habit
./habits.sh rename "exercise" "morning workout"

# Remove a habit
./habits.sh remove "old habit"
```

### Export/Import data
```bash
# Export to file
./habits.sh export my_habits.json

# Import from file (merges with existing)
./habits.sh import my_habits.json
```

## Commands

| Command | Description |
|---------|-------------|
| `add "habit" [--weekly N]` | Add a new habit (optional weekly target) |
| `check "habit" [date] [--note "text"]` | Mark habit done with optional note |
| `uncheck "habit" [date]` | Unmark habit for a date |
| `list` | Show all habits with today's status |
| `status [days]` | Show visual grid (default: 7 days) |
| `streak "habit"` | Show streak details for a habit |
| `stats [habit]` | Show statistics (all or specific) |
| `notes "habit" [N]` | Show last N notes for a habit |
| `remove "habit"` | Remove a habit and its history |
| `rename "old" "new"` | Rename a habit |
| `edit "habit"` | Edit habit settings |
| `export [file]` | Export data to JSON |
| `import <file>` | Import/merge data from JSON |
| `help` | Show help message |

## Data Storage

Habit data is stored in `data/habits.json` in the tool directory. The v2 format includes:
- List of tracked habits with settings
- Completion dates for each habit
- Notes attached to check-ins
- User settings

The tool automatically migrates v1 data to v2 format.

## Tips

- **Weekly targets**: Use `--weekly` for habits you don't need to do daily (e.g., gym 3x/week)
- **Add notes**: Notes help you remember context and track progress details
- **Review stats**: Use `habits.sh stats` to identify patterns and optimize
- **Build momentum**: Start with 1-2 habits and add more once established
- **Don't break the chain**: The streak counter helps maintain motivation
- **Be specific**: "Read for 30 minutes" is better than just "Read"
- **Backup regularly**: Use `habits.sh export` before major changes

## Version History

- **v2.0.0** - Added weekly targets, check-in notes, statistics, export/import
- **v1.0.0** - Initial release with basic habit tracking and streaks
