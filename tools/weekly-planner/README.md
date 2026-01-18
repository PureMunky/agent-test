# Weekly Planner

A command-line weekly planning and review tool that helps you set goals, track priorities, celebrate wins, and reflect on your progress.

## Features

- **Weekly Planning**: Set themes, goals, and priorities for each week
- **Progress Tracking**: Automatically aggregates data from other productivity tools
- **Win Recording**: Celebrate your achievements throughout the week
- **Challenge Logging**: Acknowledge blockers and obstacles
- **Weekly Reviews**: Guided reflection prompts for continuous improvement
- **History**: View past weeks' plans and reviews

## Usage

```bash
# View this week's plan
./weekly-planner.sh
./weekly-planner.sh plan

# Set a theme for the week
./weekly-planner.sh theme "Deep Work Week"

# Manage goals
./weekly-planner.sh goals                    # List goals
./weekly-planner.sh goals add "Complete project proposal"
./weekly-planner.sh goals done 1             # Mark goal #1 complete
./weekly-planner.sh goals remove 2           # Remove goal #2

# Manage priorities (max 3)
./weekly-planner.sh priorities               # List priorities
./weekly-planner.sh priorities add "Focus on documentation"
./weekly-planner.sh priorities remove 1

# Record wins and challenges
./weekly-planner.sh wins "Shipped new feature!"
./weekly-planner.sh challenges "API integration blocked by vendor"

# Weekly review (interactive)
./weekly-planner.sh review

# Plan for next week
./weekly-planner.sh next

# View history
./weekly-planner.sh history        # Last 4 weeks
./weekly-planner.sh history 8      # Last 8 weeks
```

## Integration

The weekly planner automatically pulls data from other tools in the suite:
- Pomodoro sessions completed
- Time tracked
- Tasks completed
- Habit completion rates

## Tips for Effective Weekly Planning

1. **Set 3-5 goals per week** - Too many goals leads to scattered focus
2. **Keep priorities to 3 max** - The rule of three helps maintain focus
3. **Record wins daily** - Building momentum through small celebrations
4. **Do reviews consistently** - Friday afternoon or Sunday evening works well
5. **Use themes** - A weekly theme helps guide decision-making

## Data Storage

Weekly plans are stored in `data/week_YYYY-MM-DD.json` where the date is the Monday of each week.

## Requirements

- bash 4.0+
- jq (JSON processor)
- date command with -d flag (GNU coreutils) or -v flag (BSD/macOS)
