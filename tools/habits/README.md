# Habits - Daily Habit Tracker

A simple command-line tool for tracking daily habits and building streaks.

## Features

- Track multiple daily habits
- Visual grid display showing completion history
- Streak tracking to maintain motivation
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
./habits.sh add "exercise"
./habits.sh add "read 30 minutes"
./habits.sh add "meditate"
```

### Mark habits as done
```bash
# Mark for today
./habits.sh check "exercise"

# Mark for a specific date
./habits.sh check "exercise" 2026-01-15
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
=== Today's Habits (2026-01-17) ===

  [✓] exercise (5 day streak)
  [ ] read 30 minutes (0 day streak)
  [✓] meditate (12 day streak)

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

                     11 12 13 14 15 16 17
                     Sa Su Mo Tu We Th Fr

exercise              ●  ●  ●  ●  ●  ○  ●  5
read 30 minutes       ○  ●  ●  ○  ○  ○  ○  0
meditate              ●  ●  ●  ●  ●  ●  ●  7

● = done, ○ = missed, number = current streak
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

### Manage habits
```bash
# Rename a habit
./habits.sh rename "exercise" "morning workout"

# Remove a habit
./habits.sh remove "old habit"
```

## Commands

| Command | Description |
|---------|-------------|
| `add "habit"` | Add a new habit to track |
| `check "habit" [date]` | Mark habit done (default: today) |
| `uncheck "habit" [date]` | Unmark habit for a date |
| `list` | Show all habits with today's status |
| `status [days]` | Show visual grid (default: 7 days) |
| `streak "habit"` | Show streak details for a habit |
| `remove "habit"` | Remove a habit and its history |
| `rename "old" "new"` | Rename a habit |
| `help` | Show help message |

## Data Storage

Habit data is stored in `data/habits.json` in the tool directory. The file contains:
- List of tracked habits
- Completion dates for each habit

## Tips

- **Build momentum**: Start with 1-2 habits and add more once those are established
- **Don't break the chain**: The streak counter helps maintain motivation
- **Be specific**: "Read for 30 minutes" is better than just "Read"
- **Review weekly**: Use `habits.sh status 7` to see your weekly patterns
