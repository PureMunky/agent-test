# Readlist

A reading list and learning content tracker for managing articles, books, videos, tutorials, and other learning material.

## Requirements

- `jq` - JSON processor (install with `sudo apt install jq`)

## Features

- Track multiple content types: articles, books, videos, tutorials, podcasts, courses, papers
- Status management: unread, in-progress, completed, abandoned
- Priority levels (1-5) for focusing on what matters
- Progress tracking for long-form content (chapters, pages, percentages)
- Time estimation and logging
- Notes/takeaways for each item
- Tagging system for organization
- Statistics and insights

## Usage

### Adding Items

```bash
# Add a book with author and time estimate
./readlist.sh add "Clean Code" -t book -a "Robert Martin" -e 10h

# Add an article from URL
./readlist.sh add https://example.com/article -t article -e 15m

# Add a tutorial with tags and high priority
./readlist.sh add "Rust Tutorial" -t tutorial --tags rust,programming -p 2

# Add a video course
./readlist.sh add "Complete React Course" -t course -a "Instructor Name" -e 20h --tags react,frontend
```

### Managing Items

```bash
# List all items
./readlist.sh list

# Filter by status
./readlist.sh list unread
./readlist.sh list in-progress

# Filter by type
./readlist.sh list -t book
./readlist.sh list unread -t article

# View item details
./readlist.sh view 1

# Open URL in browser
./readlist.sh open 1
```

### Tracking Progress

```bash
# Start reading/watching
./readlist.sh start 1

# Update progress
./readlist.sh progress 1 "Chapter 5/12"
./readlist.sh progress 2 "50%"
./readlist.sh progress 3 "Page 120/350"

# Mark as completed (optionally log time)
./readlist.sh done 1
./readlist.sh done 2 2h

# Abandon something you don't want to finish
./readlist.sh abandon 3
```

### Notes and Organization

```bash
# Add notes/takeaways
./readlist.sh note 1 "Key insight: always write tests first"
./readlist.sh note 1 "Chapter 3 on naming is excellent"

# Set priority (1=highest, 5=lowest)
./readlist.sh priority 2 1

# Search your reading list
./readlist.sh search "programming"
./readlist.sh search "Robert Martin"
```

### Statistics

```bash
# View reading statistics
./readlist.sh stats
```

## Content Types

| Type | Description |
|------|-------------|
| `article` | Web articles, blog posts, news (default) |
| `book` | Physical or digital books |
| `video` | YouTube videos, talks, presentations |
| `tutorial` | Step-by-step guides and tutorials |
| `podcast` | Podcast episodes |
| `course` | Online courses (Udemy, Coursera, etc.) |
| `paper` | Academic papers, research documents |

## Priority Levels

- **P1** (Red): Must read urgently
- **P2** (Yellow): High priority
- **P3** (Default): Normal priority
- **P4** (Gray): Low priority
- **P5** (Gray): Someday/maybe

## Status Icons

- `[ ]` - Unread
- `[~]` - In Progress
- `[x]` - Completed
- `[-]` - Abandoned

## Data Storage

Data is stored in `data/readlist.json` in a structured JSON format for easy backup or programmatic access.
