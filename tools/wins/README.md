# Wins - Gratitude and Small Wins Journal

A lightweight command-line tool for recording daily wins and gratitude. Research shows that gratitude journaling improves mental well-being, increases optimism, and boosts productivity.

## Features

- **Quick capture**: Log wins and gratitude with simple commands
- **Two entry types**: Separate tracking for achievements (wins) and gratitude
- **Streak tracking**: Build a daily journaling habit with streak counting
- **Motivation boost**: Random past wins feature for encouragement
- **Statistics**: Track your journaling patterns over time
- **Search**: Find past entries by keyword
- **Export**: Export to markdown for backup or sharing

## Installation

No installation required. The script uses `jq` for JSON processing.

```bash
# Ensure jq is installed
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

## Usage

### Adding Entries

```bash
# Log a win
./wins.sh win "Completed the quarterly report"

# Log gratitude
./wins.sh grateful "Had a great lunch with friends"

# Quick add (auto-detects type)
./wins.sh add "Got promoted!"
./wins.sh "Finished my morning workout"  # Direct input also works
```

### Viewing Entries

```bash
# Today's entries
./wins.sh today

# This week's entries
./wins.sh week

# Your journaling streak
./wins.sh streak

# Random past win for motivation
./wins.sh random
```

### Statistics and Search

```bash
# View statistics
./wins.sh stats

# Search past entries
./wins.sh search "project"
```

### Export

```bash
# Export last 30 days to markdown
./wins.sh export

# Export last N days
./wins.sh export 7
```

## Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `win "text"` | `w` | Log a personal win |
| `grateful "text"` | `gratitude`, `thanks`, `g` | Log gratitude |
| `add "text"` | - | Auto-detect and log |
| `today` | `t` | Show today's entries |
| `week` | `weekly` | Show this week's entries |
| `streak` | `s` | Show your journaling streak |
| `random` | `r`, `motivate` | Show a random past win |
| `stats` | `statistics` | Show statistics |
| `search "keyword"` | `find` | Search past entries |
| `export [days]` | - | Export to markdown |
| `help` | `-h`, `--help` | Show help |

## Data Storage

All data is stored in `data/wins.json` within the tool directory.

## Tips for Building a Habit

1. **Start small**: Log just one win or gratitude entry per day
2. **Be specific**: "Completed 3 code reviews" is better than "Did some work"
3. **Include small wins**: Everyday accomplishments count too
4. **Mix types**: Both wins and gratitude improve well-being
5. **Check your streak**: Use `wins.sh streak` to stay motivated

## Examples

```bash
# Morning gratitude
./wins.sh grateful "Good night's sleep"

# Work wins
./wins.sh win "Fixed the critical bug in production"
./wins.sh win "Mentored a junior developer"

# Personal wins
./wins.sh win "Went for a 5k run"
./wins.sh win "Cooked a healthy dinner"

# Get motivation when feeling down
./wins.sh random
```

## Why Track Wins and Gratitude?

- **Improved well-being**: Regular gratitude practice reduces stress
- **Better perspective**: Reviewing wins reminds you of your capabilities
- **Motivation**: Seeing your streak grow encourages consistency
- **Pattern recognition**: Stats help identify when you're most positive
- **Evidence-based**: The random win feature provides concrete proof of your abilities
