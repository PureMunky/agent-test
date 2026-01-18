# Daily Kickstart

A morning routine and daily planning tool that helps you start each day with intention and focus. Integrates with other productivity tools in the suite to give you a complete picture of your day.

## Features

- **Full Morning Routine**: Guided process including breathing exercise, yesterday review, today's overview, intention setting, and energy check
- **Quick Mode**: 2-minute version for busy mornings
- **Tool Integration**: Pulls data from tasks, deadlines, habits, goals, inbox, pomodoro, and worklog
- **Intention Tracking**: Set and track daily priorities
- **Energy Check**: Log your energy level with task recommendations
- **Session Statistics**: Track your kickstart streak and patterns

## Usage

```bash
# Run the full morning routine
./kickstart.sh

# Quick 2-minute version
./kickstart.sh quick

# Set or view today's intentions
./kickstart.sh intentions
./kickstart.sh intentions "Task 1" "Task 2" "Task 3"

# Review yesterday's progress
./kickstart.sh review

# View history of past sessions
./kickstart.sh history

# View statistics
./kickstart.sh stats

# Help
./kickstart.sh help
```

## Full Routine Includes

1. **Motivational Quote**: Start with inspiration
2. **Breathing Exercise** (optional): 3 rounds of 4-2-4 breathing to center yourself
3. **Yesterday Review**: See what you accomplished and your previous intentions
4. **Today's Overview**:
   - Pending tasks count
   - Deadlines due today and overdue items
   - Active habits and goals
   - Unprocessed inbox items
   - Yesterday's pomodoro count
5. **Intention Setting**: Define your top 3 priorities for the day
6. **Energy Check**: Rate your energy level and get task recommendations

## Energy Level Recommendations

- **High (1)**: Start with your most challenging task
- **Moderate (2)**: Start with a medium task to build momentum
- **Low (3)**: Start with something small and easy

## Integration

Daily Kickstart automatically reads data from:

| Tool | Data Used |
|------|-----------|
| tasks | Pending task count |
| deadlines | Due today and overdue items |
| habits | Active habits count |
| goals | Active goals count |
| inbox | Unprocessed items count |
| pomodoro | Yesterday's session count |
| worklog | Yesterday's accomplishments |

## Data Storage

- `data/kickstarts.json` - Session history (date, time, energy, intentions count)
- `data/intentions.json` - Daily intentions archive

## Requirements

- bash
- jq (JSON processor)

## Tips

- Run `kickstart.sh` first thing in the morning before checking email
- Use `kickstart.sh quick` when you're running late
- Review your intentions throughout the day to stay focused
- Use the energy check recommendation to pick your first task
- Check your stats periodically to maintain your streak
