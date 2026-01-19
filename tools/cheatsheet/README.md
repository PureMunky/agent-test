# Cheatsheet

Quick reference cards for commands, shortcuts, and syntax. Store and instantly look up keyboard shortcuts, command syntax, programming patterns, and other reference information organized by topic.

## Features

- **Built-in cheatsheets** for git, vim, docker, bash, and tmux
- **Custom cheatsheets** - create your own reference cards
- **Search** across all cheatsheets to find what you need fast
- **Sections** - organize entries logically within each sheet
- **Markdown import/export** for sharing and backup
- **Simple entry management** - add, remove, and edit entries

## Usage

```bash
# List all available cheatsheets
./cheatsheet.sh list

# Show a cheatsheet (shorthand: just use the name)
./cheatsheet.sh show git
./cheatsheet.sh git

# Search across all cheatsheets
./cheatsheet.sh search commit
./cheatsheet.sh search "delete branch"

# Create a new cheatsheet
./cheatsheet.sh create python

# Add entries to your cheatsheet
./cheatsheet.sh add python "Basics" "print()" "Output to console"
./cheatsheet.sh add python "Basics" "len(x)" "Get length of x"
./cheatsheet.sh add python "Lists" "list.append(x)" "Add x to end of list"

# Add a new section
./cheatsheet.sh add-section python "File I/O"

# Remove an entry
./cheatsheet.sh remove-entry python "Basics" "print()"

# Edit a cheatsheet directly in your editor
./cheatsheet.sh edit python

# Delete a cheatsheet
./cheatsheet.sh delete python

# Export to markdown
./cheatsheet.sh export git git-cheatsheet.md

# Import from markdown
./cheatsheet.sh import python-cheatsheet.md
```

## Built-in Cheatsheets

The tool comes with commonly needed reference cards:

| Name | Description |
|------|-------------|
| `git` | Git version control commands |
| `vim` | Vim text editor commands |
| `docker` | Docker container commands |
| `bash` | Bash shell shortcuts and syntax |
| `tmux` | Tmux terminal multiplexer |

View any built-in with: `./cheatsheet.sh <name>`

## Creating Custom Cheatsheets

1. Create a new cheatsheet:
   ```bash
   ./cheatsheet.sh create kubectl
   ```

2. Add entries:
   ```bash
   ./cheatsheet.sh add kubectl "Pods" "kubectl get pods" "List all pods"
   ./cheatsheet.sh add kubectl "Pods" "kubectl describe pod <name>" "Show pod details"
   ```

3. View your cheatsheet:
   ```bash
   ./cheatsheet.sh kubectl
   ```

## Cheatsheet Format

Cheatsheets are stored as JSON files in `data/sheets/`. The format is:

```json
{
    "name": "example",
    "description": "Example cheatsheet",
    "sections": {
        "Section Name": {
            "command or shortcut": "description",
            "another command": "another description"
        },
        "Another Section": {
            ...
        }
    }
}
```

## Markdown Import/Export

Export a cheatsheet to share or backup:
```bash
./cheatsheet.sh export git ~/Desktop/git-cheatsheet.md
```

Import from markdown:
```bash
./cheatsheet.sh import team-cheatsheet.md
```

The markdown format uses:
- `# Name Cheatsheet` for the title
- `## Section Name` for sections
- Tables with `| Command | Description |` format

## Tips

- Use `./cheatsheet.sh search` to quickly find commands across all sheets
- Keep entries short - this is for quick reference, not documentation
- Use descriptive section names to organize related commands
- Export to markdown for easy sharing with teammates
- Built-in sheets can't be modified, but you can export and re-import as custom

## Examples

Quick lookup of git branch commands:
```bash
./cheatsheet.sh git
# or search specifically
./cheatsheet.sh search branch
```

Build a team-specific cheatsheet:
```bash
./cheatsheet.sh create team-deploy
./cheatsheet.sh add team-deploy "Staging" "make deploy-staging" "Deploy to staging environment"
./cheatsheet.sh add team-deploy "Staging" "make rollback-staging" "Rollback staging deployment"
./cheatsheet.sh add team-deploy "Production" "make deploy-prod" "Deploy to production (requires approval)"
```

## Requirements

- `jq` for JSON processing
- `bash` 4.0+
