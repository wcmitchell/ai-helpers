---
name: Status Sentinel
description: Automatically sync JIRA ticket status based on git branch and commit activity
---

# Status Sentinel

This skill automatically detects JIRA tickets referenced in git branches and suggests status updates based on development activity. The goal is to keep JIRA updated without developers having to context-switch from their coding workflow.

## When to Use This Skill

This skill is invoked via:
- **Manual command:** `/jira:sync-status` - Check current branch and suggest status updates
- **Git hooks** (Phase 2): Automatic detection on branch creation, commits, and pushes

## Prerequisites

- JIRA credentials configured in `~/.config/claude-code/mcp.json`
- Git repository with branches that reference JIRA tickets
- User has permissions to update ticket status in the target project

**Reference Documentation:**
- [MCP Tools Reference](../../reference/mcp-tools.md) - MCP tool signatures
- [CLI Fallback Reference](../../reference/cli-fallback.md) - jira-cli commands (if MCP unavailable)

## How It Works

Status Sentinel uses a detection cascade to link git activity to JIRA tickets:

### Detection Cascade

1. **Branch Name Parsing** (Highest confidence)
   - Extract JIRA ID from branch name
   - Patterns: `PROJ-1234-description`, `PROJ-1234`, `feature/PROJ-1234`
   - Example: `ENGPROD-9711-fix-cji-validation` → `ENGPROD-9711`

2. **Commit Message Scanning** (Medium confidence)
   - Scan recent commits for JIRA references
   - Look for patterns: `PROJ-1234:`, `[PROJ-1234]`, `Fixes PROJ-1234`

3. **Manual Linking** (User-specified)
   - User can manually link branch to ticket
   - Stored in git config: `git config branch.<name>.jira PROJ-1234`

### Status Transition Logic

Based on git state, suggest appropriate JIRA status transitions:

| Git Event | Current JIRA Status | Suggested Status | Reasoning |
|-----------|---------------------|------------------|-----------|
| Branch created | Backlog, To Do, New | In Progress | Work has started |
| Branch created | Any other | No change | Already in motion |
| Commits pushed | Backlog, To Do, New | In Progress | Active development |
| PR opened | In Progress | Code Review | Ready for review |
| PR merged | Code Review, In Progress | Done | Work complete |
| PR closed (unmerged) | Any | No change | User may close manually |

### Workflow State Machine

The skill learns from each project's available transitions:

1. **Query JIRA** for available status transitions for the ticket
2. **Filter** transitions based on current git state
3. **Suggest** the most appropriate transition
4. **Remember** user preferences (accept/reject patterns)

## Implementation Guide

### Manual Command: `/jira:sync-status`

When invoked, execute the following workflow:

#### Step 1: Detect Current Context

```bash
# Get current branch
BRANCH=$(git branch --show-current)

# Try to extract JIRA ID from branch name
JIRA_ID=$(extract_jira_id "$BRANCH")

# If not found, check git config
if [ -z "$JIRA_ID" ]; then
  JIRA_ID=$(git config "branch.${BRANCH}.jira")
fi

# If still not found, scan recent commits
if [ -z "$JIRA_ID" ]; then
  JIRA_ID=$(git log -20 --pretty=format:"%s" | grep -oP '[A-Z]+-[0-9]+' | head -1)
fi
```

#### Step 2: Fetch JIRA Ticket Details

```bash
# Get ticket details via MCP or CLI
TICKET=$(jira_get_issue "$JIRA_ID")

# Extract current status
CURRENT_STATUS=$(echo "$TICKET" | jq -r '.fields.status.name')

# Get available transitions
TRANSITIONS=$(jira_get_transitions "$JIRA_ID")
```

#### Step 3: Determine Git State

```bash
# Check if this branch has an open PR
PR_STATE=$(gh pr view --json state,merged 2>/dev/null || echo "none")

# Count commits since branch diverged
COMMIT_COUNT=$(git rev-list --count main..HEAD)

# Determine git state
if [ "$PR_STATE" != "none" ]; then
  if [ "$(echo "$PR_STATE" | jq -r '.merged')" = "true" ]; then
    GIT_STATE="merged"
  elif [ "$(echo "$PR_STATE" | jq -r '.state')" = "OPEN" ]; then
    GIT_STATE="pr_open"
  else
    GIT_STATE="pr_closed"
  fi
elif [ "$COMMIT_COUNT" -gt 0 ]; then
  GIT_STATE="active_development"
else
  GIT_STATE="branch_created"
fi
```

#### Step 4: Suggest Status Transition

Based on `CURRENT_STATUS` and `GIT_STATE`, suggest appropriate transition:

```python
def suggest_transition(current_status, git_state, available_transitions):
    """
    Suggest the most appropriate status transition.

    Args:
        current_status: Current JIRA ticket status
        git_state: Current git state (branch_created, active_development, pr_open, merged)
        available_transitions: List of available JIRA transitions

    Returns:
        Suggested transition name or None
    """

    # Normalize status names (case-insensitive, handle spaces)
    current = current_status.lower().replace(' ', '_')

    # Define suggestion rules
    rules = {
        'branch_created': {
            'backlog': 'In Progress',
            'to_do': 'In Progress',
            'new': 'In Progress'
        },
        'active_development': {
            'backlog': 'In Progress',
            'to_do': 'In Progress',
            'new': 'In Progress'
        },
        'pr_open': {
            'in_progress': 'Code Review',
            'backlog': 'Code Review',
            'to_do': 'Code Review'
        },
        'merged': {
            'code_review': 'Done',
            'in_progress': 'Done',
            'backlog': 'Done'
        }
    }

    # Get suggestion for current state
    state_rules = rules.get(git_state, {})
    suggested = state_rules.get(current)

    if not suggested:
        return None

    # Check if suggested transition is available
    available_names = [t['name'] for t in available_transitions]

    # Try exact match
    if suggested in available_names:
        return suggested

    # Try case-insensitive match
    for name in available_names:
        if name.lower() == suggested.lower():
            return name

    return None
```

#### Step 5: Present Suggestion to User

Display the suggestion and ask for confirmation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status Sentinel: JIRA Update Suggestion
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ticket: ENGPROD-9711
Title: CJI silently rejected if name is too long
Branch: ENGPROD-9711-fix-cji-validation

Current Status: New
Git State: Active development (3 commits)

Suggested Action: Move to "In Progress"

This ticket is in "New" status, but you have 3 commits on this
branch. Would you like to move it to "In Progress" to reflect that
work has started?

Actions:
  [y] Yes, update status
  [n] No, keep current status
  [s] Skip this check for this branch
  [m] Manually specify different status
  [?] Show available transitions

Choice:
```

#### Step 6: Execute Transition

If user approves:

```bash
# Perform the transition via MCP or CLI
jira_transition_issue "$JIRA_ID" "$TRANSITION_ID"

# Confirm
echo "✓ Updated $JIRA_ID status to '$NEW_STATUS'"

# Optionally, add a comment
jira_add_comment "$JIRA_ID" "Status updated to '$NEW_STATUS' (via Status Sentinel)"
```

#### Step 7: Remember User Preference

Track user decisions for future suggestions:

```bash
# Store in git config
if [ "$USER_CHOICE" = "skip" ]; then
  git config "jira.status-sentinel.skip.$BRANCH" "true"
fi

# Store global preferences
if [ "$USER_CHOICE" = "always_yes_for_this_pattern" ]; then
  echo "$GIT_STATE -> $SUGGESTED_STATUS" >> ~/.config/claude-code/jira-sentinel-rules.txt
fi
```

## Configuration

### Global Config: `~/.config/claude-code/jira-sentinel.json`

```json
{
  "enabled": true,
  "autoDetect": true,
  "defaultWorkflow": {
    "branch_created": "In Progress",
    "pr_opened": "Code Review",
    "pr_merged": "Done"
  },
  "projectWorkflows": {
    "ENGPROD": {
      "branch_created": "In Progress",
      "pr_opened": "Under Review",
      "pr_merged": "Closed"
    }
  },
  "skipPatterns": [
    "wip/*",
    "experiment/*",
    "draft/*"
  ],
  "addComments": false
}
```

### Per-Branch Config (git config)

```bash
# Link branch to specific JIRA ticket
git config branch.my-feature.jira PROJ-1234

# Skip status sentinel for this branch
git config jira.status-sentinel.skip.my-feature true
```

## Error Handling

### No JIRA ID Found

```
Status Sentinel: No JIRA ticket detected

I couldn't find a JIRA ticket reference in your branch name,
commit messages, or git config.

Would you like to:
  [l] Link this branch to a JIRA ticket
  [s] Skip - this branch doesn't need a JIRA ticket
  [?] Show me how to name branches with JIRA refs

Choice:
```

### Multiple JIRA IDs Found

```
Status Sentinel: Multiple JIRA tickets detected

I found references to multiple tickets:
  - PROJ-1234 (in branch name)
  - PROJ-5678 (in commit messages)

Which ticket is this branch primarily for?
  [1] PROJ-1234: Fix OAuth handler
  [2] PROJ-5678: Update dependencies
  [n] Neither - link to different ticket
  [s] Skip status sync

Choice:
```

### Transition Not Available

```
Status Sentinel: Cannot transition to "Code Review"

The current workflow for ENGPROD-9711 doesn't allow
transitions from "New" to "Code Review".

Available transitions from "New":
  - In Progress
  - Won't Do
  - Closed

Would you like to:
  [1] Move to "In Progress" instead
  [2] Keep current status
  [3] View full workflow diagram

Choice:
```

### Authentication Failed

```
Status Sentinel: JIRA authentication failed

I couldn't authenticate with JIRA. Please check your credentials
in ~/.config/claude-code/mcp.json

Error: HTTP 401 Unauthorized

Would you like me to help you reconfigure JIRA credentials? [y/n]
```

## Git Hooks Integration (Phase 2)

For automated detection, install git hooks:

### post-checkout Hook

Triggers when creating or switching branches:

```bash
#!/bin/bash
# .git/hooks/post-checkout

# Only run on branch checkout (not file checkout)
if [ "$3" = "1" ]; then
  # Extract JIRA ID from new branch
  NEW_BRANCH=$(git branch --show-current)
  JIRA_ID=$(echo "$NEW_BRANCH" | grep -oP '[A-Z]+-[0-9]+')

  if [ -n "$JIRA_ID" ]; then
    # Queue for next Claude Code session
    echo "Branch $NEW_BRANCH → $JIRA_ID: Check status" >> ~/.claude-code/jira-pending.txt

    echo "📋 JIRA ticket detected: $JIRA_ID"
    echo "   Run '/jira:sync-status' to update ticket status"
  fi
fi
```

### prepare-commit-msg Hook

Suggest adding JIRA ID to commit message:

```bash
#!/bin/bash
# .git/hooks/prepare-commit-msg

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only for user-written messages (not merge, etc.)
if [ "$COMMIT_SOURCE" = "" ] || [ "$COMMIT_SOURCE" = "message" ]; then
  BRANCH=$(git branch --show-current)
  JIRA_ID=$(echo "$BRANCH" | grep -oP '[A-Z]+-[0-9]+')

  if [ -n "$JIRA_ID" ]; then
    # Check if message already has JIRA ref
    if ! grep -q "$JIRA_ID" "$COMMIT_MSG_FILE"; then
      # Prepend JIRA ID to commit message
      TEMP=$(mktemp)
      echo "[$JIRA_ID] $(cat $COMMIT_MSG_FILE)" > "$TEMP"
      mv "$TEMP" "$COMMIT_MSG_FILE"

      echo "✓ Added $JIRA_ID reference to commit message"
    fi
  fi
fi
```

## Testing

### Test Scenarios

1. **Happy Path: Branch → In Progress**
   - Create branch: `PROJ-1234-new-feature`
   - Ticket status: "Backlog"
   - Expected: Suggest "In Progress"

2. **PR Opened: In Progress → Code Review**
   - Open PR for branch
   - Ticket status: "In Progress"
   - Expected: Suggest "Code Review"

3. **PR Merged: Code Review → Done**
   - Merge PR
   - Ticket status: "Code Review"
   - Expected: Suggest "Done"

4. **No JIRA in Branch Name**
   - Branch: `fix-login-bug`
   - Commits mention: "Fixes PROJ-5678"
   - Expected: Detect PROJ-5678 from commits

5. **Already Correct Status**
   - Branch created, ticket already "In Progress"
   - Expected: No suggestion (already correct)

6. **Workflow Doesn't Allow Transition**
   - Suggest transition that's not available
   - Expected: Show available alternatives

## Future Enhancements

- **Confidence Scoring:** Show confidence level for JIRA detection
- **Batch Updates:** Update multiple tickets at once
- **Smart Defaults:** Learn user preferences over time
- **PR Integration:** Detect PR reviews and update status accordingly
- **Time Tracking:** Auto-log work time based on commits
- **Multi-Ticket Branches:** Handle branches that touch multiple tickets

## See Also

- [Progress Chronicler](../progress-chronicler/SKILL.md) - Auto-generate progress updates
- [Refinement Architect](../refinement-architect/SKILL.md) - Enhance ticket descriptions
