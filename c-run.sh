#!/bin/bash
#
# Containerized Productivity Suite Evolution Runner
#
# Runs the agent in an isolated Docker container where it can ONLY
# modify files within the mounted workspace directory.
#
# Security:
# - Read-only container filesystem
# - Only /workspace is writable (mounted from host)
# - Credentials are COPIED (not mounted) to ephemeral tmpfs
# - Lock file prevents concurrent runs
#
# Usage: ./run-containerized.sh [--dry-run] [--rebuild]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agent-runner"
CONTAINER_NAME="agent-runner-$$"
LOCK_FILE="$SCRIPT_DIR/.agent/container.lock"

# Parse arguments
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
    esac
done

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

# Check for existing running container (prevent concurrent runs)
if [[ -f "$LOCK_FILE" ]]; then
    EXISTING_CONTAINER=$(cat "$LOCK_FILE")
    if docker ps -q --filter "id=$EXISTING_CONTAINER" | grep -q .; then
        echo "Another agent container is already running: $EXISTING_CONTAINER"
        echo "Skipping this run."
        exit 0
    else
        # Stale lock file, remove it
        rm -f "$LOCK_FILE"
    fi
fi

# Build image if it doesn't exist or rebuild requested
if [[ "$REBUILD" == "true" ]] || ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "Building Docker image '$IMAGE_NAME'..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Credentials file path
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "ERROR: Claude credentials not found at $CREDENTIALS_FILE"
    exit 1
fi

# Read credentials content (will be passed via environment, not mounted)
CREDENTIALS_CONTENT=$(cat "$CREDENTIALS_FILE")

# SSH key for GitHub (optional - needed for git push)
SSH_KEY_FILE="$SCRIPT_DIR/.agent/ssh/id_ed25519"
SSH_KEY_CONTENT=""
if [[ -f "$SSH_KEY_FILE" ]]; then
    SSH_KEY_CONTENT=$(cat "$SSH_KEY_FILE")
    echo "SSH key found - git push will be enabled"
else
    echo "WARNING: No SSH key found at $SSH_KEY_FILE - git push will fail"
    echo "To enable push, add your bot SSH private key to .agent/ssh/id_ed25519"
fi

echo "Starting containerized agent run..."
echo "Workspace: $SCRIPT_DIR"
echo "Container filesystem: read-only (except /workspace and /tmp)"
echo "Credentials: copied to ephemeral storage (not mounted)"

# Create lock file
mkdir -p "$(dirname "$LOCK_FILE")"

# Run the container with strict isolation
# - Read-only root filesystem
# - tmpfs for /tmp and /home/node (ephemeral home, credentials copied here)
# - Only /workspace is mounted from host (the ONLY persistent writable location)
# - Runs as non-root user 'agent' (UID 1000) for claude CLI compatibility
CONTAINER_ID=$(docker run -d \
    --name "$CONTAINER_NAME" \
    --read-only \
    --tmpfs /tmp:rw,exec,size=100m \
    --tmpfs /home/node:rw,exec,size=100m,uid=1000,gid=1000 \
    -v "$SCRIPT_DIR:/workspace:rw" \
    -e "HOME=/home/node" \
    -e "CLAUDE_CREDENTIALS=$CREDENTIALS_CONTENT" \
    -e "SSH_PRIVATE_KEY=$SSH_KEY_CONTENT" \
    -e "GIT_AUTHOR_NAME=Agent Runner" \
    -e "GIT_AUTHOR_EMAIL=agent@local" \
    -e "GIT_COMMITTER_NAME=Agent Runner" \
    -e "GIT_COMMITTER_EMAIL=agent@local" \
    --entrypoint sh \
    "$IMAGE_NAME" -c '
        # Set up home directory
        mkdir -p /home/node/.claude
        # Write credentials from environment to file (never touches host filesystem)
        echo "$CLAUDE_CREDENTIALS" > /home/node/.claude/.credentials.json
        unset CLAUDE_CREDENTIALS

        # Set up SSH for GitHub if key was provided
        if [ -n "$SSH_PRIVATE_KEY" ]; then
            mkdir -p /home/node/.ssh
            chmod 700 /home/node/.ssh
            echo "$SSH_PRIVATE_KEY" > /home/node/.ssh/id_ed25519
            chmod 600 /home/node/.ssh/id_ed25519
            unset SSH_PRIVATE_KEY
            # Configure SSH to trust GitHub host
            echo "Host github.com
    StrictHostKeyChecking accept-new
    IdentityFile /home/node/.ssh/id_ed25519" > /home/node/.ssh/config
            chmod 600 /home/node/.ssh/config
        fi

        # Configure git to trust the workspace directory
        git config --global --add safe.directory /workspace
        # Run the actual script
        cd /workspace
        ./run.sh '"$DRY_RUN"'
    ')

echo "$CONTAINER_ID" > "$LOCK_FILE"
echo "Container started: $CONTAINER_ID"

# Follow logs and wait for completion
docker logs -f "$CONTAINER_ID" 2>&1

# Get exit code
EXIT_CODE=$(docker inspect "$CONTAINER_ID" --format='{{.State.ExitCode}}')

# Cleanup
docker rm "$CONTAINER_ID" > /dev/null 2>&1 || true
rm -f "$LOCK_FILE"

echo "Containerized run completed with exit code: $EXIT_CODE"
exit "$EXIT_CODE"
