# Meeting Notes v2.0

A command-line meeting notes template generator and manager with attendee tracking, meeting series, export, archive, and statistics.

## What's New in v2.0

- **Attendees Tracking**: Record and search by meeting participants
- **Meeting Series**: Link recurring meetings (daily standups, weekly syncs) for easy navigation
- **Export**: Export notes to markdown or HTML format
- **Archive System**: Archive old meetings to keep your list clean
- **Statistics**: Track meeting frequency, top attendees, action item completion rates
- **New Templates**: Weekly sync and interview templates added
- **Action Item Completion**: Mark action items done directly from CLI
- **Automatic Migration**: Existing v1 data automatically migrates to v2 format

## Features

- **9 Templates**: Default, standup, 1-on-1, retrospective, brainstorming, kickoff, decision, weekly, interview
- **Action Item Tracking**: Extract and complete action items from meetings
- **Series Management**: Group related meetings together
- **Search**: Search through meeting titles, attendees, and content
- **Archive/Restore**: Keep old meetings accessible without cluttering the list
- **Export Options**: Markdown and HTML export formats

## Requirements

- `jq` - JSON processor (`sudo apt install jq`)
- A text editor (uses `$EDITOR`, `$VISUAL`, or defaults to `nano`)

## Quick Start

```bash
# Create a new meeting with attendees
./meeting-notes.sh new "Weekly Team Sync" --attendees "Alice, Bob, Carol"

# Create a meeting linked to a series
./meeting-notes.sh new "Daily Standup" --series "Engineering Standup"

# Use a specific template
./meeting-notes.sh template standup
./meeting-notes.sh template interview "Jane Doe"

# List recent meetings
./meeting-notes.sh list

# List meetings in a series
./meeting-notes.sh list --series "Engineering Standup"
```

## Usage

### Creating Meetings

```bash
# Basic meeting
./meeting-notes.sh new "Project Planning"

# With attendees
./meeting-notes.sh new "Budget Review" --attendees "Finance Team, CEO"

# With series
./meeting-notes.sh new "Sprint Review" --series "Sprint Ceremonies"

# With specific template
./meeting-notes.sh new "Candidate Interview" --template interview

# Using template shortcut
./meeting-notes.sh template standup
./meeting-notes.sh template kickoff "Project Alpha"
```

### Listing and Viewing

```bash
# List recent meetings (default: 10)
./meeting-notes.sh list
./meeting-notes.sh list 20  # Show 20 most recent

# Filter by series
./meeting-notes.sh list --series "Weekly Sync"

# Show archived meetings
./meeting-notes.sh list --archived

# View a meeting
./meeting-notes.sh view 5

# Edit a meeting
./meeting-notes.sh edit 5
```

### Searching

```bash
# Search in titles, attendees, and content
./meeting-notes.sh search "budget"
./meeting-notes.sh search "Alice"
```

### Action Items

```bash
# List all uncompleted action items
./meeting-notes.sh action-items

# List action items from a specific meeting (numbered)
./meeting-notes.sh action-items 5

# Include completed items
./meeting-notes.sh action-items 5 --all

# Mark action item #2 in meeting #5 as complete
./meeting-notes.sh complete 5 2
```

### Meeting Series

```bash
# List all series
./meeting-notes.sh series

# Create a new series
./meeting-notes.sh series add "Weekly 1-on-1s"
./meeting-notes.sh series add "Sprint Ceremonies" --description "Sprint planning, review, retro"

# View meetings in a series
./meeting-notes.sh series "Weekly 1-on-1s"

# Remove a series (meetings are unlinked, not deleted)
./meeting-notes.sh series remove "Old Series"
```

### Archive Management

```bash
# Archive an old meeting
./meeting-notes.sh archive 3

# View archived meetings
./meeting-notes.sh list --archived

# Restore from archive
./meeting-notes.sh unarchive 3
```

### Export

```bash
# Export to markdown (default)
./meeting-notes.sh export 5

# Export to HTML
./meeting-notes.sh export 5 --format html
```

### Statistics

```bash
# View meeting statistics
./meeting-notes.sh stats
```

Shows:
- Total meetings (active vs archived)
- Weekly/monthly activity
- Most used templates
- Top attendees
- Action item completion rate
- Series statistics

## Available Templates

| Template | Alias | Description |
|----------|-------|-------------|
| `default` | - | General meeting with agenda, notes, decisions, action items |
| `standup` | `daily` | Daily standup (yesterday, today, blockers) |
| `one-on-one` | `1on1` | 1-on-1 meeting with check-in, discussion, feedback |
| `retrospective` | `retro` | Sprint retro (went well, improve, action items) |
| `brainstorm` | - | Brainstorming session with ideas and evaluation |
| `kickoff` | `project-kickoff` | Project kickoff with goals, scope, timeline, roles |
| `decision` | `adr` | Decision record / ADR format |
| `weekly` | `weekly-sync` | Weekly team sync meeting |
| `interview` | - | Interview notes with assessment and recommendation |

## Action Items Format

Meeting notes use markdown checkbox format for action items:

```markdown
### Action Items
- [ ] Review the proposal by Friday
- [ ] Schedule follow-up meeting
- [x] Completed item
```

The `action-items` command extracts all unchecked items (`- [ ]`).

## File Storage

- Meeting notes: `data/notes/` (markdown files)
- Archived notes: `data/archive/`
- Meeting index: `data/index.json`
- Series data: `data/series.json`
- Files are named `meeting_<id>.md`

## Examples

### Daily Standup Workflow

```bash
# Create a series for your standups
./meeting-notes.sh series add "Team Standup" --description "Daily engineering standup"

# Create daily standup notes
./meeting-notes.sh new "Daily Standup" --series "Team Standup" --template standup

# Review all standups
./meeting-notes.sh list --series "Team Standup"
```

### Meeting with Action Item Follow-up

```bash
# Create meeting
./meeting-notes.sh new "Project Planning" --attendees "Alice, Bob"

# Later, check action items
./meeting-notes.sh action-items 1

# Complete items as you finish them
./meeting-notes.sh complete 1 1
./meeting-notes.sh complete 1 2
```

### End-of-Quarter Cleanup

```bash
# View statistics
./meeting-notes.sh stats

# Archive old meetings
./meeting-notes.sh archive 1
./meeting-notes.sh archive 2
./meeting-notes.sh archive 3

# Export important meetings for reference
./meeting-notes.sh export 10 --format html
```

## Command Reference

| Command | Description |
|---------|-------------|
| `new "title" [options]` | Create new meeting notes |
| `list [n] [options]` | List meetings (n = count) |
| `view <id>` | View meeting notes |
| `edit <id>` | Edit meeting notes |
| `search "query"` | Search meetings |
| `remove <id>` | Delete meeting |
| `action-items [id]` | List action items |
| `complete <id> <num>` | Mark action item done |
| `templates` | List available templates |
| `template <name>` | Create with template |
| `series` | List/manage meeting series |
| `archive <id>` | Archive a meeting |
| `unarchive <id>` | Restore from archive |
| `export <id>` | Export to file |
| `stats` | Show statistics |
| `help` | Show help |
