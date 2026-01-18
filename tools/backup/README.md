# Backup

A simple backup utility for important files, directories, and productivity suite data.

## Features

- Add any file or directory to your backup list
- Create compressed tar.gz backups with custom names
- Restore from previous backups
- View backup history with sizes
- Prune old backups to save space
- Special "suite" mode to backup all productivity tool data at once

## Usage

```bash
# Add files/directories to backup list
./backup.sh add ~/.bashrc
./backup.sh add ~/Documents
./backup.sh add ~/.config/myapp

# View configured sources
./backup.sh list

# Remove a source by ID
./backup.sh remove 1

# Create a backup
./backup.sh run                    # Auto-named with timestamp
./backup.sh run weekly-backup      # Custom name

# Backup all productivity suite tool data
./backup.sh suite

# View backup history
./backup.sh history

# Restore from a backup (by backup ID from history)
./backup.sh restore 1737209145

# Clean up old backups
./backup.sh prune          # Remove backups older than 30 days
./backup.sh prune 7        # Remove backups older than 7 days
```

## Commands

| Command | Description |
|---------|-------------|
| `add <path>` | Add a file or directory to backup sources |
| `remove <id>` | Remove a source from the backup list |
| `list` | Show all configured backup sources |
| `run [name]` | Create a backup archive |
| `restore <id>` | Restore files from a backup |
| `history` | Show all previous backups |
| `prune [days]` | Remove backups older than N days |
| `suite` | Backup all productivity suite tool data |
| `help` | Show help information |

## Suite Backup

The `suite` command is a convenient way to backup all data from every tool in the productivity suite. It automatically finds and backs up the `data/` directory from each tool, preserving all your:

- Tasks and todos
- Notes and journal entries
- Habit tracking data
- Time logs
- Bookmarks
- Snippets
- And more...

## Backup Location

All backups are stored in `tools/backup/data/backups/` as compressed tar.gz archives.

## Requirements

- `jq` - JSON processor for managing source and history files
- `tar` - For creating compressed archives
