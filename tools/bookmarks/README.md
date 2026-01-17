# Bookmarks

A command-line bookmark manager for saving, organizing, and searching URLs and resources.

## Features

- Save bookmarks with optional titles and tags
- Search bookmarks by title, URL, or tags
- Organize bookmarks with tags
- Open bookmarks directly in your browser
- Track access counts
- Export/import bookmarks as JSON

## Installation

Make the script executable:

```bash
chmod +x bookmarks.sh
```

### Requirements

- `jq` - JSON processor (install with `sudo apt install jq`)

## Usage

### Add a bookmark

```bash
# Simple - just URL (title auto-extracted from domain)
./bookmarks.sh add https://github.com

# With custom title
./bookmarks.sh add https://docs.python.org "Python Documentation"

# With title and tags
./bookmarks.sh add https://docs.python.org "Python Docs" python reference docs
```

### List bookmarks

```bash
# List all bookmarks
./bookmarks.sh list

# Filter by tag
./bookmarks.sh list python
```

### Search bookmarks

```bash
# Search in titles, URLs, and tags
./bookmarks.sh search docs
./bookmarks.sh search github
```

### View all tags

```bash
./bookmarks.sh tags
```

### Open a bookmark

```bash
# Opens bookmark #3 in your default browser
./bookmarks.sh open 3
```

### Edit a bookmark

```bash
# Interactive editing of bookmark #5
./bookmarks.sh edit 5
```

### Remove a bookmark

```bash
./bookmarks.sh remove 3
```

### Export/Import

```bash
# Export to JSON file
./bookmarks.sh export my_bookmarks.json

# Import from JSON file
./bookmarks.sh import my_bookmarks.json
```

## Data Storage

Bookmarks are stored in `data/bookmarks.json` in the tool directory.

## Aliases

For convenience, add to your shell profile:

```bash
alias bm='/path/to/bookmarks.sh'
alias bma='bm add'
alias bms='bm search'
alias bmo='bm open'
```
