#!/bin/bash
#
# Scaffold - Project scaffolding and template generator
#
# Usage:
#   scaffold.sh create <template> <project-name> [path]   - Create a new project from template
#   scaffold.sh list                                       - List available templates
#   scaffold.sh show <template>                            - Show template details
#   scaffold.sh add <template-name>                        - Create a new custom template
#   scaffold.sh edit <template-name>                       - Edit a custom template
#   scaffold.sh remove <template-name>                     - Remove a custom template
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
TEMPLATES_DIR="$DATA_DIR/templates"
CONFIG_FILE="$DATA_DIR/config.json"

mkdir -p "$TEMPLATES_DIR"

# Initialize config if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"custom_templates":[],"variables":{"author":"","email":"","github_username":""}}' > "$CONFIG_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

# Built-in templates
get_template_files() {
    local template="$1"
    local project_name="$2"
    local year=$(date +%Y)

    case "$template" in
        bash-script)
            cat << 'EOF'
{
    "files": {
        "{{PROJECT_NAME}}.sh": "#!/bin/bash\n#\n# {{PROJECT_NAME}} - Description\n#\n# Usage:\n#   ./{{PROJECT_NAME}}.sh [options]\n#\n\nset -euo pipefail\n\n# Configuration\nSCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"\n\n# Colors\nRED='\\033[0;31m'\nGREEN='\\033[0;32m'\nYELLOW='\\033[1;33m'\nNC='\\033[0m'\n\nshow_help() {\n    echo \"{{PROJECT_NAME}} - Description\"\n    echo \"\"\n    echo \"Usage:\"\n    echo \"  ./{{PROJECT_NAME}}.sh [options]\"\n    echo \"\"\n    echo \"Options:\"\n    echo \"  -h, --help     Show this help\"\n}\n\nmain() {\n    case \"${1:-}\" in\n        -h|--help)\n            show_help\n            ;;\n        *)\n            echo \"Hello from {{PROJECT_NAME}}!\"\n            ;;\n    esac\n}\n\nmain \"$@\"\n",
        "README.md": "# {{PROJECT_NAME}}\n\nA bash script for...\n\n## Installation\n\n```bash\nchmod +x {{PROJECT_NAME}}.sh\n```\n\n## Usage\n\n```bash\n./{{PROJECT_NAME}}.sh [options]\n```\n\n## License\n\nMIT\n",
        ".gitignore": "# Logs\n*.log\n\n# Data files\ndata/\n\n# Temp files\n*.tmp\n*~\n"
    },
    "description": "Simple bash script project",
    "post_create": ["chmod +x {{PROJECT_NAME}}.sh"]
}
EOF
            ;;

        python-cli)
            cat << 'EOF'
{
    "files": {
        "{{PROJECT_NAME}}.py": "#!/usr/bin/env python3\n\"\"\"\n{{PROJECT_NAME}} - Description\n\nUsage:\n    python {{PROJECT_NAME}}.py [options]\n\"\"\"\n\nimport argparse\nimport sys\n\n\ndef main():\n    parser = argparse.ArgumentParser(description='{{PROJECT_NAME}}')\n    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')\n    args = parser.parse_args()\n\n    print(f'Hello from {{PROJECT_NAME}}!')\n    return 0\n\n\nif __name__ == '__main__':\n    sys.exit(main())\n",
        "README.md": "# {{PROJECT_NAME}}\n\nA Python CLI tool for...\n\n## Installation\n\n```bash\npip install -r requirements.txt\n```\n\n## Usage\n\n```bash\npython {{PROJECT_NAME}}.py [options]\n```\n\n## License\n\nMIT\n",
        "requirements.txt": "# Add your dependencies here\n",
        ".gitignore": "# Python\n__pycache__/\n*.py[cod]\n*$py.class\n*.so\n.Python\nvenv/\n.venv/\nENV/\n\n# IDE\n.vscode/\n.idea/\n*.swp\n*~\n\n# Logs\n*.log\n"
    },
    "description": "Python command-line application",
    "post_create": ["chmod +x {{PROJECT_NAME}}.py"]
}
EOF
            ;;

        python-package)
            cat << 'EOF'
{
    "files": {
        "{{PROJECT_NAME}}/__init__.py": "\"\"\"\n{{PROJECT_NAME}} - Description\n\"\"\"\n\n__version__ = '0.1.0'\n__author__ = '{{AUTHOR}}'\n",
        "{{PROJECT_NAME}}/main.py": "\"\"\"\nMain module for {{PROJECT_NAME}}\n\"\"\"\n\n\ndef main():\n    \"\"\"Entry point.\"\"\"\n    print('Hello from {{PROJECT_NAME}}!')\n\n\nif __name__ == '__main__':\n    main()\n",
        "tests/__init__.py": "",
        "tests/test_main.py": "\"\"\"Tests for {{PROJECT_NAME}}\"\"\"\n\nimport unittest\nfrom {{PROJECT_NAME}} import main\n\n\nclass TestMain(unittest.TestCase):\n    def test_placeholder(self):\n        self.assertTrue(True)\n\n\nif __name__ == '__main__':\n    unittest.main()\n",
        "setup.py": "from setuptools import setup, find_packages\n\nwith open('README.md', 'r') as f:\n    long_description = f.read()\n\nsetup(\n    name='{{PROJECT_NAME}}',\n    version='0.1.0',\n    author='{{AUTHOR}}',\n    description='Description',\n    long_description=long_description,\n    long_description_content_type='text/markdown',\n    packages=find_packages(),\n    python_requires='>=3.8',\n    install_requires=[],\n    entry_points={\n        'console_scripts': [\n            '{{PROJECT_NAME}}={{PROJECT_NAME}}.main:main',\n        ],\n    },\n)\n",
        "README.md": "# {{PROJECT_NAME}}\n\nDescription\n\n## Installation\n\n```bash\npip install -e .\n```\n\n## Usage\n\n```python\nfrom {{PROJECT_NAME}} import main\nmain.main()\n```\n\n## Development\n\n```bash\npython -m pytest tests/\n```\n\n## License\n\nMIT\n",
        "requirements.txt": "# Development dependencies\npytest>=7.0\n",
        ".gitignore": "# Python\n__pycache__/\n*.py[cod]\n*$py.class\n*.so\n.Python\ndist/\nbuild/\n*.egg-info/\nvenv/\n.venv/\n\n# IDE\n.vscode/\n.idea/\n*.swp\n\n# Testing\n.pytest_cache/\n.coverage\nhtmlcov/\n"
    },
    "directories": ["{{PROJECT_NAME}}", "tests"],
    "description": "Python package with setup.py and tests",
    "post_create": []
}
EOF
            ;;

        node-cli)
            cat << 'EOF'
{
    "files": {
        "index.js": "#!/usr/bin/env node\n\n/**\n * {{PROJECT_NAME}}\n * Description\n */\n\nconst args = process.argv.slice(2);\n\nfunction main() {\n    if (args.includes('--help') || args.includes('-h')) {\n        console.log('{{PROJECT_NAME}} - Description');\n        console.log('');\n        console.log('Usage:');\n        console.log('  node index.js [options]');\n        console.log('');\n        console.log('Options:');\n        console.log('  -h, --help     Show this help');\n        process.exit(0);\n    }\n\n    console.log('Hello from {{PROJECT_NAME}}!');\n}\n\nmain();\n",
        "package.json": "{\n  \"name\": \"{{PROJECT_NAME}}\",\n  \"version\": \"1.0.0\",\n  \"description\": \"Description\",\n  \"main\": \"index.js\",\n  \"bin\": {\n    \"{{PROJECT_NAME}}\": \"./index.js\"\n  },\n  \"scripts\": {\n    \"start\": \"node index.js\",\n    \"test\": \"echo \\\"Error: no test specified\\\" && exit 1\"\n  },\n  \"keywords\": [],\n  \"author\": \"{{AUTHOR}}\",\n  \"license\": \"MIT\"\n}\n",
        "README.md": "# {{PROJECT_NAME}}\n\nDescription\n\n## Installation\n\n```bash\nnpm install\n```\n\n## Usage\n\n```bash\nnode index.js [options]\n```\n\n## License\n\nMIT\n",
        ".gitignore": "node_modules/\nnpm-debug.log\n*.log\n.env\n"
    },
    "description": "Node.js CLI application",
    "post_create": ["chmod +x index.js"]
}
EOF
            ;;

        express-api)
            cat << 'EOF'
{
    "files": {
        "index.js": "const express = require('express');\n\nconst app = express();\nconst PORT = process.env.PORT || 3000;\n\napp.use(express.json());\n\n// Health check\napp.get('/health', (req, res) => {\n    res.json({ status: 'ok', timestamp: new Date().toISOString() });\n});\n\n// API routes\napp.get('/api', (req, res) => {\n    res.json({ message: 'Welcome to {{PROJECT_NAME}} API' });\n});\n\n// 404 handler\napp.use((req, res) => {\n    res.status(404).json({ error: 'Not found' });\n});\n\n// Error handler\napp.use((err, req, res, next) => {\n    console.error(err.stack);\n    res.status(500).json({ error: 'Internal server error' });\n});\n\napp.listen(PORT, () => {\n    console.log(`{{PROJECT_NAME}} running on http://localhost:${PORT}`);\n});\n",
        "package.json": "{\n  \"name\": \"{{PROJECT_NAME}}\",\n  \"version\": \"1.0.0\",\n  \"description\": \"Express API\",\n  \"main\": \"index.js\",\n  \"scripts\": {\n    \"start\": \"node index.js\",\n    \"dev\": \"node --watch index.js\"\n  },\n  \"dependencies\": {\n    \"express\": \"^4.18.0\"\n  },\n  \"author\": \"{{AUTHOR}}\",\n  \"license\": \"MIT\"\n}\n",
        "README.md": "# {{PROJECT_NAME}}\n\nExpress.js REST API\n\n## Setup\n\n```bash\nnpm install\n```\n\n## Run\n\n```bash\nnpm start\n# or for development\nnpm run dev\n```\n\n## API Endpoints\n\n- `GET /health` - Health check\n- `GET /api` - API info\n\n## License\n\nMIT\n",
        ".gitignore": "node_modules/\nnpm-debug.log\n*.log\n.env\n",
        ".env.example": "PORT=3000\n"
    },
    "description": "Express.js REST API starter",
    "post_create": []
}
EOF
            ;;

        html-page)
            cat << 'EOF'
{
    "files": {
        "index.html": "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"UTF-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n    <title>{{PROJECT_NAME}}</title>\n    <link rel=\"stylesheet\" href=\"styles.css\">\n</head>\n<body>\n    <header>\n        <h1>{{PROJECT_NAME}}</h1>\n    </header>\n    <main>\n        <p>Welcome to {{PROJECT_NAME}}!</p>\n    </main>\n    <footer>\n        <p>&copy; {{YEAR}} {{AUTHOR}}</p>\n    </footer>\n    <script src=\"script.js\"></script>\n</body>\n</html>\n",
        "styles.css": "/* Reset */\n* {\n    margin: 0;\n    padding: 0;\n    box-sizing: border-box;\n}\n\n/* Base styles */\nbody {\n    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;\n    line-height: 1.6;\n    color: #333;\n    max-width: 1200px;\n    margin: 0 auto;\n    padding: 2rem;\n}\n\nheader {\n    margin-bottom: 2rem;\n}\n\nh1 {\n    color: #2c3e50;\n}\n\nmain {\n    min-height: 60vh;\n}\n\nfooter {\n    margin-top: 2rem;\n    padding-top: 1rem;\n    border-top: 1px solid #eee;\n    color: #666;\n    font-size: 0.9rem;\n}\n",
        "script.js": "// {{PROJECT_NAME}} JavaScript\n\ndocument.addEventListener('DOMContentLoaded', () => {\n    console.log('{{PROJECT_NAME}} loaded');\n});\n",
        "README.md": "# {{PROJECT_NAME}}\n\nA simple HTML page.\n\n## Usage\n\nOpen `index.html` in your browser.\n\n## License\n\nMIT\n"
    },
    "description": "Simple HTML/CSS/JS page",
    "post_create": []
}
EOF
            ;;

        makefile-project)
            cat << 'EOF'
{
    "files": {
        "Makefile": ".PHONY: all build clean test help\n\nPROJECT := {{PROJECT_NAME}}\nVERSION := 0.1.0\n\nall: build\n\nbuild:\n\t@echo \"Building $(PROJECT)...\"\n\t@echo \"Done.\"\n\ntest:\n\t@echo \"Running tests...\"\n\t@echo \"All tests passed.\"\n\nclean:\n\t@echo \"Cleaning...\"\n\t@rm -rf build/ dist/\n\t@echo \"Done.\"\n\nhelp:\n\t@echo \"{{PROJECT_NAME}} Makefile\"\n\t@echo \"\"\n\t@echo \"Targets:\"\n\t@echo \"  build   Build the project\"\n\t@echo \"  test    Run tests\"\n\t@echo \"  clean   Clean build artifacts\"\n\t@echo \"  help    Show this help\"\n",
        "README.md": "# {{PROJECT_NAME}}\n\nDescription\n\n## Build\n\n```bash\nmake build\n```\n\n## Test\n\n```bash\nmake test\n```\n\n## Clean\n\n```bash\nmake clean\n```\n\n## License\n\nMIT\n",
        ".gitignore": "build/\ndist/\n*.o\n*.a\n*.so\n*~\n"
    },
    "description": "Project with Makefile",
    "post_create": []
}
EOF
            ;;

        docker-service)
            cat << 'EOF'
{
    "files": {
        "Dockerfile": "FROM python:3.11-slim\n\nWORKDIR /app\n\nCOPY requirements.txt .\nRUN pip install --no-cache-dir -r requirements.txt\n\nCOPY . .\n\nEXPOSE 8000\n\nCMD [\"python\", \"app.py\"]\n",
        "docker-compose.yml": "version: '3.8'\n\nservices:\n  {{PROJECT_NAME}}:\n    build: .\n    ports:\n      - \"8000:8000\"\n    environment:\n      - DEBUG=false\n    volumes:\n      - ./data:/app/data\n    restart: unless-stopped\n",
        "app.py": "#!/usr/bin/env python3\n\"\"\"{{PROJECT_NAME}} service\"\"\"\n\nfrom http.server import HTTPServer, SimpleHTTPRequestHandler\nimport json\n\nclass Handler(SimpleHTTPRequestHandler):\n    def do_GET(self):\n        if self.path == '/health':\n            self.send_response(200)\n            self.send_header('Content-type', 'application/json')\n            self.end_headers()\n            self.wfile.write(json.dumps({'status': 'ok'}).encode())\n        else:\n            self.send_response(200)\n            self.send_header('Content-type', 'text/plain')\n            self.end_headers()\n            self.wfile.write(b'Hello from {{PROJECT_NAME}}!')\n\nif __name__ == '__main__':\n    server = HTTPServer(('0.0.0.0', 8000), Handler)\n    print('{{PROJECT_NAME}} running on http://0.0.0.0:8000')\n    server.serve_forever()\n",
        "requirements.txt": "# Add dependencies here\n",
        "README.md": "# {{PROJECT_NAME}}\n\nDocker-based service.\n\n## Build\n\n```bash\ndocker-compose build\n```\n\n## Run\n\n```bash\ndocker-compose up\n```\n\n## Stop\n\n```bash\ndocker-compose down\n```\n\n## License\n\nMIT\n",
        ".gitignore": "data/\n*.log\n.env\n",
        ".dockerignore": ".git\n.gitignore\nREADME.md\ndata/\n*.log\n"
    },
    "directories": ["data"],
    "description": "Docker service with docker-compose",
    "post_create": []
}
EOF
            ;;

        *)
            echo "{}"
            ;;
    esac
}

# List available templates
list_templates() {
    echo -e "${BLUE}=== Available Templates ===${NC}"
    echo ""
    echo -e "${YELLOW}Built-in templates:${NC}"
    echo ""
    printf "  ${GREEN}%-18s${NC} %s\n" "bash-script" "Simple bash script project"
    printf "  ${GREEN}%-18s${NC} %s\n" "python-cli" "Python command-line application"
    printf "  ${GREEN}%-18s${NC} %s\n" "python-package" "Python package with setup.py and tests"
    printf "  ${GREEN}%-18s${NC} %s\n" "node-cli" "Node.js CLI application"
    printf "  ${GREEN}%-18s${NC} %s\n" "express-api" "Express.js REST API starter"
    printf "  ${GREEN}%-18s${NC} %s\n" "html-page" "Simple HTML/CSS/JS page"
    printf "  ${GREEN}%-18s${NC} %s\n" "makefile-project" "Project with Makefile"
    printf "  ${GREEN}%-18s${NC} %s\n" "docker-service" "Docker service with docker-compose"

    # List custom templates
    local custom=$(jq -r '.custom_templates[]' "$CONFIG_FILE" 2>/dev/null)

    if [[ -n "$custom" ]]; then
        echo ""
        echo -e "${YELLOW}Custom templates:${NC}"
        echo ""
        while IFS= read -r name; do
            if [[ -f "$TEMPLATES_DIR/$name.json" ]]; then
                local desc=$(jq -r '.description // "Custom template"' "$TEMPLATES_DIR/$name.json")
                printf "  ${MAGENTA}%-18s${NC} %s\n" "$name" "$desc"
            fi
        done <<< "$custom"
    fi

    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  scaffold.sh create <template> <project-name> [path]"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  scaffold.sh create python-cli my-tool"
    echo "  scaffold.sh create bash-script backup-script ~/projects"
}

# Show template details
show_template() {
    local template="$1"

    if [[ -z "$template" ]]; then
        echo "Usage: scaffold.sh show <template>"
        exit 1
    fi

    local template_json=""

    # Check for custom template
    if [[ -f "$TEMPLATES_DIR/$template.json" ]]; then
        template_json=$(cat "$TEMPLATES_DIR/$template.json")
    else
        template_json=$(get_template_files "$template" "example")
    fi

    if [[ -z "$template_json" ]] || [[ "$template_json" == "{}" ]]; then
        echo -e "${RED}Template '$template' not found${NC}"
        echo ""
        echo "Run 'scaffold.sh list' to see available templates."
        exit 1
    fi

    local desc=$(echo "$template_json" | jq -r '.description // "No description"')

    echo -e "${BLUE}=== Template: $template ===${NC}"
    echo ""
    echo -e "${CYAN}Description:${NC} $desc"
    echo ""
    echo -e "${YELLOW}Files created:${NC}"
    echo "$template_json" | jq -r '.files | keys[]' | while read file; do
        echo "  - $file"
    done

    local dirs=$(echo "$template_json" | jq -r '.directories // [] | .[]' 2>/dev/null)
    if [[ -n "$dirs" ]]; then
        echo ""
        echo -e "${YELLOW}Directories:${NC}"
        echo "$dirs" | while read dir; do
            echo "  - $dir/"
        done
    fi

    local post=$(echo "$template_json" | jq -r '.post_create // [] | .[]' 2>/dev/null)
    if [[ -n "$post" ]]; then
        echo ""
        echo -e "${YELLOW}Post-create commands:${NC}"
        echo "$post" | while read cmd; do
            echo "  - $cmd"
        done
    fi
}

# Create project from template
create_project() {
    local template="$1"
    local project_name="$2"
    local target_path="${3:-.}"

    if [[ -z "$template" ]] || [[ -z "$project_name" ]]; then
        echo "Usage: scaffold.sh create <template> <project-name> [path]"
        echo ""
        echo "Run 'scaffold.sh list' to see available templates."
        exit 1
    fi

    # Validate project name (alphanumeric, hyphens, underscores)
    if ! [[ "$project_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        echo -e "${RED}Invalid project name.${NC}"
        echo "Name must start with a letter and contain only letters, numbers, hyphens, and underscores."
        exit 1
    fi

    # Get template JSON
    local template_json=""
    if [[ -f "$TEMPLATES_DIR/$template.json" ]]; then
        template_json=$(cat "$TEMPLATES_DIR/$template.json")
    else
        template_json=$(get_template_files "$template" "$project_name")
    fi

    if [[ -z "$template_json" ]] || [[ "$template_json" == "{}" ]]; then
        echo -e "${RED}Template '$template' not found${NC}"
        echo ""
        echo "Run 'scaffold.sh list' to see available templates."
        exit 1
    fi

    # Determine project directory
    local project_dir="$target_path/$project_name"

    # Check if directory already exists
    if [[ -d "$project_dir" ]]; then
        echo -e "${YELLOW}Directory already exists:${NC} $project_dir"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    # Create project directory
    mkdir -p "$project_dir"

    echo -e "${GREEN}Creating project:${NC} $project_name"
    echo -e "${CYAN}Template:${NC} $template"
    echo -e "${CYAN}Location:${NC} $project_dir"
    echo ""

    # Get variables for substitution
    local author=$(jq -r '.variables.author // ""' "$CONFIG_FILE")
    local year=$(date +%Y)

    # Create directories
    local dirs=$(echo "$template_json" | jq -r '.directories // [] | .[]' 2>/dev/null)
    if [[ -n "$dirs" ]]; then
        while IFS= read -r dir; do
            local actual_dir="${dir//\{\{PROJECT_NAME\}\}/$project_name}"
            mkdir -p "$project_dir/$actual_dir"
            echo -e "  ${CYAN}Created:${NC} $actual_dir/"
        done <<< "$dirs"
    fi

    # Create files
    echo "$template_json" | jq -r '.files | to_entries[] | @base64' | while read entry; do
        local filename=$(echo "$entry" | base64 -d | jq -r '.key')
        local content=$(echo "$entry" | base64 -d | jq -r '.value')

        # Replace placeholders
        filename="${filename//\{\{PROJECT_NAME\}\}/$project_name}"
        content="${content//\{\{PROJECT_NAME\}\}/$project_name}"
        content="${content//\{\{AUTHOR\}\}/$author}"
        content="${content//\{\{YEAR\}\}/$year}"

        # Create parent directories if needed
        local file_dir=$(dirname "$project_dir/$filename")
        mkdir -p "$file_dir"

        # Write file (interpret escape sequences)
        echo -e "$content" > "$project_dir/$filename"
        echo -e "  ${GREEN}Created:${NC} $filename"
    done

    # Run post-create commands
    local post_cmds=$(echo "$template_json" | jq -r '.post_create // [] | .[]' 2>/dev/null)
    if [[ -n "$post_cmds" ]]; then
        echo ""
        echo -e "${YELLOW}Running post-create commands:${NC}"
        while IFS= read -r cmd; do
            local actual_cmd="${cmd//\{\{PROJECT_NAME\}\}/$project_name}"
            echo -e "  ${GRAY}$ $actual_cmd${NC}"
            (cd "$project_dir" && eval "$actual_cmd" 2>/dev/null)
        done <<< "$post_cmds"
    fi

    echo ""
    echo -e "${GREEN}Project created successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  cd $project_dir"

    # Template-specific next steps
    case "$template" in
        node-cli|express-api)
            echo "  npm install"
            echo "  npm start"
            ;;
        python-cli)
            echo "  python $project_name.py"
            ;;
        python-package)
            echo "  pip install -e ."
            echo "  python -m pytest tests/"
            ;;
        bash-script)
            echo "  ./$project_name.sh"
            ;;
        docker-service)
            echo "  docker-compose up"
            ;;
        makefile-project)
            echo "  make build"
            ;;
    esac
}

# Add custom template
add_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: scaffold.sh add <template-name>"
        exit 1
    fi

    # Validate name
    if ! [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        echo -e "${RED}Invalid template name.${NC}"
        exit 1
    fi

    # Check if already exists
    if [[ -f "$TEMPLATES_DIR/$name.json" ]]; then
        echo -e "${YELLOW}Template '$name' already exists.${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Create template skeleton
    cat > "$TEMPLATES_DIR/$name.json" << 'EOF'
{
    "description": "Custom template",
    "files": {
        "README.md": "# {{PROJECT_NAME}}\n\nDescription\n",
        "main.sh": "#!/bin/bash\necho 'Hello from {{PROJECT_NAME}}'\n"
    },
    "directories": [],
    "post_create": ["chmod +x main.sh"]
}
EOF

    # Add to custom templates list
    jq --arg name "$name" '.custom_templates += [$name] | .custom_templates |= unique' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo -e "${GREEN}Created template:${NC} $name"
    echo -e "${CYAN}Edit:${NC} $TEMPLATES_DIR/$name.json"
    echo ""

    # Open in editor
    local editor="${EDITOR:-${VISUAL:-nano}}"
    read -p "Open in editor? (Y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        $editor "$TEMPLATES_DIR/$name.json"
    fi
}

# Edit custom template
edit_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: scaffold.sh edit <template-name>"
        exit 1
    fi

    if [[ ! -f "$TEMPLATES_DIR/$name.json" ]]; then
        echo -e "${RED}Custom template '$name' not found.${NC}"
        exit 1
    fi

    local editor="${EDITOR:-${VISUAL:-nano}}"
    $editor "$TEMPLATES_DIR/$name.json"

    echo -e "${GREEN}Template '$name' updated.${NC}"
}

# Remove custom template
remove_template() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: scaffold.sh remove <template-name>"
        exit 1
    fi

    if [[ ! -f "$TEMPLATES_DIR/$name.json" ]]; then
        echo -e "${RED}Custom template '$name' not found.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}About to delete template:${NC} $name"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    rm "$TEMPLATES_DIR/$name.json"
    jq --arg name "$name" '.custom_templates -= [$name]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo -e "${RED}Deleted template:${NC} $name"
}

# Configure variables
config_vars() {
    echo -e "${BLUE}=== Configure Default Variables ===${NC}"
    echo ""
    echo "These values will be substituted in templates."
    echo ""

    local current_author=$(jq -r '.variables.author // ""' "$CONFIG_FILE")
    local current_email=$(jq -r '.variables.email // ""' "$CONFIG_FILE")
    local current_github=$(jq -r '.variables.github_username // ""' "$CONFIG_FILE")

    read -p "Author name [$current_author]: " new_author
    read -p "Email [$current_email]: " new_email
    read -p "GitHub username [$current_github]: " new_github

    new_author="${new_author:-$current_author}"
    new_email="${new_email:-$current_email}"
    new_github="${new_github:-$current_github}"

    jq --arg author "$new_author" --arg email "$new_email" --arg github "$new_github" '
        .variables.author = $author |
        .variables.email = $email |
        .variables.github_username = $github
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo ""
    echo -e "${GREEN}Configuration saved.${NC}"
}

show_help() {
    echo "Scaffold - Project scaffolding and template generator"
    echo ""
    echo "Usage:"
    echo "  scaffold.sh create <template> <name> [path]  Create project from template"
    echo "  scaffold.sh list                             List available templates"
    echo "  scaffold.sh show <template>                  Show template details"
    echo "  scaffold.sh add <name>                       Create custom template"
    echo "  scaffold.sh edit <name>                      Edit custom template"
    echo "  scaffold.sh remove <name>                    Remove custom template"
    echo "  scaffold.sh config                           Configure default variables"
    echo "  scaffold.sh help                             Show this help"
    echo ""
    echo "Templates:"
    echo "  bash-script, python-cli, python-package, node-cli,"
    echo "  express-api, html-page, makefile-project, docker-service"
    echo ""
    echo "Examples:"
    echo "  scaffold.sh create python-cli my-tool"
    echo "  scaffold.sh create express-api api-server ~/projects"
    echo "  scaffold.sh add my-template"
}

case "$1" in
    create|new|init)
        create_project "$2" "$3" "$4"
        ;;
    list|ls)
        list_templates
        ;;
    show|info)
        show_template "$2"
        ;;
    add)
        add_template "$2"
        ;;
    edit)
        edit_template "$2"
        ;;
    remove|rm|delete)
        remove_template "$2"
        ;;
    config|configure)
        config_vars
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        list_templates
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'scaffold.sh help' for usage"
        exit 1
        ;;
esac
