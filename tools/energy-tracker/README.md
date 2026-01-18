# Energy Tracker

Track your energy levels and mood throughout the day to understand your productivity patterns.

## Features

- Log energy levels (1-5 scale) with optional mood and notes
- Automatic time-of-day categorization (morning, afternoon, etc.)
- Pattern analysis to find your peak energy times
- Daily, weekly, and historical views
- Statistics with level distribution and mood tracking
- Data export (CSV/JSON)

## Installation

Requires `jq` for JSON processing:
```bash
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

## Usage

### Log Energy

```bash
# Full log with mood and note
./energy.sh log 4 focused "After morning coffee"

# Quick log (energy only)
./energy.sh quick 3
./energy.sh 4  # Shorthand
```

### View Data

```bash
# Today's entries
./energy.sh today

# This week's summary
./energy.sh week

# Pattern analysis
./energy.sh patterns

# History (last N days)
./energy.sh history 14
```

### Statistics

```bash
./energy.sh stats
```

### Export

```bash
./energy.sh export csv > energy_data.csv
./energy.sh export json > energy_data.json
```

## Energy Scale

| Level | Description | When to use |
|-------|-------------|-------------|
| 1 | Very Low | Exhausted, need rest |
| 2 | Low | Tired, sluggish |
| 3 | Moderate | Okay, functional |
| 4 | High | Good energy, productive |
| 5 | Very High | Peak energy, focused |

## Example Moods

`great`, `good`, `okay`, `tired`, `stressed`, `focused`, `creative`, `anxious`, `calm`, `energized`

## Tips

- Log your energy 3-4 times per day for useful patterns
- Use the `patterns` command to find your peak productivity hours
- Schedule important work during high-energy times
- Track mood alongside energy to identify correlations

## Data Storage

Data is stored in `data/energy.json` within the tool directory.
