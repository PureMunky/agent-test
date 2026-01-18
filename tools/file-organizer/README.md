# File Organizer

A command-line tool for organizing files by type, date, or custom rules. Helps clean up cluttered directories like Downloads folders.

## Features

- **Scan directories** - Get a breakdown of files by category and size
- **Organize by type** - Move files into category folders (Images, Documents, Videos, etc.)
- **Organize by date** - Move files into YYYY/MM folder structure
- **Cleanup scan** - Find empty files, potential duplicates, and large files
- **Undo support** - Reverse the last organization operation
- **Customizable rules** - Edit category definitions and ignore patterns
- **Dry run mode** - Preview changes before applying them

## Installation

```bash
chmod +x file-organizer.sh
```

## Usage

### Scan a directory
```bash
./file-organizer.sh scan ~/Downloads
```

Output shows file counts and sizes by category:
```
=== File Scan: /home/user/Downloads ===

Files by Category:

  Images          42 files  (156MiB)
  Documents       23 files  (45MiB)
  Archives        12 files  (890MiB)
  Videos           5 files  (2.1GiB)
  Other            8 files  (12MiB)

Total: 90 files (3.2GiB)
```

### Organize by file type
```bash
# Preview changes first
./file-organizer.sh organize ~/Downloads --dry-run

# Apply organization
./file-organizer.sh organize ~/Downloads
```

This creates category folders and moves files:
```
Downloads/
├── Images/
│   ├── photo1.jpg
│   └── screenshot.png
├── Documents/
│   ├── report.pdf
│   └── notes.txt
├── Videos/
│   └── recording.mp4
└── Archives/
    └── backup.zip
```

### Organize by date
```bash
./file-organizer.sh by-date ~/Photos
```

Creates year/month folder structure:
```
Photos/
├── 2025/
│   ├── 11/
│   │   └── photo1.jpg
│   └── 12/
│       └── photo2.jpg
└── 2026/
    └── 01/
        └── photo3.jpg
```

### Find duplicates and cleanup opportunities
```bash
./file-organizer.sh cleanup ~/Downloads
```

Shows:
- Empty files
- Files with identical sizes (potential duplicates)
- Largest files in the directory

### Undo last operation
```bash
./file-organizer.sh undo
```

Reverses the most recent organize operation and removes empty directories it created.

### View operation history
```bash
./file-organizer.sh history
```

### View/edit organization rules
```bash
./file-organizer.sh rules
```

Rules are stored in `data/rules.json`. You can:
- Add new categories
- Change which extensions belong to which category
- Add patterns to ignore

## Default Categories

| Category    | Extensions                                           |
|-------------|------------------------------------------------------|
| Images      | jpg, jpeg, png, gif, bmp, svg, webp, ico, tiff, raw |
| Documents   | pdf, doc, docx, txt, rtf, odt, xls, xlsx, ppt, csv  |
| Videos      | mp4, avi, mkv, mov, wmv, flv, webm, m4v, mpeg       |
| Audio       | mp3, wav, flac, aac, ogg, wma, m4a, opus            |
| Archives    | zip, tar, gz, rar, 7z, bz2, xz, tgz                 |
| Code        | py, js, ts, java, c, cpp, h, go, rs, rb, php, sh    |
| Data        | json, xml, yaml, yml, toml, ini, cfg, conf          |
| Executables | exe, msi, dmg, app, deb, rpm, AppImage              |
| Fonts       | ttf, otf, woff, woff2, eot                          |

Files with unrecognized extensions go to "Other".

## Customizing Rules

Edit `data/rules.json`:

```json
{
    "categories": {
        "Images": ["jpg", "jpeg", "png", "gif"],
        "MyCustomCategory": ["xyz", "abc"]
    },
    "ignore_patterns": [
        ".*",
        "node_modules",
        "__pycache__"
    ]
}
```

## Requirements

- bash 4.0+
- jq (JSON processor)
- Standard Unix utilities (find, stat, mv)

## Safety Features

- **Dry run mode** - Always preview before organizing
- **Undo support** - Easily reverse operations
- **No deletions** - Only moves files, never deletes
- **Conflict handling** - Renames files if destination exists
- **Ignore patterns** - Skips hidden files and common development directories

## License

MIT
