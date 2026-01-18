# Break Timer

Smart break reminders with healthy activity suggestions to help you maintain focus and wellbeing during work sessions.

## Features

- Configurable work interval reminders
- Three break types: stretch (2 min), short (5 min), long (15 min)
- Curated activity suggestions for each break type
- Break history tracking and statistics
- Desktop notifications (when notify-send is available)
- Fully configurable durations

## Usage

```bash
# Start reminder timer (reminds you every 50 minutes by default)
./break-timer.sh start
./break-timer.sh start 30    # Remind every 30 minutes

# Stop the reminder
./break-timer.sh stop

# Take a break now
./break-timer.sh break       # 5-minute break with suggestion
./break-timer.sh break 10    # 10-minute break
./break-timer.sh long        # 15-minute long break
./break-timer.sh stretch     # Quick 2-minute stretch

# Get activity suggestions without taking a break
./break-timer.sh suggest           # Random suggestion
./break-timer.sh suggest stretch   # Stretch-specific
./break-timer.sh suggest short     # Short break activity
./break-timer.sh suggest long      # Long break activity

# View history and stats
./break-timer.sh history           # Today's breaks
./break-timer.sh history 2026-01-15 # Specific date
./break-timer.sh stats             # Overall statistics

# Configure
./break-timer.sh config                        # View settings
./break-timer.sh config set work_interval 45   # Change work interval
./break-timer.sh config set short_break 7      # Change break duration
```

## Break Types

### Stretch Breaks (2 min)
Quick physical movements to prevent stiffness:
- Neck rolls, shoulder shrugs
- Wrist circles, standing stretches
- Eye exercises

### Short Breaks (5 min)
Quick refreshers to reset focus:
- Hydration breaks
- 20-20-20 eye rule
- Deep breathing
- Quick walk

### Long Breaks (15 min)
Substantial rest for sustained productivity:
- Outdoor walks
- Meditation
- Healthy snacks
- Reading

## Configuration

Settings are stored in `data/config.json`:

```json
{
    "work_interval": 50,
    "short_break": 5,
    "long_break": 15,
    "stretch_break": 2,
    "notify_sound": true,
    "show_suggestion": true
}
```

## Why Take Breaks?

Research shows regular breaks:
- Improve focus and concentration
- Reduce eye strain and physical tension
- Boost creativity and problem-solving
- Prevent burnout

The default 50/5 pattern is based on research showing optimal focus periods.

## Data

Break history is stored in `data/break_history.csv` for tracking patterns over time.
