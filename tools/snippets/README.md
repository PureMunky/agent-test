# Snippets

A command and code snippet manager for storing, organizing, and quickly recalling frequently used commands and text.

## Features

- **Save snippets** with names and optional tags
- **Execute commands** directly from saved snippets
- **Copy to clipboard** for quick pasting
- **Tag-based organization** for easy categorization
- **Search** by name, content, or tags
- **Usage tracking** to see which snippets you use most
- **Import/Export** for backup and sharing

## Installation

Requires `jq` for JSON processing:

```bash
sudo apt install jq
```

For clipboard support, one of these tools is recommended:
- `xclip` (X11)
- `xsel` (X11)
- `wl-copy` (Wayland)
- `pbcopy` (macOS)

## Usage

### Adding Snippets

```bash
# Basic usage
./snippets.sh add "name" "content"

# With tags
./snippets.sh add "git-log" "git log --oneline -10" -t "git,log"

# Multi-line content (interactive)
./snippets.sh add "my-script"
# Then type/paste content, press Ctrl+D when done

# From pipe
echo 'docker ps -a' | ./snippets.sh add "docker-list"
cat my-function.sh | ./snippets.sh add "bash-function" -t "bash,template"
```

### Getting Snippets

```bash
# Get and copy to clipboard
./snippets.sh get "git-log"

# Show full details
./snippets.sh show "git-log"
```

### Running Command Snippets

```bash
# Execute a saved command
./snippets.sh run "git-log"

# With additional arguments
./snippets.sh run "docker-list" | grep nginx
```

### Listing and Searching

```bash
# List all snippets
./snippets.sh list

# Filter by tag
./snippets.sh list git

# Search by name, content, or tags
./snippets.sh search docker
./snippets.sh search "find.*log"
```

### Managing Tags

```bash
# List all tags
./snippets.sh tags
```

### Editing Snippets

```bash
# Edit in your default editor ($EDITOR or nano)
./snippets.sh edit "git-log"
```

### Removing Snippets

```bash
./snippets.sh remove "old-snippet"
```

### Import/Export

```bash
# Export all snippets
./snippets.sh export                    # Creates snippets_export.json
./snippets.sh export my-snippets.json   # Custom filename

# Import snippets
./snippets.sh import snippets_export.json
```

## Example Snippets

Here are some useful snippets to get you started:

```bash
# Git shortcuts
./snippets.sh add "git-status" "git status -sb" -t "git"
./snippets.sh add "git-log-graph" "git log --oneline --graph --all -20" -t "git,log"
./snippets.sh add "git-uncommit" "git reset --soft HEAD~1" -t "git"

# Docker commands
./snippets.sh add "docker-clean" "docker system prune -af" -t "docker,cleanup"
./snippets.sh add "docker-logs" "docker logs -f --tail 100" -t "docker,log"

# System info
./snippets.sh add "disk-usage" "df -h | head -10" -t "system"
./snippets.sh add "port-check" "ss -tulpn" -t "network,system"

# File operations
./snippets.sh add "find-large" "find . -type f -size +100M" -t "files"
./snippets.sh add "clean-logs" "find . -name '*.log' -mtime +7 -delete" -t "cleanup,files"
```

## Command Reference

| Command | Description |
|---------|-------------|
| `add "name" "content" [-t tags]` | Save a new snippet |
| `get "name"` | Get snippet content (copies to clipboard) |
| `run "name" [args]` | Execute snippet as a command |
| `show "name"` | Show full snippet details |
| `list [tag]` | List all snippets or filter by tag |
| `search "query"` | Search snippets by name/content/tags |
| `edit "name"` | Edit snippet in your editor |
| `remove "name"` | Delete a snippet |
| `tags` | List all tags with counts |
| `export [file]` | Export snippets to JSON |
| `import <file>` | Import snippets from JSON |
| `help` | Show help message |

## Data Storage

Snippets are stored in `data/snippets.json` within the tool directory. Each snippet includes:
- `name`: Unique identifier
- `content`: The snippet text/command
- `tags`: Array of tags for organization
- `created`: Timestamp when created
- `last_used`: Timestamp of last access
- `use_count`: Number of times accessed/executed

## Tips

1. **Use descriptive names** - Makes snippets easier to find and remember
2. **Tag consistently** - Use common tags like `git`, `docker`, `cleanup`, `dev` for easy filtering
3. **Backup regularly** - Use `export` to save your snippets periodically
4. **Combine with aliases** - Create shell aliases for frequently used snippets:
   ```bash
   alias snip='/path/to/snippets.sh'
   alias sr='/path/to/snippets.sh run'
   ```
