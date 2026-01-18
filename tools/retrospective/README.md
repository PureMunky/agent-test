# Retrospective

A structured tool for conducting retrospectives to reflect on work, identify improvements, and track action items over time.

Retrospectives are a core practice for continuous improvement. Whether you're reviewing a sprint, a project milestone, a week of work, or any period of activity, this tool helps you systematically capture what went well, what didn't, what you learned, and what you'll do differently.

## Installation

The script requires `jq` for JSON processing:

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Usage

```bash
# Start a new retrospective (interactive)
./retrospective.sh new

# Start with a name
./retrospective.sh new "Sprint 42 Retro"

# List all retrospectives
./retrospective.sh list

# View a specific retrospective
./retrospective.sh view 1

# Show pending action items across all retros
./retrospective.sh actions

# Mark an action item as complete
./retrospective.sh complete 3

# View statistics
./retrospective.sh stats

# Export a retrospective
./retrospective.sh export 1 md    # Markdown format
./retrospective.sh export 1 txt   # Plain text format
```

## Retrospective Format

Each retrospective captures four key areas:

### 1. What Went Well
Celebrate successes and identify what worked. This reinforces good practices and builds morale.

### 2. What Didn't Go Well
Honest reflection on challenges, blockers, and problems. No blame - focus on identifying issues.

### 3. What Did You Learn
New insights, skills, or knowledge gained. This captures growth and builds institutional knowledge.

### 4. Action Items
Concrete, actionable improvements to implement. These are tracked across retrospectives to ensure follow-through.

## Features

- **Structured reflection**: Guided prompts for consistent, thorough retrospectives
- **Action item tracking**: Track action items across all retrospectives with completion status
- **Rating system**: Optional 1-5 rating to track trends over time
- **Statistics**: View trends including completion rates for action items
- **Export**: Export retrospectives to Markdown or plain text for sharing
- **Persistent storage**: All data saved in JSON format

## Data Storage

All retrospective data is stored in `data/retrospectives.json` within the tool directory.

## Examples

### Running a Sprint Retrospective

```bash
$ ./retrospective.sh new "Sprint 42"

╔═══════════════════════════════════════════════════════════╗
║            New Retrospective                              ║
╚═══════════════════════════════════════════════════════════╝

Starting retrospective: Sprint 42
Date: 2026-01-18

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌟 WHAT WENT WELL
What worked? What are you proud of?
(Enter each item on a new line. Press Ctrl+D or enter an empty line when done)
Shipped the new dashboard feature on time
Team collaboration was excellent
...
```

### Viewing Pending Actions

```bash
$ ./retrospective.sh actions

=== Pending Action Items ===

From: Sprint 42 (2026-01-18)
  [ ] #1: Set up automated testing for dashboard
  [ ] #2: Schedule weekly sync with design team

From: Q4 Review (2026-01-10)
  [ ] #3: Document API endpoints

Complete an action: retrospective.sh complete <id>
```

## Best Practices

1. **Run regularly**: Weekly, bi-weekly, or after each project/sprint
2. **Be specific**: Vague items are hard to act on
3. **Follow through**: Review and complete action items before the next retro
4. **Keep it safe**: Focus on improvements, not blame
5. **Celebrate wins**: Don't skip the positive - it matters!

## Integration Ideas

- Export retrospectives to share with your team
- Review action items during weekly planning
- Use ratings to track team morale over time
- Combine with the `weekly-planner` tool for comprehensive reviews
