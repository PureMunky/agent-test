# Evolution Agent

A general-purpose autonomous agent runner that continuously refines and evolves any project based on a configurable prompt. Point it at any repository with a `project-config.json` and let it incrementally improve your codebase over time.

## Overview

This repository contains **only the agent infrastructure**. Projects live in their own separate repositories/directories. This clean separation means:

- Your project's git history stays independent
- The agent can evolve multiple projects
- Agent updates don't affect your projects
- Projects can be private while the agent is shared

## Directory Structure

```
evolution-agent/           # This repository
├── agent/
│   ├── run.sh             # Main runner script
│   ├── c-run.sh           # Containerized runner
│   ├── Dockerfile         # Container definition
│   ├── config/
│   │   └── agent-config.json   # Global agent guidelines
│   ├── state/             # Runtime state (timestamps, markers)
│   └── logs/              # Execution logs
├── ssh/                   # SSH keys for GitHub (gitignored)
│   ├── id_ed25519         # Private key
│   └── id_ed25519.pub     # Public key
└── README.md

../my-project/             # Your project (separate repo)
├── project-config.json    # Evolution instructions
└── ...                    # Your project files
```

## Setup

### 1. Install Dependencies

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Ensure jq is installed (for JSON processing)
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### 2. Authenticate with Claude

Run `claude` once to authenticate:

```bash
claude
```

This creates `~/.claude/.credentials.json` which is required for the agent to run. For containerized runs (`c-run.sh`), this file is copied into the container at runtime.

### 3. Set Up SSH Keys (Optional - for auto_push)

If you want the agent to push commits to GitHub, generate an SSH key and place it in the `ssh/` directory:

```bash
# Generate a new key (or copy an existing one)
ssh-keygen -t ed25519 -f ssh/id_ed25519 -N ""

# Add the public key to your GitHub account
cat ssh/id_ed25519.pub
# Copy this output to GitHub → Settings → SSH Keys
```

The `ssh/` directory is gitignored to keep your keys out of version control.

**Note:** For non-containerized runs (`run.sh`), your system's default SSH configuration is used instead.

## Quick Start

### 1. Set Up a Project

In any repository you want the agent to evolve, create a `project-config.json`:

```json
{
  "name": "my-project",
  "description": "What this project does",
  "auto_commit": true,
  "auto_push": false,
  "min_interval_seconds": 60,
  "prompt": "Your detailed instructions for the agent. Describe what you want built, improved, or fixed. Be specific about constraints and goals."
}
```

### 2. Run the Agent

```bash
# From the agent directory, point to your project
./agent/run.sh ../my-project

# Dry run (no changes committed)
./agent/run.sh ../my-project --dry-run

# Using absolute path
./agent/run.sh /home/user/projects/my-app

# Containerized execution (more secure)
./agent/c-run.sh ../my-project
```

## Configuration

### Project Config (`project-config.json`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | Project identifier (used for logs and state) |
| `description` | string | - | Human-readable description |
| `prompt` | string | required | **The instructions given to the agent each run** |
| `auto_commit` | boolean | true | Automatically commit changes |
| `auto_push` | boolean | false | Push commits to remote |
| `min_interval_seconds` | number | 60 | Minimum time between runs |

### Global Agent Config (`agent/config/agent-config.json`)

Contains guidelines that apply to all projects:
- General coding standards
- Safety constraints
- Improvement priorities

## How It Works

1. **Trigger**: `run.sh` is called with a project path (manually or via cron)
2. **Safety Checks**: Verifies auth status, rate limits, and minimum intervals
3. **Load Config**: Reads project-specific prompt from `project-config.json`
4. **Invoke Agent**: Runs Claude with the prompt in the project directory
5. **Auto-Commit**: If changes detected and enabled, commits with descriptive message
6. **Log**: Records execution details to `agent/logs/`

## Running on a Schedule

Add to crontab for continuous evolution:

```bash
# Run every 10 minutes
*/10 * * * * /path/to/evolution-agent/agent/run.sh /path/to/my-project >> /path/to/evolution-agent/agent/logs/cron.log 2>&1
```

## Containerized Execution

For added security, use the containerized runner:

```bash
# Build and run
./agent/c-run.sh ../my-project

# Rebuild the image
./agent/c-run.sh ../my-project --rebuild
```

The container:
- Has a read-only filesystem (except `/agent` and `/project`)
- Stores credentials in ephemeral tmpfs (never persisted)
- Runs as non-root user
- Prevents concurrent executions

## State Files

Located in `agent/state/`:

| File | Purpose |
|------|---------|
| `last_run_<project>` | Unix timestamp of last successful run |
| `last_prompt_<project>.txt` | The prompt sent on last run |
| `auth_expired` | Created if API auth fails; remove after `claude /login` |
| `rate_limited` | Created if rate limited; auto-clears after 1 hour |

## Example Projects

### Productivity Suite

A collection of 42 CLI productivity tools autonomously created by this agent:

```bash
# Clone and run
git clone <productivity-suite-repo> ../productivity-suite
./agent/run.sh ../productivity-suite
```

### Web Application

```json
{
  "name": "my-webapp",
  "auto_commit": true,
  "prompt": "You are improving a React web application. Each run, make ONE improvement: fix a bug, add a feature, improve tests, or refactor code. Update CHANGELOG.md with your changes. Focus on code quality and user experience."
}
```

### Documentation Site

```json
{
  "name": "docs-site",
  "auto_commit": true,
  "prompt": "You maintain a documentation website. Each run: fix typos, improve clarity, add missing examples, or expand incomplete sections. Keep the tone consistent and beginner-friendly."
}
```

## Requirements

- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- `jq` for JSON processing
- `git` for version control
- Docker (optional, for containerized runs)

## Tips for Writing Prompts

1. **Be specific**: Describe exactly what you want built or improved
2. **Set constraints**: Limit scope per run (e.g., "make ONE change")
3. **Define structure**: Specify directory layout, file naming conventions
4. **Include examples**: Show the agent what good output looks like
5. **Iterate**: Refine your prompt as the project evolves
6. **Track state**: Use a manifest.json or similar to help the agent understand what exists

## License

MIT
