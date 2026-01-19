# Batch File Renamer

A powerful command-line tool for renaming multiple files with patterns, find/replace, numbering, case changes, and more.

## Features

- **Preview Mode**: All operations run in preview mode by default for safety
- **Find/Replace**: Replace text patterns in filenames
- **Prefix/Suffix**: Add text before or after filenames
- **Sequential Numbering**: Add configurable numbers (001_, 002_, ...)
- **Date Prefix**: Add file modification date to filenames
- **Case Conversion**: Convert to lowercase or UPPERCASE
- **Space Handling**: Replace spaces with underscores or custom characters
- **Character Stripping**: Remove unwanted characters from filenames
- **Extension Changes**: Bulk change file extensions
- **Undo Support**: Revert the last rename operation
- **History Tracking**: View past rename operations

## Installation

No installation required. Run directly:

```bash
./rename.sh help
```

Or add to your PATH:

```bash
ln -s /path/to/rename.sh ~/bin/rename
```

## Usage

```bash
rename.sh <command> [options] [directory]
```

All commands run in **preview mode** by default. Add `--apply` to actually rename files.

## Commands

### Find and Replace

Replace text patterns in filenames:

```bash
# Preview changes
rename.sh replace "IMG_" "photo_" ~/Photos

# Apply changes
rename.sh replace "IMG_" "photo_" ~/Photos --apply
```

### Add Prefix

Add prefix to all filenames:

```bash
rename.sh prefix "backup_" ~/Documents
rename.sh prefix "2024_" ~/Reports --apply
```

### Add Suffix

Add suffix before the file extension:

```bash
rename.sh suffix "_final" ~/Documents
rename.sh suffix "_v2" ~/Projects --apply
```

### Sequential Numbering

Add sequential numbers to filenames:

```bash
# Default: 001_filename.ext, 002_filename.ext, ...
rename.sh number ~/Photos

# Custom options
rename.sh number ~/Photos --start 1 --padding 4 --apply
# Result: 0001_filename.ext, 0002_filename.ext, ...

# Numbers as suffix
rename.sh number ~/Files --position suffix
# Result: filename_001.ext, filename_002.ext, ...
```

### Date Prefix

Add file modification date as prefix:

```bash
# Default format: YYYY-MM-DD
rename.sh date ~/Photos
# Result: 2024-01-15_photo.jpg

# Custom format
rename.sh date ~/Photos --format "%Y%m%d" --apply
# Result: 20240115_photo.jpg
```

### Case Conversion

Convert filenames to lowercase or UPPERCASE:

```bash
rename.sh lower ~/Downloads
rename.sh upper ~/Documents --apply
```

### Replace Spaces

Replace spaces with underscores (or custom character):

```bash
# Replace with underscore (default)
rename.sh spaces ~/Downloads

# Replace with hyphen
rename.sh spaces ~/Downloads --char "-" --apply
```

### Strip Characters

Remove specific characters from filenames:

```bash
# Remove parentheses and brackets
rename.sh strip "()[]" ~/Downloads

# Remove special characters
rename.sh strip "#@!" ~/Files --apply
```

### Change Extension

Bulk change file extensions:

```bash
rename.sh ext txt ~/Documents
rename.sh ext jpg ~/Images --apply
```

### Undo

Revert the last rename operation:

```bash
rename.sh undo
```

### History

View past rename operations:

```bash
rename.sh history
```

## Options

| Option | Description |
|--------|-------------|
| `--apply`, `-a` | Apply changes (default is preview) |
| `--start <n>` | Starting number for 'number' command |
| `--padding <n>` | Digit padding for 'number' (default: 3) |
| `--position <prefix\|suffix>` | Number position (default: prefix) |
| `--format <fmt>` | Date format for 'date' command |
| `--char <c>` | Replacement character for 'spaces' |

## Examples

### Organize Photo Collection

```bash
# Preview: Add date prefix from file metadata
rename.sh date ~/Photos

# Preview: Replace camera prefix
rename.sh replace "DSC_" "vacation_" ~/Photos

# Apply both operations
rename.sh date ~/Photos --apply
rename.sh replace "DSC_" "vacation_" ~/Photos --apply
```

### Clean Up Downloads

```bash
# Preview: Remove spaces and convert to lowercase
rename.sh spaces ~/Downloads
rename.sh lower ~/Downloads

# Apply changes
rename.sh spaces ~/Downloads --apply
rename.sh lower ~/Downloads --apply
```

### Batch Rename Project Files

```bash
# Add version suffix to all files
rename.sh suffix "_v2" ~/project/assets --apply

# Rename with sequential numbers
rename.sh number ~/project/chapters --padding 2 --apply
```

## Safety Features

1. **Preview by Default**: All operations show what would happen without making changes
2. **No Overwrites**: Will not rename if destination file already exists
3. **Undo Support**: Can revert the last operation
4. **History Tracking**: All operations are logged

## Requirements

- Bash 4.0+
- jq (for history/undo features)

## Data Storage

- History file: `tools/rename/data/history.json`

## Related Tools

- **file-organizer**: Organize files into directories by type or date
- **backup**: Backup important files and directories
