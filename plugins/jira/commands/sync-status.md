---
description: Automatically detect JIRA tickets from git branches and suggest status updates based on development activity
argument-hint: "[--branch branch-name] [--ticket PROJ-1234] [--dry-run]"
---

## Name
jira:sync-status

## Synopsis
```
/jira:sync-status [--branch branch-name] [--ticket PROJ-1234]
```

## Description
The `jira:sync-status` command automatically detects JIRA tickets referenced in your git branch and suggests status updates based on your development activity. This keeps JIRA updated without requiring you to context-switch from coding.

**Key Benefit:** Stay in your development flow - Status Sentinel handles JIRA updates for you.

## How It Works

1. **Detects JIRA ticket** from:
   - Current branch name (e.g., `ENGPROD-9711-fix-bug`)
   - Recent commit messages
   - Manual git config link

2. **Analyzes git state:**
   - Branch created → Suggest "In Progress"
   - Commits pushed → Suggest "In Progress"
   - PR opened → Suggest "Code Review"
   - PR merged → Suggest "Done"

3. **Suggests status update** based on JIRA workflow

4. **You approve** → Status updated automatically

## Usage Examples

### 1. Check current branch
```bash
/jira:sync-status
```
Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status Sentinel: JIRA Update Suggestion
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ticket: ENGPROD-9711
Title: CJI silently rejected if name is too long
Branch: ENGPROD-9711-fix-cji-validation

Current Status: New
Git State: Active development (3 commits)

Suggested Action: Move to "In Progress"

[y] Yes  [n] No  [s] Skip this branch  [?] Help
```

### 2. Check specific branch
```bash
/jira:sync-status --branch feature/PROJ-1234-oauth
```

### 3. Manually specify ticket
```bash
/jira:sync-status --ticket PROJ-5678
```
Useful when branch name doesn't contain JIRA ID.

### 4. Link branch to ticket for future use
```bash
git config branch.my-feature.jira PROJ-1234
/jira:sync-status
```

## Interactive Workflow

When you run `/jira:sync-status`, you'll be guided through:

1. **Ticket Detection:** Finds JIRA reference(s) in your branch
2. **Current State:** Shows ticket status and git activity
3. **Suggestion:** Recommends appropriate status transition
4. **Confirmation:** You review and approve/reject
5. **Update:** Status changed in JIRA (if approved)

### Example Session

```
$ /jira:sync-status

🔍 Detecting JIRA ticket from branch...
✓ Found: ENGPROD-9711 (from branch name)

📋 Fetching ticket details...
✓ ENGPROD-9711: "CJI silently rejected if name is too long"
   Status: New
   Assignee: Unassigned

🔧 Analyzing git activity...
✓ Branch: ENGPROD-9711-fix-cji-validation
✓ Commits: 3 since branch created
✓ PR: Not yet opened

💡 Suggestion:
   Current: "New"
   Recommended: "In Progress"
   Reason: You have active commits on this branch

Would you like to update the status? [y/n/s/?]: y

✓ Updated ENGPROD-9711 status to "In Progress"
```

## Configuration

### Global Settings: `~/.config/claude-code/jira-sentinel.json`

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
    "experiment/*"
  ],
  "addComments": false
}
```

### Per-Branch Configuration

```bash
# Link branch to ticket
git config branch.my-feature.jira PROJ-1234

# Disable sentinel for this branch
git config jira.status-sentinel.skip.my-feature true

# View current config
git config --get branch.$(git branch --show-current).jira
```

## Branch Naming Best Practices

For automatic detection, name branches with JIRA ID:

**Recommended formats:**
- `PROJ-1234-short-description`
- `PROJ-1234/feature-name`
- `feature/PROJ-1234-description`
- `bugfix/PROJ-1234`

**Examples:**
```bash
git checkout -b ENGPROD-9711-fix-cji-validation
git checkout -b OCPBUGS-12345/oauth-handler
git checkout -b feature/HYPE-9876-new-api
```

**Not recommended:**
- `fix-login` (no JIRA ID)
- `my-feature-branch` (no JIRA ID)
- `update-stuff` (no JIRA ID)

## Troubleshooting

### No JIRA ticket detected

```
Error: Could not detect JIRA ticket

Try:
  1. Rename branch to include JIRA ID: git branch -m PROJ-1234-description
  2. Manually link: git config branch.$(git branch --show-current).jira PROJ-1234
  3. Specify ticket: /jira:sync-status --ticket PROJ-1234
```

### Multiple tickets detected

```
Multiple JIRA tickets found:
  - PROJ-1234 (in branch name)
  - PROJ-5678 (in commit messages)

Which ticket is primary for this branch?
[1] PROJ-1234  [2] PROJ-5678  [m] Manual entry
```

### Transition not allowed

```
Cannot transition from "New" to "Code Review"

Available transitions from "New":
  - In Progress
  - Won't Do

Would you like to move to "In Progress" instead? [y/n]
```

### Authentication failed

```
JIRA authentication failed (HTTP 401)

Please check credentials in ~/.config/claude-code/mcp.json

See: /jira:setup for configuration help
```

## Opt-Out

To disable Status Sentinel:

```bash
# Globally
git config --global jira.status-sentinel.enabled false

# Per repository
git config jira.status-sentinel.enabled false

# Per branch
git config jira.status-sentinel.skip.$(git branch --show-current) true
```

## Arguments

- `--branch <name>` - Check specific branch instead of current branch
- `--ticket <PROJ-1234>` - Specify JIRA ticket ID manually
- `--no-detect` - Skip auto-detection, require explicit ticket ID
- `--dry-run` - Show what would be updated without making changes
- `--force` - Skip confirmation prompts (use with caution)

## Return Value

- **Exit 0**: Status updated successfully or no update needed
- **Exit 1**: Error (ticket not found, auth failed, etc.)
- **Exit 2**: User cancelled

## Integration

### With Progress Chronicler

After updating status, generate a progress update:

```bash
/jira:sync-status && /jira:chronicle
```

### With Git Workflow

```bash
# Start work
git checkout -b PROJ-1234-new-feature
/jira:sync-status  # Moves to "In Progress"

# Open PR
gh pr create
/jira:sync-status  # Moves to "Code Review"

# After merge
/jira:sync-status  # Moves to "Done"
```

## See Also

- `/jira:chronicle` - Generate progress updates from git history
- `/jira:grooming` - Analyze and groom backlog tickets
- `/jira:solve` - Start work on a JIRA ticket

## Implementation

The command follows these steps to detect the JIRA ticket, analyze git state, and suggest status updates:

### Process Flow

1. **Parse Arguments and Detect JIRA Ticket**:
   - Check for `--dry-run` flag in arguments. If present, set DRY_RUN=true
   - Check for `--branch` argument. If not provided, use current branch: `git branch --show-current`
   - Check for `--ticket` argument. If provided, use this as JIRA_ID and skip detection
   - If no --ticket provided, attempt to detect JIRA ID using the helper script:
     ```bash
     JIRA_ID=$(plugins/jira/skills/status-sentinel/extract-jira-id.sh "$BRANCH" 2>/dev/null)
     ```
   - JIRA ID pattern: `[A-Z][A-Z0-9]+-[0-9]+` (e.g., ENGPROD-9711, OCPBUGS-1234)
   - If no JIRA ID found, display error and suggest:
     - Renaming branch: `git branch -m PROJ-1234-description`
     - Manual linking: `git config branch.$(git branch --show-current).jira PROJ-1234`
     - Using --ticket flag: `/jira:sync-status --ticket PROJ-1234`
   - If multiple JIRA IDs detected (e.g., one in branch, different in commits), prompt user to select primary ticket

2. **Fetch JIRA Ticket Details**:
   - Extract credentials from `~/.config/claude-code/mcp.json`:
     ```bash
     JIRA_URL=$(jq -r '.mcpServers.atlassian.env.JIRA_URL' ~/.config/claude-code/mcp.json)
     JIRA_USERNAME=$(jq -r '.mcpServers.atlassian.env.JIRA_USERNAME' ~/.config/claude-code/mcp.json)
     JIRA_API_TOKEN=$(jq -r '.mcpServers.atlassian.env.JIRA_API_TOKEN' ~/.config/claude-code/mcp.json)
     ```
   - Fetch ticket using JIRA REST API:
     ```bash
     curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
       "$JIRA_URL/rest/api/3/issue/$JIRA_ID?fields=summary,status,assignee,transitions" \
       -o /tmp/jira-ticket-$JIRA_ID.json
     ```
   - Parse response to extract:
     - `summary`: Ticket title
     - `status.name`: Current status (e.g., "New", "In Progress", "Code Review")
     - `assignee.emailAddress`: Assigned user email
     - `assignee.displayName`: Assigned user name
   - **Ownership Check**: Compare assignee email with `$JIRA_USERNAME`
     - If ticket is assigned to someone else (not you, not unassigned):
       ```
       ⚠️  Warning: This ticket is assigned to {assignee.displayName}

       Would you like to update it anyway? [y/n]
       ```
     - If user says 'n', exit gracefully
     - This prevents accidentally updating other people's tickets

3. **Analyze Git State**:
   - Count commits since branch diverged from main:
     ```bash
     COMMIT_COUNT=$(git rev-list --count main..HEAD 2>/dev/null || echo "0")
     ```
   - Check for open/merged PR using GitHub CLI:
     ```bash
     PR_STATE=$(gh pr view --json state,merged 2>/dev/null || echo '{"state":"none"}')
     PR_OPEN=$(echo "$PR_STATE" | jq -r '.state == "OPEN"')
     PR_MERGED=$(echo "$PR_STATE" | jq -r '.merged == true')
     ```
   - Determine git state:
     - If `PR_MERGED == true`: git_state = "merged"
     - Else if `PR_OPEN == true`: git_state = "pr_open"
     - Else if `COMMIT_COUNT > 0`: git_state = "active_development"
     - Else: git_state = "branch_created"

4. **Determine Suggested Status Transition**:
   - Based on current_status and git_state, determine suggested new status:

   | Current Status | Git State | Suggested Status |
   |----------------|-----------|------------------|
   | Backlog, To Do, New | active_development | In Progress |
   | Backlog, To Do, New | branch_created | In Progress |
   | In Progress | pr_open | Code Review |
   | In Progress | merged | Done |
   | Code Review | merged | Done |
   | Any | No activity | No change |

   - Fetch available transitions from JIRA:
     ```bash
     curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
       "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions" \
       -o /tmp/jira-transitions-$JIRA_ID.json
     ```
   - Parse available transitions and check if suggested transition is allowed
   - If suggested transition not available, find closest match or suggest no change

5. **Present Suggestion to User**:
   - Display formatted suggestion:
     ```
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Status Sentinel: JIRA Update Suggestion {if DRY_RUN: "(DRY RUN)"}
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     Ticket: {JIRA_ID}
     Title: {summary}
     Branch: {branch_name}
     Assignee: {assignee or "Unassigned"}

     Current Status: {current_status}
     Git State: {git_state_description}

     Suggested Action: Move to "{suggested_status}"
     Reason: {explanation based on git state}
     {if DRY_RUN: "\n     ⚠️  DRY RUN MODE - No changes will be made to JIRA"}

     Actions:
       [y] Yes, update status {if DRY_RUN: "(preview only)"}
       [n] No, keep current status
       [s] Skip this check for this branch
       [t] Show available transitions
       [?] Help

     Choice:
     ```
   - Wait for user input using `AskUserQuestion` tool
   - Handle responses:
     - `y`: Proceed to step 6 (execute transition)
     - `n`: Exit gracefully, display "Status unchanged"
     - `s`: Store skip preference in git config: `git config jira.status-sentinel.skip.$BRANCH true`, then exit
     - `t`: Display available transitions from transitions API call, then re-prompt
     - `?`: Display help text explaining options, then re-prompt

6. **Execute Status Transition** (if user approved):
   - Find the transition ID for the selected status from the transitions API response
   - **If DRY_RUN is true:**
     - Skip actual JIRA API call
     - Display:
       ```
       🔍 DRY RUN - No changes made

       Would have updated {JIRA_ID}:
         Current: {current_status}
         New: {new_status}
         Transition ID: {transition_id}

       To actually update JIRA, run without --dry-run flag.
       ```
     - Exit successfully
   - **If DRY_RUN is false (normal mode):**
     - Execute transition using JIRA API:
       ```bash
       curl -X POST -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
         -H "Content-Type: application/json" \
         "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions" \
         -d '{"transition": {"id": "'$TRANSITION_ID'"}}'
       ```
     - Verify success (HTTP 204 response)
     - Display confirmation:
       ```
       ✓ Updated {JIRA_ID} status to "{new_status}"

       View ticket: {JIRA_URL}/browse/{JIRA_ID}
       ```
   - Optionally add comment to ticket (if configured):
     ```bash
     curl -X POST -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
       -H "Content-Type: application/json" \
       "$JIRA_URL/rest/api/3/issue/$JIRA_ID/comment" \
       -d '{"body": "Status updated to '\''{new_status}'\'' via Status Sentinel (branch: '$BRANCH', commits: '$COMMIT_COUNT')"}'
     ```

7. **Error Handling**:
   - **No git repository**: Display error "Not in a git repository. Please run this command from within a git repository."
   - **No JIRA credentials**: Display error pointing to MCP config setup
   - **HTTP 401 from JIRA**: Display authentication error with link to token regeneration
   - **HTTP 404 from JIRA**: Display "Ticket {JIRA_ID} not found. Please check the ticket ID."
   - **Transition not allowed**: Display available transitions and suggest alternative
   - **Network errors**: Display "Could not connect to JIRA. Please check your network connection."

### Arguments:
- `--branch <name>`: Check specific branch instead of current branch (optional)
- `--ticket <PROJ-1234>`: Specify JIRA ticket ID manually, skip detection (optional)
- `--dry-run`: Show what would be updated without making changes (optional)
- `--force`: Skip confirmation prompts, auto-approve transitions (use with caution, optional)

### Configuration:
The command reads configuration from `~/.config/claude-code/jira-sentinel.json` if it exists. Configuration options:
- `enabled`: Whether Status Sentinel is enabled globally (default: true)
- `defaultWorkflow`: Default status mappings for git states
- `projectWorkflows`: Project-specific status mappings
- `skipPatterns`: Branch patterns to automatically skip
- `addComments`: Whether to add comments to JIRA when updating status (default: false)

If config file doesn't exist, use sensible defaults.

### Reference:
See the [Status Sentinel SKILL.md](../skills/status-sentinel/SKILL.md) for additional implementation details, configuration examples, and future enhancements.
