# Meeting Notes

A command-line meeting notes template generator and manager. Quickly create structured meeting notes from templates, track action items, and search through your meeting history.

## Features

- **Multiple Templates**: Standup, 1-on-1, retrospective, brainstorming, kickoff, decision records
- **Action Item Tracking**: Extract and list uncompleted action items from all meetings
- **Search**: Search through meeting titles and content
- **Organized Storage**: Each meeting saved as a markdown file with metadata indexing

## Requirements

- `jq` - JSON processor (`sudo apt install jq`)
- A text editor (uses `$EDITOR`, `$VISUAL`, or defaults to `nano`)

## Usage

```bash
# Create new meeting notes (opens in editor)
./meeting-notes.sh new "Weekly Team Sync"

# Create with a specific template
./meeting-notes.sh template standup
./meeting-notes.sh template kickoff "Project Alpha"

# List recent meetings
./meeting-notes.sh list
./meeting-notes.sh list 20  # Show 20 most recent

# View meeting notes
./meeting-notes.sh view 1

# Edit meeting notes
./meeting-notes.sh edit 1

# Search meetings
./meeting-notes.sh search "project alpha"

# List all uncompleted action items
./meeting-notes.sh action-items

# List action items from specific meeting
./meeting-notes.sh action-items 3

# See available templates
./meeting-notes.sh templates

# Remove a meeting
./meeting-notes.sh remove 1
```

## Available Templates

| Template | Description |
|----------|-------------|
| `default` | General meeting with agenda, notes, decisions, action items |
| `standup` | Daily standup (yesterday, today, blockers) |
| `one-on-one` | 1-on-1 meeting with check-in, discussion, feedback |
| `retrospective` | Sprint retro (went well, improve, action items) |
| `brainstorm` | Brainstorming session with ideas and evaluation |
| `kickoff` | Project kickoff with goals, scope, timeline, roles |
| `decision` | Decision record / ADR format |

## Using Templates

You can specify a template in two ways:

```bash
# Using the template command
./meeting-notes.sh template standup "Daily Standup"

# Using environment variable
MEETING_TEMPLATE=retrospective ./meeting-notes.sh new "Sprint 5 Retro"
```

## Action Items

Meeting notes use markdown checkbox format for action items:

```markdown
### Action Items
- [ ] Review the proposal by Friday
- [ ] Schedule follow-up meeting
- [x] Completed item
```

The `action-items` command extracts all unchecked items (`- [ ]`) from your meetings.

## File Storage

- Meeting notes are stored in `data/notes/` as markdown files
- Metadata is indexed in `data/index.json`
- Files are named `meeting_<id>.md` for easy reference

## Examples

### Create a Daily Standup

```bash
./meeting-notes.sh template standup
```

Creates a standup template with sections for Yesterday, Today, and Blockers.

### Track Action Items Across Meetings

```bash
./meeting-notes.sh action-items
```

Shows all uncompleted action items from all meetings, organized by meeting.

### Find Meeting About a Topic

```bash
./meeting-notes.sh search "budget"
```

Searches both meeting titles and content for the query.
