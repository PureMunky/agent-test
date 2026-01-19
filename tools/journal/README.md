# Journal

Personal daily journal for reflection, thought capture, and self-discovery.

## Features

- **Daily Journaling**: Write and edit daily journal entries with your preferred editor
- **Quick Thoughts**: Capture fleeting ideas without opening the full editor
- **Journaling Prompts**: 25 thoughtful prompts to inspire writing when you're stuck
- **Mood Tracking**: Log daily mood (1-5 scale) with visual statistics
- **Streak Tracking**: Maintain your journaling habit with streak visibility
- **Search**: Find past reflections and insights across all entries
- **Random Entry**: Revisit a surprise entry from your past
- **Export**: Backup entries to markdown or JSON format

## Usage

```bash
# Start writing today's entry (opens in your $EDITOR)
./journal.sh

# Add a quick thought without opening editor
./journal.sh add "Had an interesting conversation about career goals"

# Get a random journaling prompt for inspiration
./journal.sh prompt

# Log today's mood (1=low, 5=high)
./journal.sh mood 4

# View today's entry
./journal.sh today

# Read a past entry
./journal.sh read 2026-01-15
./journal.sh read yesterday

# List recent entries
./journal.sh list
./journal.sh list 20

# Search for a topic
./journal.sh search "gratitude"

# View your journaling streak
./journal.sh streak

# View statistics
./journal.sh stats

# Read a random past entry
./journal.sh random

# Export last 30 days to markdown
./journal.sh export markdown 30 > my-journal.md
```

## Journal Entry Format

Each entry is saved as a markdown file with the date as filename:

```markdown
# Journal Entry - 2026-01-19

**Time:** 09:30

---

## Prompt
*What are you grateful for today?*

## Entry
[Your journal writing here...]

---

## Quick Thoughts
- [09:45] Had an idea about the new project
- [14:20] Feeling energized after the walk

---
```

## Mood Tracking

Track your emotional state over time:

```
1 - Low/Difficult      (hard day)
2 - Below Average      (challenging)
3 - Neutral/Okay       (average day)
4 - Good               (positive day)
5 - Great/Excellent    (exceptional day)
```

View mood distribution with `journal.sh stats`.

## Journaling Prompts

Get inspiration when facing a blank page:

- What's on your mind right now?
- What are you grateful for today?
- What's one thing you learned recently?
- How are you feeling, and why?
- What's a challenge you're facing?
- What made you smile today?
- ... and 19 more prompts

## Tips for Consistent Journaling

1. **Set a time**: Journal at the same time each day
2. **Start small**: Even 3 sentences counts
3. **Use quick thoughts**: Capture ideas throughout the day
4. **Review prompts**: Use `journal.sh prompt` when stuck
5. **Track your streak**: Let it motivate you to continue
6. **Be honest**: This is for you alone
7. **Read old entries**: Use `journal.sh random` for perspective

## Data Storage

- Entries: `data/entries/YYYY-MM-DD.md`
- Index and stats: `data/index.json`

## Differences from Other Tools

| Tool | Purpose |
|------|---------|
| **journal** | Personal reflection, thoughts, emotions |
| worklog | Professional work tracking for standups |
| wins | Gratitude and small wins (positive focus only) |
| project-journal | Project-specific progress tracking |
| daily-kickstart | Morning routine and day planning |

## Requirements

- bash
- jq
- A text editor (uses `$EDITOR` or falls back to nano)
