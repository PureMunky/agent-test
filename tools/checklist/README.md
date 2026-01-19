# Checklist

A reusable checklist manager for common workflows and repetitive processes.

## What Makes This Different

Unlike **tasks** (one-off items to complete) or **habits** (daily recurring activities), checklists are **reusable templates** that you check off and reset. They're perfect for:

- Code review checklists
- Pre-deployment verification
- Pull request submission
- Morning routines
- Project setup processes
- Meeting preparation

## Quick Start

```bash
# Create from a built-in template
./checklist.sh use-template code-review

# Or create your own
./checklist.sh new "My Checklist" -d "Optional description"

# Add items
./checklist.sh add "My Checklist" "First thing to check"
./checklist.sh add "My Checklist" "Second item"

# Run through interactively
./checklist.sh run "My Checklist"

# Or check items individually
./checklist.sh check "My Checklist" 1

# Reset for next use
./checklist.sh reset "My Checklist"
```

## Commands

### Creating & Managing Checklists

| Command | Description |
|---------|-------------|
| `checklist.sh new "name" [-d "desc"]` | Create a new checklist |
| `checklist.sh add "name" "item"` | Add an item to a checklist |
| `checklist.sh remove "name" <n>` | Remove item #n |
| `checklist.sh copy "src" "dest"` | Copy checklist as new template |
| `checklist.sh delete "name"` | Delete a checklist |

### Using Checklists

| Command | Description |
|---------|-------------|
| `checklist.sh show "name"` | Show checklist with progress |
| `checklist.sh check "name" <n>` | Toggle check on item #n |
| `checklist.sh run "name"` | Interactive walkthrough |
| `checklist.sh reset "name"` | Uncheck all items |
| `checklist.sh list` | List all checklists |

### Templates

| Command | Description |
|---------|-------------|
| `checklist.sh templates` | Show available templates |
| `checklist.sh use-template <name>` | Create from template |

Available templates:
- `code-review` - Standard code review checklist
- `deployment` - Pre-deployment verification
- `pr-checklist` - Pull request submission
- `morning-routine` - Daily startup routine
- `project-setup` - New project initialization
- `meeting-prep` - Meeting preparation

### Import/Export

| Command | Description |
|---------|-------------|
| `checklist.sh export "name" [file]` | Export to markdown |
| `checklist.sh import <file>` | Import from markdown |
| `checklist.sh history [name]` | Show completion history |

## Examples

### Code Review Workflow

```bash
# Create from template
./checklist.sh use-template code-review

# Run through for each PR
./checklist.sh run "code-review"

# Reset for next review
./checklist.sh reset "code-review"
```

### Custom Deployment Checklist

```bash
# Create custom checklist
./checklist.sh new "Production Deploy" -d "Steps for prod deployment"

# Add your specific items
./checklist.sh add "Production Deploy" "Run integration tests"
./checklist.sh add "Production Deploy" "Notify #deployments channel"
./checklist.sh add "Production Deploy" "Check error rates post-deploy"

# Use it
./checklist.sh run "Production Deploy"
```

### Sharing Checklists

```bash
# Export to share with team
./checklist.sh export "code-review" code-review.md

# Team member imports
./checklist.sh import code-review.md
```

## Progress Tracking

Each checklist tracks:
- Current progress (items checked vs total)
- Number of times completed
- Last completion date

View with `checklist.sh show "name"` to see a visual progress bar.

## Data Storage

Checklists are stored in `data/checklists/` as JSON files. Completion history is tracked in `data/history.json`.

## Tips

1. **Use templates as starting points** - Customize them for your needs
2. **Reset after each use** - Keep checklists ready for next time
3. **Interactive mode is fastest** - Use `run` for quick walkthroughs
4. **Export important checklists** - Share with team or backup
5. **Partial names work** - `checklist.sh show code` finds "code-review"
