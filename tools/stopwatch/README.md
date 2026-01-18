# Stopwatch

A simple command-line stopwatch with lap times and support for multiple named timers.

## Features

- Start/stop/pause stopwatches with precision timing
- Support for multiple concurrent named stopwatches
- Lap time recording with split times
- Live updating display mode
- Session history tracking
- Pause and resume support

## Usage

```bash
# Basic usage
./stopwatch.sh start              # Start default stopwatch
./stopwatch.sh lap                # Record a lap
./stopwatch.sh stop               # Stop and save

# Named stopwatches
./stopwatch.sh start workout      # Start a named stopwatch
./stopwatch.sh lap workout        # Record lap for specific stopwatch
./stopwatch.sh status workout     # Check elapsed time
./stopwatch.sh stop workout       # Stop the stopwatch

# Multiple stopwatches
./stopwatch.sh start coding
./stopwatch.sh start meeting
./stopwatch.sh list               # See all active stopwatches

# Pause and resume
./stopwatch.sh pause workout      # Pause the stopwatch
./stopwatch.sh start workout      # Resume it

# Live display
./stopwatch.sh live workout       # Watch time tick (Ctrl+C to exit)

# History
./stopwatch.sh history            # Show last 10 sessions
./stopwatch.sh history 20         # Show last 20 sessions
```

## Commands

| Command | Description |
|---------|-------------|
| `start [name]` | Start a new stopwatch or resume a paused one |
| `stop [name]` | Stop the stopwatch and save to history |
| `pause [name]` | Pause without losing time |
| `lap [name]` | Record a lap/split time |
| `status [name]` | Show current elapsed time and laps |
| `reset [name]` | Reset without saving to history |
| `list` | List all active stopwatches |
| `history [n]` | Show last n completed sessions |
| `live [name]` | Live updating time display |
| `help` | Show help message |

## Examples

### Timing a workout with intervals

```bash
./stopwatch.sh start workout
# ... do first set ...
./stopwatch.sh lap workout    # Lap 1: 0:45.123
# ... do second set ...
./stopwatch.sh lap workout    # Lap 2: 1:32.456 (split: 0:47.333)
# ... do third set ...
./stopwatch.sh stop workout   # Final: 2:15.789

# Output shows all laps with split times
```

### Running multiple timers

```bash
./stopwatch.sh start project-a
./stopwatch.sh start project-b
./stopwatch.sh list
# Shows both timers running with current times

./stopwatch.sh stop project-a  # Stop just project-a
./stopwatch.sh status project-b # Check project-b
```

### Pause for breaks

```bash
./stopwatch.sh start coding
# ... work for a while ...
./stopwatch.sh pause coding     # Take a break
# ... break time ...
./stopwatch.sh start coding     # Resume - time continues from where it paused
```

## Time Format

- Times are displayed in `MM:SS.mmm` or `HH:MM:SS.mmm` format
- Millisecond precision for accurate timing
- Human-readable format also shown (e.g., "2h 15m 30s")

## Data Storage

- Active stopwatches are stored in `data/active/`
- Completed sessions are logged to `data/history.csv`
- History includes: date, name, duration, lap count, start time, end time

## Comparison with Pomodoro

| Feature | Stopwatch | Pomodoro |
|---------|-----------|----------|
| Fixed intervals | No | Yes (25/5 min) |
| Free-form timing | Yes | No |
| Lap times | Yes | No |
| Multiple concurrent | Yes | No |
| Best for | Measuring activities | Focused work sessions |

Use **stopwatch** when you need to measure how long something takes.
Use **pomodoro** when you want structured work/break intervals.
