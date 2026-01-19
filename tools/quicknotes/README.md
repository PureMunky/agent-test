# Quick Notes

A fast command-line tool for capturing notes on the fly, now with tagging support.

## Usage

```bash
# Add a note
./quicknotes.sh add "Remember to review PR #42"

# Add a note with tags
./quicknotes.sh add "Discussed Q1 roadmap with team #work #meeting"

# Quick add (shortcut - anything not a command becomes a note)
./quicknotes.sh "This also adds a note"

# List recent notes
./quicknotes.sh list      # Last 10
./quicknotes.sh list 20   # Last 20

# Search notes
./quicknotes.sh search "meeting"

# Today's notes only
./quicknotes.sh today

# Filter by tag
./quicknotes.sh tag work
./quicknotes.sh tag #meeting

# List all tags with usage counts
./quicknotes.sh tags

# Delete a specific note
./quicknotes.sh delete 5

# Export notes
./quicknotes.sh export backup.txt

# View statistics
./quicknotes.sh stats

# Open in editor
./quicknotes.sh edit
```

## Features

- **Timestamped notes** - Each note is automatically timestamped
- **Inline tagging** - Use `#tag` syntax anywhere in your notes
- **Tag filtering** - Filter notes by tag with `tag` command
- **Tag listing** - See all tags with usage counts
- **Quick capture** - Minimal syntax for fast note-taking
- **Search** - Full-text search across all notes
- **Statistics** - Track your note-taking habits
- **Delete** - Remove specific notes by line number
- **Export** - Backup notes to a file
- **Pipe support** - `echo "note" | quicknotes.sh add`

## Tagging

Add tags inline using the `#hashtag` syntax:

```bash
# Multiple tags
./quicknotes.sh add "Review PR for auth module #work #code-review #urgent"

# Filter by tag
./quicknotes.sh tag work           # Show all #work notes
./quicknotes.sh tag #code-review   # Leading # is optional

# List all tags
./quicknotes.sh tags
```

Tags are case-insensitive and can contain letters, numbers, dashes, and underscores.

## Data

Notes are stored in `data/notes.txt` in a simple timestamped format that remains human-readable and compatible with standard text tools.

## Version

2.0.0 - Added tagging, delete, export, and statistics features
