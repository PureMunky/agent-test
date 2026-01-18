# Daily Summary

A productivity dashboard that aggregates data from all tools in the suite to give you a comprehensive view of your daily and weekly productivity.

## Features

- **Daily Dashboard**: See all your productivity metrics in one place
- **Progress Bars**: Visual goal tracking with progress indicators
- **Weekly Overview**: 7-day summary with daily breakdown
- **Date Range Reports**: Analyze productivity over any time period
- **Customizable Goals**: Set personal targets for daily achievements
- **Daily Score**: Get a star rating based on goals achieved

## Installation

The tool is ready to use. Make sure the script is executable:

```bash
chmod +x daily-summary.sh
```

Requires `jq` for JSON processing:
```bash
sudo apt install jq
```

## Usage

```bash
# Show today's productivity summary
./daily-summary.sh

# Show yesterday's summary
./daily-summary.sh yesterday

# Show this week's summary
./daily-summary.sh week

# Show summary for a specific date
./daily-summary.sh date 2026-01-15

# Show summary for a date range
./daily-summary.sh range 2026-01-01 2026-01-15

# View current goals
./daily-summary.sh goals

# Set new goals
./daily-summary.sh goals set 10 8 6 90
```

## Data Sources

The daily summary aggregates data from:

| Tool | Metrics |
|------|---------|
| Pomodoro | Sessions completed |
| Time Log | Hours tracked, projects worked on |
| Tasks | Tasks completed and added |
| Habits | Daily habit completion rate |
| Quick Notes | Notes captured |
| Bookmarks | URLs saved |

## Goal Tracking

Set daily goals for key metrics:

- **Pomodoros**: Target number of focus sessions per day
- **Hours**: Target hours of tracked work time
- **Tasks**: Target number of tasks to complete
- **Habits %**: Target percentage of habits to complete

The daily score shows how many of your 4 goals you've achieved.

## Examples

### Daily Summary Output

```
╔════════════════════════════════════════════════════════════╗
║          DAILY PRODUCTIVITY SUMMARY                        ║
║          Saturday, January 18, 2026
╚════════════════════════════════════════════════════════════╝

🍅 POMODORO SESSIONS
   Completed: 6 / 8  [████████████░░░░░░░░]

⏱️  TIME TRACKED
   Logged: 4h 30m / 6h  [███████████████░░░░░]
   Projects:
     coding               2h 15m
     meetings             1h 30m
     planning             45m

✓ TASKS
   Completed: 4 / 5  [████████████████░░░░]
   Added: 2

📊 HABITS
   Completed: 3 / 4 (75%)  [███████████████░░░░░]

📝 NOTES & BOOKMARKS
   Notes captured: 5
   Bookmarks added: 1

────────────────────────────────────────────────────────────

   DAILY SCORE: ★ ★ ★ ☆ (3/4 goals)
   Great job! Almost perfect!
```

### Weekly Summary

```
╔════════════════════════════════════════════════════════════╗
║            WEEKLY PRODUCTIVITY SUMMARY                     ║
╚════════════════════════════════════════════════════════════╝

  Date         Pomodoro       Time    Tasks   Habits
  ─────────────────────────────────────────────────────
  Sun 01-12         4       2h 15m        3      2/3
  Mon 01-13         8       6h 30m        5      3/3
  Tue 01-14         6       5h 00m        4      3/3
  Wed 01-15         7       5h 45m        6      2/3
  Thu 01-16         5       4h 00m        3      3/3
  Fri 01-17         9       7h 15m        7      3/3
  Sat 01-18         6       4h 30m        4      3/4
  ─────────────────────────────────────────────────────
  TOTAL            45      35h 15m       32      85%

Weekly Averages:
   Pomodoros/day: 6
   Time/day: 5h 2m
   Tasks/day: 4
```

## Tips

1. Run `daily-summary.sh` at the end of each day to review your productivity
2. Use `daily-summary.sh week` for weekly retrospectives
3. Adjust your goals based on what's realistic for your schedule
4. The star rating helps gamify your productivity - aim for 4 stars!
