FROM node:22-slim

# Install git, ssh, and jq (needed for commits, pushing to GitHub, and JSON processing)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git openssh-client jq && \
    rm -rf /var/lib/apt/lists/*

# Install claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Working directory will be mounted
WORKDIR /workspace

# Run as non-root 'node' user (UID 1000) - required because claude CLI
# refuses --dangerously-skip-permissions when running as root
USER node

# Default entrypoint - can be overridden by c-run.sh
ENTRYPOINT ["./agent/run.sh"]
