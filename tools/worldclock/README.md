# World Clock

A time zone converter and world clock tool for remote collaboration and scheduling across time zones.

## Features

- **World Clock Display**: See current time across all saved locations at a glance
- **Time Conversion**: Convert times between any two time zones
- **Meeting Finder**: Find optimal meeting times when work hours overlap
- **Location Management**: Save frequently used locations with custom names and emojis
- **Time Difference**: Quickly check the time difference between zones
- **Work Hours Highlighting**: Color-coded display shows work hours (green), evening (yellow), and night (gray)

## Installation

The tool is ready to use. Requires `jq` for JSON processing.

```bash
# Make executable (if not already)
chmod +x worldclock.sh

# Optional: Create alias
alias wc='./worldclock.sh'
```

## Usage

### Show Current Time

```bash
# Show current time in all saved locations
./worldclock.sh
./worldclock.sh now
```

### Manage Locations

```bash
# Add a new location
./worldclock.sh add Berlin Europe/Berlin
./worldclock.sh add Sydney Australia/Sydney 🦘

# Remove a location
./worldclock.sh remove Berlin

# List all saved locations
./worldclock.sh list
```

### Convert Times

```bash
# Convert time between zones
./worldclock.sh convert 14:00 America/New_York to Europe/London
./worldclock.sh convert "2026-01-20 09:00" UTC to Asia/Tokyo

# Show what time it is everywhere at a specific time
./worldclock.sh at 14:00
./worldclock.sh at 09:00 UTC
./worldclock.sh at "2026-01-20 15:00" America/Los_Angeles
```

### Meeting Planning

```bash
# Find best meeting time across all locations
./worldclock.sh meeting

# Find meeting time starting from a preferred time
./worldclock.sh meeting 10:00
./worldclock.sh meeting 14:00 America/New_York
```

### Time Difference

```bash
# Show difference between two zones
./worldclock.sh diff America/New_York Europe/London
./worldclock.sh diff Tokyo London
```

### Search Timezones

```bash
# List common timezones
./worldclock.sh zones

# Search for specific timezone
./worldclock.sh zones australia
./worldclock.sh zones america
```

## Display Colors

The world clock uses color coding to quickly identify work availability:
- **Green**: Work hours (9:00-18:00 local time)
- **Yellow**: Evening (18:00-22:00)
- **Gray**: Night/early morning (22:00-9:00)

## Default Locations

The tool comes preconfigured with these locations:
- Local (your system timezone)
- UTC
- New York (America/New_York)
- London (Europe/London)
- Tokyo (Asia/Tokyo)

You can customize these by adding/removing locations as needed.

## Data Storage

Location data is stored in `data/locations.json`. You can edit this file directly or use the CLI commands.

## Examples

```bash
# Daily workflow
./worldclock.sh                    # Check times across offices

# Scheduling a call
./worldclock.sh at 15:00          # "What time is 3pm here for everyone?"
./worldclock.sh meeting           # Find the best overlap

# Working with colleagues
./worldclock.sh diff "New York" Tokyo    # How far apart are we?
./worldclock.sh convert 9:00 Tokyo to local  # When their 9am is for me
```

## Tips

1. **Use saved location names**: You can use saved names (like "Tokyo") instead of full timezone strings (like "Asia/Tokyo") in most commands.

2. **Add your team's locations**: Set up locations for everyone you regularly collaborate with.

3. **Check before scheduling**: Use the `meeting` command to find times that work for everyone.

4. **Quick reference**: Run without arguments for an instant view of all your important timezones.
