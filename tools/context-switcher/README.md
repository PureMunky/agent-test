# Context Switcher

A command-line tool for managing and switching between project contexts. Helps you stay organized when working on multiple projects by tracking directories, notes, and environment variables for each context.

## Features

- **Context Management**: Create, switch between, archive, and remove project contexts
- **Directory Tracking**: Associate each context with its project directory
- **Notes**: Keep context-specific notes to remember where you left off
- **Environment Variables**: Store project-specific environment variables
- **Activity History**: Track context switches and see recent activity
- **Archive Support**: Archive old contexts instead of deleting them

## Installation

The tool requires `jq` for JSON processing:

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Creating a Context

```bash
# Create a context for current directory
./context.sh create "my-project"

# Create a context with specific directory
./context.sh create "webapp" ~/projects/webapp

# Create context for a client project
./context.sh create "client-api" ~/work/client-api
```

### Switching Contexts

```bash
# Switch to a context
./context.sh switch my-project

# Or use shorthand
./context.sh sw webapp

# Or just type the context name
./context.sh my-project
```

### Managing Notes

Notes help you remember what you were working on when you return to a project:

```bash
# Add a note to current context
./context.sh note "Fix the authentication bug in login.js"
./context.sh note "Need to review PR #42"
./context.sh note "Left off at implementing the search feature"

# View notes for current context
./context.sh notes

# View notes for a specific context
./context.sh notes webapp
```

### Environment Variables

Store project-specific environment variables:

```bash
# Add environment variable to current context
./context.sh env "API_KEY=abc123"
./context.sh env "DATABASE_URL=postgres://localhost/mydb"
./context.sh env "DEBUG=true"

# When you switch contexts, env vars are displayed
# Copy and run them to set up your environment
```

### Listing Contexts

```bash
# List active contexts
./context.sh list

# List all contexts including archived
./context.sh list --all
```

### Status and Activity

```bash
# Show current context details
./context.sh current

# Show activity summary
./context.sh status
```

### Archiving and Removing

```bash
# Archive a context (keeps it but hides from list)
./context.sh archive old-project

# Permanently remove a context
./context.sh remove old-project
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `create "name" [dir]` | Create a new context |
| `switch "name"` | Switch to a context |
| `current` | Show current context details |
| `list` | List active contexts |
| `list --all` | List all contexts including archived |
| `note "text"` | Add note to current context |
| `notes [name]` | Show notes for a context |
| `env "KEY=value"` | Add env var to current context |
| `status` | Show activity summary |
| `archive "name"` | Archive a context |
| `remove "name"` | Permanently remove a context |
| `help` | Show help message |

## Tips

1. **Use notes liberally**: When you stop working on a project, add a note about what you were doing. Your future self will thank you.

2. **Store environment variables**: Instead of looking up API keys and database URLs each time, store them in the context.

3. **Archive instead of delete**: When a project is done, archive it instead of deleting. You might need to reference it later.

4. **Quick switching**: You can switch to a context by just typing its name: `./context.sh webapp`

5. **Integrate with shell**: Add an alias to your shell config:
   ```bash
   alias ctx='/path/to/context.sh'
   ```

## Data Storage

All data is stored in the `data/` subdirectory:
- `contexts.json` - All context definitions and notes
- `current.txt` - Currently active context
- `history.log` - Activity history

## Example Workflow

```bash
# Start of day - check what contexts you have
./context.sh list

# Switch to a project
./context.sh switch webapp

# See where you left off
./context.sh notes

# Add a note about what you're working on
./context.sh note "Working on user dashboard feature"

# Switch to another project for a meeting
./context.sh switch client-api

# Come back later
./context.sh switch webapp
# Your notes remind you what you were doing
```
