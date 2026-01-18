# Text Templates

Reusable text templates with variable substitution for emails, documentation, commit messages, and any repetitive text.

## Features

- Create and manage text templates with customizable variables
- Variable substitution with required and optional (default) values
- Built-in date/time variables
- Categories for organizing templates
- Search across template names and content
- Clipboard integration for quick use
- Import/export for sharing templates
- Usage tracking

## Installation

The tool requires `jq` for JSON processing:

```bash
sudo apt install jq
```

## Usage

### Create a Template

```bash
./templates.sh new email-reply
```

This opens your editor to create the template. Use `{{variable}}` syntax for placeholders.

### Template Syntax

```
Hi {{name}},

Thank you for your email about {{topic}}.

{{response}}

Best regards,
{{_user_}}
{{_date_}}
```

Variables:
- `{{variable}}` - Required, will prompt if not provided
- `{{variable:default}}` - Optional with default value
- `{{_date_}}` - Built-in: current date (YYYY-MM-DD)
- `{{_time_}}` - Built-in: current time (HH:MM)
- `{{_datetime_}}` - Built-in: date and time
- `{{_year_}}`, `{{_month_}}`, `{{_day_}}` - Built-in date parts
- `{{_user_}}` - Built-in: current username
- `{{_name_}}` - Built-in: template name

### Use a Template

```bash
# Interactive (prompts for missing variables)
./templates.sh use email-reply

# With variables
./templates.sh use email-reply name="John" topic="project update"

# Copy directly to clipboard
./templates.sh copy email-reply name="John" topic="project update"
```

### Manage Templates

```bash
# List all templates
./templates.sh list

# Show template content and variables
./templates.sh show email-reply

# See what variables a template needs
./templates.sh vars email-reply

# Edit a template
./templates.sh edit email-reply

# Delete a template
./templates.sh delete email-reply

# Search templates
./templates.sh search email
```

### Import/Export

```bash
# Export for sharing
./templates.sh export email-reply my-template.tpl

# Import from file
./templates.sh import my-template.tpl
./templates.sh import my-template.tpl custom-name
```

## Example Templates

### Commit Message

```
{{type}}({{scope:general}}): {{description}}

{{body:}}

{{footer:}}
```

Usage:
```bash
./templates.sh use commit-msg type="feat" scope="auth" description="add login"
```

### Email Reply

```
Hi {{name}},

Thank you for reaching out about {{topic}}.

{{response}}

Let me know if you have any questions.

Best regards,
{{_user_}}
```

### Bug Report

```
## Bug Report

**Date:** {{_date_}}
**Reporter:** {{_user_}}
**Severity:** {{severity:medium}}

### Description
{{description}}

### Steps to Reproduce
{{steps}}

### Expected Behavior
{{expected}}

### Actual Behavior
{{actual}}

### Environment
{{environment:Not specified}}
```

### Meeting Invite

```
Subject: {{meeting_type:Meeting}} - {{topic}}

Hi {{attendees}},

I'd like to schedule a {{meeting_type:meeting}} to discuss {{topic}}.

**Proposed Time:** {{time}}
**Duration:** {{duration:30 minutes}}
**Location:** {{location:Virtual}}

**Agenda:**
{{agenda}}

Please let me know if this works for you.

Best,
{{_user_}}
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `new <name>` | Create a new template |
| `edit <name>` | Edit an existing template |
| `use <name> [var=val ...]` | Generate text from template |
| `list` | List all templates |
| `show <name>` | Show template content |
| `delete <name>` | Delete a template |
| `vars <name>` | Show template variables |
| `copy <name> [var=val ...]` | Copy generated text to clipboard |
| `search <term>` | Search templates |
| `export <name> [file]` | Export template to file |
| `import <file> [name]` | Import template from file |
| `help` | Show help |

## Categories

Templates are organized by category:
- `email` - Email templates and responses
- `code` - Code-related templates (comments, headers)
- `docs` - Documentation templates
- `commit` - Git commit messages
- `other` - Everything else

## Tips

1. **Use defaults wisely** - Add defaults for commonly used values
2. **Leverage built-ins** - Use `{{_date_}}` and `{{_user_}}` for automatic values
3. **Organize by category** - Makes finding templates easier
4. **Export and share** - Team templates can be imported by everyone
