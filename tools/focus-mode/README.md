# Focus Mode

A command-line tool for managing focused work sessions with distraction blocking and statistics tracking.

## Features

- **Timed Focus Sessions**: Start focus sessions of any duration (default 25 minutes)
- **Distraction Blocking**: Maintains a customizable list of sites to block during focus time
- **Session Tracking**: Logs all focus sessions with completion status
- **Statistics**: View daily, weekly, and all-time focus statistics
- **Desktop Notifications**: Get notified when sessions start and complete
- **Progress Tracking**: See real-time progress during active sessions

## Installation

The tool requires `jq` for JSON processing:

```bash
sudo apt install jq   # Debian/Ubuntu
brew install jq       # macOS
```

## Usage

### Starting a Focus Session

```bash
# Start a 25-minute focus session (default)
./focus-mode.sh start

# Start a custom duration session
./focus-mode.sh start 45    # 45-minute session
./focus-mode.sh 30          # Quick start: 30-minute session
```

### Checking Status

```bash
# View current status and progress
./focus-mode.sh status

# Or just run without arguments
./focus-mode.sh
```

### Stopping Early

```bash
./focus-mode.sh stop
```

### Managing Blocked Sites

```bash
# List all blocked sites
./focus-mode.sh block list

# Add a site to the block list
./focus-mode.sh block add hacker-news.com

# Remove a site from the block list
./focus-mode.sh block remove youtube.com
```

### Viewing Statistics

```bash
./focus-mode.sh stats
```

### Configuration

```bash
# View current configuration
./focus-mode.sh config
```

Configuration is stored in `data/config.json` and can be manually edited.

## Default Blocked Sites

The tool comes pre-configured to block common distracting sites:

- facebook.com
- twitter.com / x.com
- instagram.com
- reddit.com
- youtube.com
- tiktok.com
- netflix.com
- twitch.tv

## How Blocking Works

The tool generates a hosts-format block file at `data/blocked_hosts.txt` when a focus session starts. This file can be used with:

1. **Browser Extensions**: Extensions like uBlock Origin can import custom block lists
2. **System Hosts File**: Append to `/etc/hosts` (requires sudo)
3. **Third-party Apps**: Tools like Cold Turkey, Freedom, or SelfControl

The tool does not modify system files automatically to avoid requiring root permissions.

## Data Files

- `data/config.json` - Configuration settings
- `data/current_session.json` - Active session state (temporary)
- `data/history.csv` - Session history log
- `data/blocked_hosts.txt` - Generated block list (when session active)

## Integration with Pomodoro Timer

Focus Mode complements the Pomodoro tool by adding distraction blocking. For a complete focus workflow:

1. Start a focus session: `focus-mode.sh start 25`
2. Or use pomodoro for timing: `pomodoro.sh start` while focus-mode blocks distractions

## Tips for Maximum Focus

- Put your phone in another room
- Close unnecessary browser tabs
- Use "Do Not Disturb" mode on your OS
- Have water and snacks nearby
- Take breaks between focus sessions

## Examples

```bash
# Morning focus routine
./focus-mode.sh block add news.ycombinator.com
./focus-mode.sh start 90

# Check how you're doing
./focus-mode.sh status

# End of day review
./focus-mode.sh stats

# Quick 15-minute task
./focus-mode.sh 15
```
