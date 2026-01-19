# Project Journal

Track progress, notes, and milestones for your projects. Keep a structured journal of what you've accomplished, decisions made, and resources gathered.

## Features

- **Project Management**: Create and manage multiple projects with statuses
- **Journal Entries**: Log progress updates with inline #tag support
- **Milestones**: Record and track significant achievements
- **Links**: Store related URLs, documentation, and resources
- **Search**: Find entries across all projects
- **Export**: Generate markdown documentation for any project
- **Archive**: Keep completed projects organized without cluttering the active list

## Installation

The tool is ready to use. Requires `jq` for JSON processing:

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Creating Projects

```bash
# Create a new project
./project-journal.sh new "Website Redesign"
./project-journal.sh new "Q1 Marketing Campaign"
```

### Logging Progress

```bash
# Add journal entries (project names can be abbreviated)
./project-journal.sh log website "Completed wireframes for homepage"
./project-journal.sh log website "Met with stakeholders, approved color scheme"

# Use #tags to categorize entries
./project-journal.sh log website "Fixed #bug with mobile navigation #frontend"
./project-journal.sh log campaign "Drafted email copy #content #review"
```

### Recording Milestones

```bash
# Record significant achievements
./project-journal.sh milestone website "v1.0 design approved"
./project-journal.sh milestone website "Staging environment deployed"
./project-journal.sh milestone campaign "Campaign launched!"
```

### Managing Projects

```bash
# View project details and recent entries
./project-journal.sh view website
./project-journal.sh view website 50  # Show last 50 entries

# Set project status
./project-journal.sh status website active
./project-journal.sh status website paused
./project-journal.sh status website completed

# Add project description
./project-journal.sh desc website "Complete redesign of company website with new branding"

# Add related links
./project-journal.sh link website "https://figma.com/..." "Design mockups"
./project-journal.sh link website "https://github.com/..." "Code repository"
```

### Listing and Searching

```bash
# List all active projects
./project-journal.sh list

# List all projects including archived
./project-journal.sh list --all

# List only archived projects
./project-journal.sh list --archived

# Search across all projects
./project-journal.sh search "navigation"
./project-journal.sh search "#frontend"
```

### Statistics and Export

```bash
# View statistics and recent activity
./project-journal.sh stats

# Export project to markdown
./project-journal.sh export website
./project-journal.sh export website website-journal.md
```

### Archiving

```bash
# Archive completed projects
./project-journal.sh archive website

# Restore archived project
./project-journal.sh unarchive website
```

## Project Statuses

| Status | Description |
|--------|-------------|
| `active` | Currently being worked on |
| `paused` | Temporarily on hold |
| `on-hold` | Waiting on external factors |
| `blocked` | Cannot proceed due to blockers |
| `completed` | Project finished |

## Data Storage

All data is stored in `data/projects.json` in the tool directory.

## Tips

1. **Use Tags**: Add #tags to entries for easy filtering and categorization
2. **Abbreviate**: Project names can be abbreviated when logging (e.g., "website" instead of "Website Redesign")
3. **Regular Logging**: Add entries frequently to maintain a useful history
4. **Export for Sharing**: Use export to create shareable project summaries
5. **Archive Completed**: Keep your active list clean by archiving completed projects

## Examples

### Starting a New Project

```bash
./project-journal.sh new "API Integration"
./project-journal.sh desc api "Integrate with third-party payment API"
./project-journal.sh link api "https://api.example.com/docs" "API Documentation"
./project-journal.sh log api "Initial research completed, selected REST endpoint approach"
```

### Daily Progress Updates

```bash
./project-journal.sh log api "Implemented authentication flow #backend"
./project-journal.sh log api "Added error handling for failed payments #backend #testing"
./project-journal.sh milestone api "Authentication working in staging"
```

### Project Completion

```bash
./project-journal.sh log api "Final testing complete, all edge cases handled"
./project-journal.sh milestone api "Production deployment successful"
./project-journal.sh status api completed
./project-journal.sh export api
./project-journal.sh archive api
```
