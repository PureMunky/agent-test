# Goals - Long-term Goal Tracker

A command-line tool for setting, tracking, and achieving long-term goals with milestones and progress visualization.

## Features

- **Goal Management**: Create goals with optional deadlines
- **Milestone Tracking**: Break goals into smaller, achievable milestones
- **Progress Visualization**: Visual progress bars and completion percentages
- **Deadline Tracking**: Automatic countdown and overdue alerts
- **Notes**: Add context and reflections to your goals
- **Statistics**: Track completion rates and goal history
- **Archive**: Review completed and abandoned goals

## Installation

Ensure `jq` is installed:
```bash
sudo apt install jq
```

## Usage

### Adding Goals

```bash
# Add a simple goal
./goals.sh add "Read 24 books this year"

# Add a goal with a deadline
./goals.sh add "Launch side project" 2026-06-30

# Add a goal with a deadline
./goals.sh add "Learn conversational Spanish" 2026-12-31
```

### Managing Milestones

Break your goals into achievable milestones:

```bash
# Add milestones to goal #1
./goals.sh milestone 1 "Complete Duolingo beginner course"
./goals.sh milestone 1 "Watch 10 Spanish movies without subtitles"
./goals.sh milestone 1 "Have a 10-minute conversation"

# Mark a milestone complete
./goals.sh check 1 1  # Mark milestone #1 of goal #1 as done
```

### Tracking Progress

```bash
# Update progress (0-100%)
./goals.sh progress 1 25

# View a specific goal
./goals.sh show 1

# List all active goals
./goals.sh list
```

### Adding Notes

```bash
# Add a note to track thoughts or progress
./goals.sh note 1 "Finished first module, enjoying the process!"
./goals.sh note 1 "Found a language exchange partner"
```

### Completing Goals

```bash
# Mark a goal as achieved
./goals.sh complete 1

# Or archive an abandoned goal
./goals.sh abandon 2
```

### Viewing Statistics

```bash
# See overall statistics
./goals.sh stats

# View archived goals
./goals.sh archive
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `add "title" [deadline]` | Add a new goal (deadline: YYYY-MM-DD) |
| `list` | List all active goals with progress |
| `show <id>` | Show detailed view of a goal |
| `progress <id> <percent>` | Update goal progress (0-100) |
| `milestone <id> "desc"` | Add a milestone to a goal |
| `check <id> <milestone_id>` | Mark a milestone complete |
| `note <id> "text"` | Add a note to a goal |
| `complete <id>` | Mark goal as achieved |
| `abandon <id>` | Archive an abandoned goal |
| `archive` | Show archived goals |
| `stats` | Show goal statistics |
| `help` | Show help message |

## Examples

### Example Workflow

```bash
# Create a fitness goal
./goals.sh add "Run a marathon" 2026-10-15

# Add milestones
./goals.sh milestone 1 "Run 5K without stopping"
./goals.sh milestone 1 "Run 10K under 60 minutes"
./goals.sh milestone 1 "Complete a half marathon"
./goals.sh milestone 1 "Run 30K training run"

# Track progress over time
./goals.sh check 1 1
./goals.sh progress 1 20
./goals.sh note 1 "5K done! Feeling great"

./goals.sh check 1 2
./goals.sh progress 1 40

# View progress
./goals.sh show 1
```

### Output Example

```
=== Goal #1 ===

Run a marathon

Progress: [████████░░░░░░░░░░░░]  40%

Status: active
Created: 2026-01-18 10:30
Deadline: 2026-10-15 (270 days left)

Milestones:
  [✓] #1 Run 5K without stopping (2026-02-01 08:00)
  [✓] #2 Run 10K under 60 minutes (2026-03-15 09:30)
  [ ] #3 Complete a half marathon
  [ ] #4 Run 30K training run

Notes:
  [2026-02-01] 5K done! Feeling great
```

## Data Storage

Goal data is stored in `data/goals.json` within the tool directory. Back up this file to preserve your goal history.

## Integration Ideas

- Combine with `weekly-planner` to review goals weekly
- Use `reminders` to set check-in reminders for goals
- Export goal progress to `daily-summary` for productivity tracking
