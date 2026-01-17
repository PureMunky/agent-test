# Quick Notes

A fast command-line tool for capturing notes on the fly.

## Usage

```bash
# Add a note
./quicknotes.sh add "Remember to review PR #42"

# Quick add (shortcut - anything not a command becomes a note)
./quicknotes.sh "This also adds a note"

# List recent notes
./quicknotes.sh list      # Last 10
./quicknotes.sh list 20   # Last 20

# Search notes
./quicknotes.sh search "meeting"

# Today's notes only
./quicknotes.sh today

# Open in editor
./quicknotes.sh edit
```

## Features

- Timestamped notes
- Quick capture with minimal syntax
- Search functionality
- Filter by today's notes
- Pipe support: `echo "note" | quicknotes.sh add`

## Data

Notes are stored in `data/notes.txt` in a simple timestamped format.
