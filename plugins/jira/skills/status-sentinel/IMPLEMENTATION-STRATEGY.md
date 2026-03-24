# Status Sentinel: MCP-First with Curl Fallback

## Implementation Strategy

**Goal:** Try MCP tools first (cleaner code), fall back to curl if MCP unavailable (always works).

## Detection Pattern

```markdown
## Implementation

### MCP Availability Detection

Before executing any JIRA operations, detect if MCP is available:

1. **Try MCP first:**
   ```python
   try:
       # Test if MCP tools are available
       test_issue = mcp__atlassian__jira_get_issue(issue_key="TEST-1")
       USE_MCP = True
   except:
       # MCP not available, use curl fallback
       USE_MCP = False
   ```

2. **If MCP unavailable, extract credentials for curl:**
   ```bash
   if ! USE_MCP; then
       MCP_CONFIG="$HOME/.config/claude-code/mcp.json"
       JIRA_URL=$(jq -r '.mcpServers.atlassian.env.JIRA_URL' "$MCP_CONFIG")
       JIRA_USERNAME=$(jq -r '.mcpServers.atlassian.env.JIRA_USERNAME' "$MCP_CONFIG")
       JIRA_API_TOKEN=$(jq -r '.mcpServers.atlassian.env.JIRA_API_TOKEN' "$MCP_CONFIG")
   fi
   ```

### Process Flow with Fallback

#### Step 1: Detect JIRA Ticket
- Same as current (branch name parsing)

#### Step 2: Fetch Ticket Details

**If MCP available:**
```python
issue = mcp__atlassian__jira_get_issue(issue_key=JIRA_ID)
summary = issue["fields"]["summary"]
current_status = issue["fields"]["status"]["name"]
assignee = issue["fields"]["assignee"]
```

**If MCP unavailable (curl fallback):**
```bash
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID?fields=summary,status,assignee" \
  -o /tmp/jira-$JIRA_ID.json

summary=$(jq -r '.fields.summary' /tmp/jira-$JIRA_ID.json)
current_status=$(jq -r '.fields.status.name' /tmp/jira-$JIRA_ID.json)
assignee_email=$(jq -r '.fields.assignee.emailAddress // ""' /tmp/jira-$JIRA_ID.json)
```

#### Step 3: Get Available Transitions

**If MCP available:**
```python
transitions = mcp__atlassian__jira_get_issue_transitions(issue_key=JIRA_ID)

for t in transitions:
    if t["name"].lower() == suggested_status.lower():
        transition_id = t["id"]
        break
```

**If MCP unavailable (curl fallback):**
```bash
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions" \
  -o /tmp/jira-transitions-$JIRA_ID.json

transition_id=$(jq -r --arg status "$suggested_status" \
  '.transitions[] | select(.name == $status) | .id' \
  /tmp/jira-transitions-$JIRA_ID.json)
```

#### Step 4: Execute Transition

**If MCP available:**
```python
mcp__atlassian__jira_transition_issue(
    issue_key=JIRA_ID,
    transition_id=transition_id
)

# Optionally add comment (only easy with MCP)
if add_comments_enabled:
    mcp__atlassian__jira_add_issue_comment(
        issue_key=JIRA_ID,
        comment_body=f"Status updated to '{new_status}' via Status Sentinel"
    )
```

**If MCP unavailable (curl fallback):**
```bash
curl -X POST -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions" \
  -d "{\"transition\": {\"id\": \"$transition_id\"}}"

# Comments not implemented in curl fallback (too complex)
```

## Benefits of This Approach

### When MCP Available ✅
- Clean, simple code
- Easy comment support
- Better error messages
- ~2-4K tokens (acceptable)

### When MCP Unavailable ✅
- Still works!
- Uses curl with credentials from mcp.json
- Zero token consumption
- No additional setup needed

### Overall ✅
- **Best of both worlds**
- **Low complexity** (just an if/else branch)
- **Graceful degradation**
- **Future-proof** (benefits from MCP improvements)

## Complexity Assessment

**Added complexity:** Minimal

```markdown
# Pseudocode
if mcp_available():
    use_mcp_tools()  # Clean, simple
else:
    use_curl()       # Fallback, works always

# Implementation: ~20 extra lines for the if/else logic
```

**Benefit:** High
- Users with MCP get better UX
- Users without MCP still get full functionality
- No forced dependency on MCP server

## Recommendation

✅ **Yes, implement MCP-first with curl fallback**

This is **NOT** added complexity for low benefit. It's:
- **Medium complexity** (one if/else per operation)
- **High benefit** (best of both worlds)
- **Graceful degradation** (always works)
- **User-friendly** (no forced setup)

## Testing Requirements

Test both paths:

### Test 1: With MCP
```bash
# Start MCP server
claude mcp add --transport stdio jira -- uvx mcp-atlassian

# Test Status Sentinel
/jira:sync-status

# Should use MCP tools
# Should support comment adding (if enabled)
```

### Test 2: Without MCP
```bash
# Stop MCP server
claude mcp remove jira

# Test Status Sentinel
/jira:sync-status

# Should use curl fallback
# Should still work perfectly
```

## Implementation Note

The fallback is **automatic and transparent** to the user. They don't need to:
- Configure anything special
- Know which path is being used
- Care about the implementation

It Just Works™ either way!
