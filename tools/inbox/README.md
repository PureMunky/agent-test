# Inbox

A GTD-style capture and processing inbox for quickly collecting items that need attention.

## Purpose

The inbox serves as a central collection point for all incoming items - ideas, tasks, reminders, or anything that needs processing later. The key principle is: **capture quickly, process later**.

This helps ensure nothing falls through the cracks by providing:
- Quick capture without context switching
- A processing workflow to handle items appropriately
- Zero-inbox goal tracking
- Priority and deferral support

## Installation

The inbox tool requires `jq` for JSON processing:

```bash
sudo apt install jq
```

## Usage

### Quick Capture

```bash
# Add an item to your inbox
./inbox.sh add "Review quarterly report"
./inbox.sh add "Call dentist to schedule appointment"

# Quick shorthand
./inbox.sh + "Research vacation destinations"

# Pipe input
echo "Great idea I just had" | ./inbox.sh add
```

### View Inbox

```bash
# Show active items to process
./inbox.sh list

# Show all items including deferred
./inbox.sh list --all

# Just run with no args
./inbox.sh
```

### Process Items

The interactive processing workflow helps you decide what to do with each item:

```bash
./inbox.sh process 5
```

Options when processing:
- **Done** - Mark as processed and remove
- **Task** - Convert to a task (integrates with tasks tool)
- **Note** - Save as a note (integrates with quicknotes)
- **Defer** - Defer until a later date
- **Priority** - Set priority level
- **Skip** - Leave in inbox for now
- **Delete** - Remove without processing

### Priority Levels

```bash
# Set priority (1=high, 2=medium, 3=low)
./inbox.sh priority 3 1   # Set item #3 to high priority
./inbox.sh priority 7 2   # Set item #7 to medium priority
```

Priority display:
- `!!!` = High priority (red)
- `!!` = Medium priority (yellow)
- `!` = Low priority (gray)

### Deferring Items

Defer items you can't or don't want to process right now:

```bash
# Defer to tomorrow (default)
./inbox.sh defer 5

# Defer N days
./inbox.sh defer 5 +7     # Defer 7 days

# Defer to specific date
./inbox.sh defer 5 2026-02-01
```

Deferred items won't appear in your active list until the defer date arrives.

### Tags

Organize items with tags:

```bash
./inbox.sh tag 3 "work"
./inbox.sh tag 3 "urgent"
```

### Search

```bash
./inbox.sh search "meeting"
./inbox.sh search "budget"
```

### Statistics

```bash
./inbox.sh stats
```

Shows:
- Active/deferred/processed counts
- Priority breakdown
- Item age distribution
- All-time processed count

### Maintenance

```bash
# Mark item as done
./inbox.sh done 5

# Delete an item
./inbox.sh delete 3

# Clear all processed items
./inbox.sh clear-done
```

## GTD Workflow

The inbox follows Getting Things Done (GTD) principles:

1. **Capture** - Quickly add anything to your inbox without judgment
2. **Clarify** - Process each item to decide what it is and what to do
3. **Organize** - Move items to appropriate lists (tasks, notes, calendar)
4. **Review** - Regularly review your inbox to keep it at zero
5. **Engage** - Work from your organized lists, not your inbox

## Integration

The inbox integrates with other productivity tools:

- **tasks** - Convert inbox items to tasks
- **quicknotes** - Save items as notes

When processing an item, you can automatically move it to these tools.

## Data Storage

Data is stored in `data/inbox.json` with the following structure:

```json
{
  "items": [
    {
      "id": 1,
      "content": "Item description",
      "created": "2026-01-18 10:30",
      "priority": 1,
      "tags": ["work"],
      "deferred_until": null,
      "processed": false
    }
  ],
  "next_id": 2,
  "processed_count": 0
}
```

## Tips

- **Capture everything** - Don't try to organize while capturing
- **Process regularly** - Aim for inbox zero daily
- **Use priorities sparingly** - Not everything is high priority
- **Defer aggressively** - If you can't do it now, defer it
- **Review weekly** - Check deferred items and stale entries
