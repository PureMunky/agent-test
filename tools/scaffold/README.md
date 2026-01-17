# Scaffold - Project Scaffolding Tool

A command-line tool for quickly creating new projects from templates. Stop writing the same boilerplate code and project structures over and over.

## Features

- 8 built-in templates for common project types
- Create custom templates for your own use cases
- Variable substitution for project name, author, year
- Post-create commands for setup tasks
- Configurable default author/email settings

## Installation

Make the script executable (if not already):

```bash
chmod +x scaffold.sh
```

Requires `jq` for JSON processing:
```bash
sudo apt install jq
```

## Usage

### Create a New Project

```bash
# Create in current directory
./scaffold.sh create python-cli my-tool

# Create in a specific location
./scaffold.sh create express-api my-api ~/projects
```

### List Available Templates

```bash
./scaffold.sh list
```

### Show Template Details

```bash
./scaffold.sh show python-package
```

## Built-in Templates

| Template | Description |
|----------|-------------|
| `bash-script` | Simple bash script project with help, colors, and error handling |
| `python-cli` | Python command-line application with argparse |
| `python-package` | Python package with setup.py, tests, and proper structure |
| `node-cli` | Node.js CLI application with package.json |
| `express-api` | Express.js REST API with health check and error handling |
| `html-page` | Simple HTML/CSS/JS page with modern defaults |
| `makefile-project` | Generic project with Makefile |
| `docker-service` | Docker service with docker-compose |

## Custom Templates

### Create a Custom Template

```bash
./scaffold.sh add my-template
```

This creates a JSON template file that you can edit.

### Template Format

Templates are JSON files with this structure:

```json
{
    "description": "My custom template",
    "files": {
        "main.py": "print('Hello {{PROJECT_NAME}}')\n",
        "README.md": "# {{PROJECT_NAME}}\n"
    },
    "directories": ["src", "tests"],
    "post_create": ["chmod +x main.py"]
}
```

### Available Variables

- `{{PROJECT_NAME}}` - Name of the project
- `{{AUTHOR}}` - Configured author name
- `{{YEAR}}` - Current year

### Configure Default Variables

```bash
./scaffold.sh config
```

This lets you set your author name, email, and GitHub username for use in templates.

## Commands

| Command | Description |
|---------|-------------|
| `create <template> <name> [path]` | Create a new project |
| `list` | List available templates |
| `show <template>` | Show template details |
| `add <name>` | Create a custom template |
| `edit <name>` | Edit a custom template |
| `remove <name>` | Delete a custom template |
| `config` | Configure default variables |
| `help` | Show help |

## Examples

```bash
# Create a Python CLI tool
./scaffold.sh create python-cli backup-tool

# Create an Express API in projects folder
./scaffold.sh create express-api my-api ~/projects

# Create a custom template
./scaffold.sh add flask-app

# Configure your author name
./scaffold.sh config
```

## License

MIT
