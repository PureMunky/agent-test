# Decisions

A command-line decision log for tracking important choices, their rationale, alternatives considered, and outcomes.

## Why Track Decisions?

- **Avoid rehashing** - Stop revisiting the same decisions repeatedly
- **Learn from history** - Understand what worked and what didn't
- **Provide context** - Help future you (or teammates) understand why choices were made
- **Track outcomes** - See if decisions had the expected results

## Installation

The tool is ready to use. Ensure `jq` is installed:

```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

## Usage

### Recording a Decision

```bash
./decisions.sh add "Use PostgreSQL for user data"
```

You'll be prompted for:
- **Context** - What led to this decision
- **Decision** - The actual choice made
- **Alternatives** - Other options considered
- **Rationale** - Why this choice was made
- **Tags** - Categories (comma-separated)
- **Expected outcome** - What you hope will happen
- **Review date** - When to revisit (optional)

### Viewing Decisions

```bash
# List recent decisions
./decisions.sh list        # Last 10
./decisions.sh list 20     # Last 20

# View full details
./decisions.sh show 1

# Search decisions
./decisions.sh search "database"

# Filter by tag
./decisions.sh by-tag "architecture"
```

### Updating Decisions

```bash
./decisions.sh update 1
```

Options:
1. Record actual outcome
2. Change status (active/reversed/superseded/pending)
3. Add to rationale
4. Set review date

### Other Commands

```bash
# List all tags
./decisions.sh tags

# Show decisions needing review
./decisions.sh pending

# View statistics
./decisions.sh stats

# Help
./decisions.sh help
```

## Decision Status

| Status | Meaning |
|--------|---------|
| `active` | Decision is currently in effect |
| `pending` | Awaiting implementation or review |
| `reversed` | Decision was rolled back |
| `superseded` | Replaced by a newer decision |

## Examples

### Recording a Technical Decision

```bash
./decisions.sh add "Migrate from REST to GraphQL"
```

**Context:** API is becoming complex with many endpoints, clients need flexible queries

**Decision:** Implement GraphQL using Apollo Server, keep REST for public API

**Alternatives:**
- Keep REST, add query parameters
- Use JSON:API specification
- Implement custom query language

**Rationale:**
- Reduces over-fetching for mobile clients
- Type safety with schema
- Team has experience with Apollo

**Tags:** api, architecture, backend

**Expected outcome:** 30% reduction in API calls, faster mobile app

### Recording a Process Decision

```bash
./decisions.sh add "Adopt trunk-based development"
```

### Later: Recording the Outcome

```bash
./decisions.sh update 1
# Choose option 1 (Record actual outcome)
# Enter: "Achieved 40% reduction in API calls. Mobile team very happy."
```

## Data Storage

Decisions are stored in `data/decisions.json`. Back up this file to preserve your decision history.

## Tips

- **Be specific** - Good titles make searching easier
- **Document alternatives** - Even rejected options have value
- **Set review dates** - For decisions that need validation
- **Use consistent tags** - Makes filtering more useful
- **Record outcomes** - The most valuable part of the log
