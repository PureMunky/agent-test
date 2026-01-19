# Wiki - Personal Knowledge Base

A personal wiki and knowledge base for documenting learnings, procedures, reference information, and internal documentation organized by topics with wiki-style linking.

## Features

- **Topic Organization**: Organize pages into topics (development, devops, personal, etc.)
- **Wiki-Style Links**: Use `[[Page Title]]` syntax for internal linking
- **Backlinks**: Automatically track what pages link to each page
- **Full-Text Search**: Search across titles and content
- **Archive System**: Archive old pages without deleting them
- **Export**: Export to markdown or basic HTML

## Installation

The tool is ready to use. Ensure `jq` is installed:

```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Creating Pages

```bash
# Create a new page
./wiki.sh new "Page Title"

# Create with a specific topic
./wiki.sh new "Docker Basics" --topic devops

# Topics are created automatically
./wiki.sh new "Git Workflow" --topic development
```

### Viewing and Editing

```bash
# View a page by ID or title
./wiki.sh view 1
./wiki.sh view "docker basics"

# Edit a page
./wiki.sh edit 1
./wiki.sh edit "git workflow"

# List all pages
./wiki.sh list

# List pages in a topic
./wiki.sh list --topic devops
```

### Searching

```bash
# Search titles and content
./wiki.sh search "kubernetes"
./wiki.sh search "how to deploy"
```

### Wiki Links

Inside your pages, use double brackets to create wiki-style links:

```markdown
See [[Git Workflow]] for our branching strategy.
This relates to [[Docker Basics]] as well.
```

These links are automatically detected and tracked. View backlinks with:

```bash
./wiki.sh backlinks "Git Workflow"
```

### Organizing

```bash
# List all topics
./wiki.sh topics

# Show recently updated pages
./wiki.sh recent
./wiki.sh recent 20

# Archive a page
./wiki.sh archive 5

# Restore archived page
./wiki.sh unarchive 5

# List including archived
./wiki.sh list --archived
```

### Exporting

```bash
# Export to markdown (organized by topic)
./wiki.sh export

# Export to HTML
./wiki.sh export --format html
```

### Statistics

```bash
./wiki.sh stats
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `new "title" [--topic t]` | Create a new wiki page |
| `edit <id\|title>` | Edit an existing page |
| `view <id\|title>` | View a page |
| `list [--topic t]` | List all pages |
| `search "query"` | Search pages |
| `topics` | List all topics |
| `link <from> <to>` | Link two pages |
| `backlinks <id>` | Show pages linking to a page |
| `recent [n]` | Show recently updated pages |
| `archive <id>` | Archive a page |
| `unarchive <id>` | Restore archived page |
| `export [--format md\|html]` | Export all pages |
| `stats` | Show wiki statistics |
| `delete <id>` | Permanently delete a page |
| `help` | Show help |

## Page Template

New pages are created with this template:

```markdown
# Page Title

**Topic:** topic-name
**Created:** 2026-01-19 12:00
**Last Updated:** 2026-01-19 12:00

---

## Overview

## Details

## Related

-

---
*Wiki page #1*
```

## Use Cases

- **Development Documentation**: Code patterns, architecture decisions, API references
- **DevOps Runbooks**: Deployment procedures, incident response, infrastructure docs
- **Learning Notes**: Course notes, book summaries, tech deep-dives
- **Team Processes**: Onboarding guides, meeting notes templates, workflows
- **Personal Reference**: Frequently used commands, configuration snippets

## Data Storage

All data is stored in `data/`:
- `index.json` - Page index and metadata
- `pages/` - Individual page markdown files

## Tips

1. **Use Topics Wisely**: Group related pages under topics for easier browsing
2. **Link Liberally**: Use `[[Page Title]]` links to create a connected knowledge graph
3. **Check Backlinks**: Before deleting, check what pages link to a page
4. **Regular Export**: Export periodically for backup or sharing
5. **Archive vs Delete**: Archive pages you might need later, delete only when certain
