# Contacts

Professional networking and relationship manager for tracking contacts, interactions, and follow-ups.

## Features

- **Contact Management**: Store contact details including name, email, company, role, phone, LinkedIn
- **Interaction Logging**: Record every interaction with notes and timestamps
- **Follow-up Reminders**: Set follow-up dates with reasons, view overdue and upcoming follow-ups
- **Tagging System**: Organize contacts with custom tags for easy filtering
- **Stale Contact Detection**: Automatically identifies contacts you haven't reached out to recently
- **Search**: Full-text search across all contact fields
- **Export**: Export contacts to JSON or CSV format
- **Statistics**: View networking metrics and top tags/companies

## Installation

The tool requires `jq` for JSON processing:

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Adding Contacts

```bash
# Basic add
./contacts.sh add "Jane Smith"

# With full details
./contacts.sh add "Jane Smith" "jane@techcorp.com" "TechCorp" "CTO"
```

### Viewing Contacts

```bash
# List all contacts
./contacts.sh list

# Filter by tag
./contacts.sh list --tag vip

# Filter by company
./contacts.sh list --company TechCorp

# Show detailed info
./contacts.sh show "Jane Smith"

# Search across all fields
./contacts.sh search "engineer"
```

### Logging Interactions

```bash
# Log a meeting or conversation
./contacts.sh log "Jane Smith" "Met at conference, discussed Q2 partnership"

# This automatically updates the "last contact" date
```

### Managing Tags

```bash
# Add tags (comma-separated)
./contacts.sh tag "Jane Smith" "vip,partner,tech-industry"
```

### Follow-up Reminders

```bash
# Set a follow-up date
./contacts.sh followup "Jane Smith" "2026-02-15" "Send proposal document"

# View all due follow-ups
./contacts.sh due

# Clear a follow-up
./contacts.sh clear-followup "Jane Smith"
```

### Other Commands

```bash
# Edit contact in your default editor
./contacts.sh edit "Jane Smith"

# View networking statistics
./contacts.sh stats

# Export to CSV
./contacts.sh export --format csv > contacts.csv

# Export to JSON
./contacts.sh export --format json > contacts.json

# Remove a contact
./contacts.sh remove "Jane Smith"
```

## Data Storage

Contacts are stored in `data/contacts.json` in the tool directory.

### Contact Schema

```json
{
  "id": 1,
  "name": "Jane Smith",
  "email": "jane@techcorp.com",
  "company": "TechCorp",
  "role": "CTO",
  "phone": "",
  "linkedin": "",
  "notes": "Key decision maker for enterprise deals",
  "tags": ["vip", "partner"],
  "interactions": [
    {"date": "2026-01-15", "note": "Met at conference"}
  ],
  "followup_date": "2026-02-15",
  "followup_reason": "Send proposal",
  "created": "2026-01-10 14:30:00",
  "last_contact": "2026-01-15"
}
```

## Tips

1. **Log interactions regularly**: Even brief notes help you remember context for future conversations
2. **Use tags strategically**: Create tags like `vip`, `mentor`, `recruiter`, `industry-tech` for easy filtering
3. **Set follow-ups**: Don't let important contacts go cold - set reminders for regular check-ins
4. **Review due list daily**: Run `./contacts.sh due` each morning to see who needs attention
5. **Check stale contacts**: The due command shows contacts you haven't talked to in 90+ days

## Integration Ideas

- Add to your morning routine with `daily-kickstart`
- Export contacts to sync with other tools
- Use with `reminders` tool for notification-based follow-ups
