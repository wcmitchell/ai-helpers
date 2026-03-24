# Status Sentinel: MCP vs Curl Analysis

## Current Implementation

We're using **curl** to call JIRA REST API directly:

```bash
# Extract credentials from MCP config
JIRA_URL=$(jq -r '.mcpServers.atlassian.env.JIRA_URL' ~/.config/claude-code/mcp.json)
JIRA_USERNAME=$(jq -r '.mcpServers.atlassian.env.JIRA_USERNAME' ~/.config/claude-code/mcp.json)
JIRA_API_TOKEN=$(jq -r '.mcpServers.atlassian.env.JIRA_API_TOKEN' ~/.config/claude-code/mcp.json)

# Fetch ticket
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID?fields=summary,status,assignee,transitions"

# Get transitions
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions"

# Perform transition
curl -X POST -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$JIRA_ID/transitions" \
  -d '{"transition": {"id": "'$TRANSITION_ID'"}}'
```

## Alternative: Using MCP Tools

We could use MCP tools instead:

```python
# Fetch ticket
issue = mcp__atlassian__jira_get_issue(issue_key=JIRA_ID)

# Get transitions
transitions = mcp__atlassian__jira_get_issue_transitions(issue_key=JIRA_ID)

# Perform transition
mcp__atlassian__jira_transition_issue(
    issue_key=JIRA_ID,
    transition_id=transition_id
)

# Optional: Add comment
mcp__atlassian__jira_add_issue_comment(
    issue_key=JIRA_ID,
    comment_body="Status updated to 'In Progress' via Status Sentinel"
)
```

## Pattern Survey Across Jira Plugin

| Command | Approach | Operation Type | Reasoning |
|---------|----------|----------------|-----------|
| **backlog.md** | curl | Bulk (40K tickets) | Avoid token consumption, save to disk |
| **solve.md** | curl | Single ticket | Historical choice, works fine |
| **status-rollup.md** | MCP | Single ticket + comment | Clean, simple code |
| **create.md** | MCP | Create issues | Type-safe, validated |
| **categorize-activity-type.md** | MCP | Single ticket update | Clean, simple code |
| **grooming.md** | curl | Bulk analysis | Avoid token limits |

**Conclusion:** Mixed pattern - **bulk operations use curl**, **single-ticket operations can use either**.

## Tradeoffs

### Curl Approach (Current)

**Pros:**
- ✅ No token consumption per API call
- ✅ Direct control over requests
- ✅ Can save responses to files easily
- ✅ No dependency on MCP server being running
- ✅ Better for bulk operations
- ✅ Consistent with backlog.md and solve.md

**Cons:**
- ❌ Manual JSON parsing (jq)
- ❌ Manual error handling
- ❌ More verbose code
- ❌ Need to handle auth ourselves
- ❌ Harder to debug API issues

### MCP Tools Approach

**Pros:**
- ✅ Clean, concise code
- ✅ Built-in error handling
- ✅ Type-safer responses
- ✅ Abstracts API details
- ✅ Validated by MCP server
- ✅ Easier to maintain
- ✅ Consistent with status-rollup.md and create.md

**Cons:**
- ❌ Each MCP call consumes tokens (Claude processes request AND response)
- ❌ MCP server must be running
- ❌ Less control over exact requests
- ❌ Can hit token limits on large operations
- ❌ Adds dependency chain (MCP server → JIRA API)

## Token Consumption Analysis

For Status Sentinel specifically:

**Typical workflow:**
1. Get issue details (1 MCP call)
2. Get transitions (1 MCP call)
3. Transition issue (1 MCP call)
4. Optionally add comment (1 MCP call)

**Total: 3-4 MCP calls per status update**

**Token estimate:**
- Each MCP call: ~500-1000 tokens (request + response)
- Total per update: ~2000-4000 tokens

**For a single-ticket command like Status Sentinel, this is acceptable.**

## Recommendation

### For Status Sentinel: Use MCP Tools

**Why:**
1. **Operation scope**: Single ticket only, not bulk
2. **Code clarity**: Much simpler and more maintainable
3. **Token cost**: Acceptable for single-ticket ops (2-4K tokens)
4. **Error handling**: Built-in validation
5. **Consistency**: Aligns with other single-ticket commands (status-rollup, create, categorize)
6. **Future-proof**: If MCP tools improve, we benefit automatically

### Keep Curl For: Bulk Operations

Commands that process many tickets (backlog, grooming) should continue using curl to avoid:
- Token explosion (40K tickets × 1K tokens = 40M tokens!)
- Performance degradation
- Token limit errors

## Implementation Change Proposal

Update `sync-status.md` to use MCP tools:

```markdown
## Implementation

### Process Flow

1. **Parse Arguments and Detect JIRA Ticket**
   - Same as current (use extract-jira-id.sh)

2. **Fetch JIRA Ticket Details**
   - Use MCP tool instead of curl:
     ```python
     issue = mcp__atlassian__jira_get_issue(issue_key=JIRA_ID)

     summary = issue["fields"]["summary"]
     current_status = issue["fields"]["status"]["name"]
     assignee = issue["fields"]["assignee"]
     assignee_email = assignee["emailAddress"] if assignee else None
     ```

3. **Check Ownership**
   - Compare assignee_email with JIRA_USERNAME from config
   - Warn if ticket belongs to someone else

4. **Analyze Git State**
   - Same as current (git commands)

5. **Get Available Transitions**
   - Use MCP tool instead of curl:
     ```python
     transitions = mcp__atlassian__jira_get_issue_transitions(issue_key=JIRA_ID)

     # Find matching transition
     for t in transitions:
         if t["name"].lower() == suggested_status.lower():
             transition_id = t["id"]
             break
     ```

6. **Present Suggestion to User**
   - Same as current (interactive prompt)

7. **Execute Transition** (if approved)
   - Use MCP tool instead of curl:
     ```python
     mcp__atlassian__jira_transition_issue(
         issue_key=JIRA_ID,
         transition_id=transition_id
     )
     ```

8. **Optionally Add Comment**
   - Use MCP tool (new capability!):
     ```python
     if add_comments_enabled:
         mcp__atlassian__jira_add_issue_comment(
             issue_key=JIRA_ID,
             comment_body=f"Status updated to '{new_status}' via Status Sentinel\n\nBranch: {branch}\nCommits: {commit_count}"
         )
     ```
```

### Benefits of This Change

1. **Simpler code**: ~40 lines of bash/jq/curl → ~10 lines of MCP calls
2. **Better errors**: MCP handles auth, 404s, network issues
3. **Comment support**: Easy to add comments (currently not implemented with curl)
4. **Maintainability**: Less bash scripting, more declarative
5. **Consistency**: Aligns with other single-ticket commands

### Risks

1. **MCP server dependency**: If MCP server isn't running, command fails
   - Mitigation: Check MCP availability, fall back to curl if needed

2. **Token consumption**: 2-4K tokens per status update
   - Mitigation: Acceptable for single-ticket ops, document in README

3. **Debugging**: Less visibility into raw API calls
   - Mitigation: MCP server logs show all API calls

## Decision Matrix

| Factor | Curl | MCP | Winner |
|--------|------|-----|--------|
| Code simplicity | ❌ | ✅ | MCP |
| Token efficiency | ✅ | ❌ | Curl |
| Error handling | ❌ | ✅ | MCP |
| Bulk operations | ✅ | ❌ | Curl |
| Single ticket ops | ≈ | ✅ | MCP |
| Maintainability | ❌ | ✅ | MCP |
| Debugging | ✅ | ❌ | Curl |
| Comment support | ❌ | ✅ | MCP |
| Consistency with plugin | ≈ | ≈ | Tie |

**For Status Sentinel (single-ticket): MCP wins 6-2**

## Recommendation

✅ **Switch Status Sentinel to use MCP tools**

Rationale:
- Single-ticket scope makes token cost acceptable
- Much cleaner code
- Better error handling
- Enables easy comment addition
- Aligns with other single-ticket commands (status-rollup, create, categorize)

Keep curl approach for bulk commands (backlog, grooming).

## Next Steps

1. Update `sync-status.md` implementation section to use MCP tools
2. Test with real ENGPROD tickets
3. Document MCP dependency in Prerequisites
4. Add fallback to curl if MCP unavailable (optional, nice-to-have)
