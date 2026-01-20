#!/bin/bash
#
# Containerized Evolution Agent Runner
#
# Runs the agent in an isolated Docker container where it can ONLY
# modify files within the mounted project directory.
#
# Security:
# - Read-only container filesystem
# - Only /agent (for state/logs) and /project are writable
# - Credentials are COPIED (not mounted) to ephemeral tmpfs
# - Lock file prevents concurrent runs
#
# Usage: ./c-run.sh <project-path> [--dry-run] [--rebuild]
#
# Project path can be:
#   - A relative path (e.g., "../my-project", "./project")
#   - An absolute path (e.g., "/home/user/my-project")
#

set -e

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="evolution-agent"
CONTAINER_NAME="evolution-agent-$$"
LOCK_FILE="$AGENT_DIR/state/container.lock"

# Parse arguments
PROJECT_PATH=""
DRY_RUN=""
REBUILD=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --rebuild)
            REBUILD=true
            ;;
        *)
            if [[ -z "$PROJECT_PATH" ]]; then
                PROJECT_PATH="$arg"
            fi
            ;;
    esac
done

# Validate project path
if [[ -z "$PROJECT_PATH" ]]; then
    echo "Usage: $0 <project-path> [--dry-run] [--rebuild]"
    echo ""
    echo "Project path can be:"
    echo "  - A relative path (e.g., '../my-project', './project')"
    echo "  - An absolute path (e.g., '/home/user/my-project')"
    echo ""
    echo "The project directory must contain a project-config.json file."
    echo ""
    echo "Example:"
    echo "  $0 ../productivity-suite"
    echo "  $0 /home/user/my-app --dry-run"
    exit 1
fi

# Resolve project path to absolute
if [[ "$PROJECT_PATH" == /* ]]; then
    # Already absolute - use as-is
    :
elif [[ -d "$PROJECT_PATH" ]]; then
    # Relative path from current working directory
    PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
else
    echo "ERROR: Project directory not found: $PROJECT_PATH"
    echo ""
    echo "Looked for: $(pwd)/$PROJECT_PATH"
    exit 1
fi

# Verify path exists
if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "ERROR: Project directory does not exist: $PROJECT_PATH"
    exit 1
fi

# Validate project config exists
if [[ ! -f "$PROJECT_PATH/project-config.json" ]]; then
    echo "ERROR: No project-config.json found in $PROJECT_PATH"
    echo ""
    echo "Create a project-config.json with at minimum:"
    echo '{'
    echo '  "name": "my-project",'
    echo '  "prompt": "Instructions for the agent..."'
    echo '}'
    exit 1
fi

# Get project name from config
PROJECT_NAME=$(jq -r '.name // "unnamed"' "$PROJECT_PATH/project-config.json" 2>/dev/null || echo "unnamed")

# Ensure state directory exists
mkdir -p "$AGENT_DIR/state"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

# Check for existing running container
if [[ -f "$LOCK_FILE" ]]; then
    EXISTING_CONTAINER=$(cat "$LOCK_FILE")
    if docker ps -q --filter "id=$EXISTING_CONTAINER" | grep -q .; then
        echo "Another agent container is already running: $EXISTING_CONTAINER"
        echo "Skipping this run."
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

# Build image if needed
if [[ "$REBUILD" == "true" ]] || ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "Building Docker image '$IMAGE_NAME'..."
    docker build -t "$IMAGE_NAME" "$AGENT_DIR"
fi

# Credentials file path
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "ERROR: Claude credentials not found at $CREDENTIALS_FILE"
    exit 1
fi

CREDENTIALS_CONTENT=$(cat "$CREDENTIALS_FILE")

# SSH key for GitHub (optional)
SSH_KEY_FILE="$AGENT_DIR/state/ssh/id_ed25519"
SSH_KEY_CONTENT=""
if [[ -f "$SSH_KEY_FILE" ]]; then
    SSH_KEY_CONTENT=$(cat "$SSH_KEY_FILE")
    echo "SSH key found - git push will be enabled"
else
    echo "WARNING: No SSH key found at $SSH_KEY_FILE - git push will fail"
fi

echo "Starting containerized agent run..."
echo "Project: $PROJECT_NAME"
echo "Project path: $PROJECT_PATH"

# Run the container
# Mount agent directory and project directory separately
CONTAINER_ID=$(docker run -d \
    --name "$CONTAINER_NAME" \
    --read-only \
    --tmpfs /tmp:rw,exec,size=100m \
    --tmpfs /home/node:rw,exec,size=100m,uid=1000,gid=1000 \
    -v "$AGENT_DIR:/agent:rw" \
    -v "$PROJECT_PATH:/project:rw" \
    -e "HOME=/home/node" \
    -e "CLAUDE_CREDENTIALS=$CREDENTIALS_CONTENT" \
    -e "SSH_PRIVATE_KEY=$SSH_KEY_CONTENT" \
    -e "GIT_AUTHOR_NAME=Evolution Agent" \
    -e "GIT_AUTHOR_EMAIL=agent@local" \
    -e "GIT_COMMITTER_NAME=Evolution Agent" \
    -e "GIT_COMMITTER_EMAIL=agent@local" \
    -e "DRY_RUN=$DRY_RUN" \
    --entrypoint sh \
    "$IMAGE_NAME" -c '
        # Set up home directory
        mkdir -p /home/node/.claude

        # Write credentials from environment
        echo "$CLAUDE_CREDENTIALS" > /home/node/.claude/.credentials.json
        unset CLAUDE_CREDENTIALS

        # Set up SSH if key provided
        if [ -n "$SSH_PRIVATE_KEY" ]; then
            mkdir -p /home/node/.ssh
            chmod 700 /home/node/.ssh
            echo "$SSH_PRIVATE_KEY" > /home/node/.ssh/id_ed25519
            chmod 600 /home/node/.ssh/id_ed25519
            unset SSH_PRIVATE_KEY
            echo "Host github.com
    StrictHostKeyChecking accept-new
    IdentityFile /home/node/.ssh/id_ed25519" > /home/node/.ssh/config
            chmod 600 /home/node/.ssh/config
        fi

        # Configure git safe directories
        git config --global --add safe.directory /agent
        git config --global --add safe.directory /project

        # Run the agent
        /agent/run.sh /project $DRY_RUN
    ')

echo "$CONTAINER_ID" > "$LOCK_FILE"
echo "Container started: $CONTAINER_ID"

# Follow logs
docker logs -f "$CONTAINER_ID" 2>&1

# Get exit code
EXIT_CODE=$(docker inspect "$CONTAINER_ID" --format='{{.State.ExitCode}}')

# Cleanup
docker rm "$CONTAINER_ID" > /dev/null 2>&1 || true
rm -f "$LOCK_FILE"

echo "Containerized run completed with exit code: $EXIT_CODE"
exit "$EXIT_CODE"
