# Pomodoro Timer

A simple command-line Pomodoro timer for focused work sessions.

## Usage

```bash
# Start a default 25-minute work / 5-minute break session
./pomodoro.sh

# Custom durations (work_minutes break_minutes)
./pomodoro.sh 30 10

# View today's completed pomodoros
./pomodoro.sh status

# Take a 15-minute long break
./pomodoro.sh long-break
```

## Features

- Countdown timer with visual feedback
- Desktop notifications (if `notify-send` is available)
- Terminal bell alert
- Automatic logging of completed sessions
- Daily statistics

## Data

Session logs are stored in `data/pomodoro_log.txt`.
