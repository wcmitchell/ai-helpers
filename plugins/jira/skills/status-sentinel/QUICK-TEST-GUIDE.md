# Status Sentinel: Quick Test Guide

## Prerequisites Checklist

- [x] JIRA credentials in `~/.config/claude-code/mcp.json`
- [x] Working in a git repository
- [x] Have test ENGPROD ticket ready
- [ ] Test ticket is assigned to you (or unassigned)

## Your Test Ticket Setup

**Ticket:** `ENGPROD-____` (fill in your ticket number)

**Pre-test checklist:**
1. ✅ Ticket exists and you can access it
2. ✅ Current status is "Backlog" or "To Do" or "New" (so we can move it)
3. ✅ Ticket is assigned to you OR unassigned (so ownership check passes)
4. ✅ You have a poorly written description (perfect for Refinement Architect later!)

## Test Approach: Incremental Validation

We'll test in small steps, verifying each piece works before moving on.

### Phase 1: Detection (No JIRA API calls yet)

**Goal:** Verify branch parsing and JIRA ID extraction works

**Steps:**
```bash
# 1. Create branch with your ticket ID
git checkout -b ENGPROD-XXXX-test-sentinel

# 2. Test the helper script directly
cd plugins/jira/skills/status-sentinel
./extract-jira-id.sh

# Expected output:
# ENGPROD-XXXX
# source: branch_name
# confidence: high
```

**Validation:**
- [ ] Script extracts correct JIRA ID
- [ ] Reports "branch_name" as source
- [ ] Reports "high" confidence

**If this fails:** Fix the detection logic before proceeding.

---

### Phase 2: JIRA API Connection (Read-only test)

**Goal:** Verify we can fetch the ticket without errors

**Test manually with curl:**
```bash
# Extract credentials
JIRA_URL=$(jq -r '.mcpServers.atlassian.env.JIRA_URL' ~/.config/claude-code/mcp.json)
JIRA_USERNAME=$(jq -r '.mcpServers.atlassian.env.JIRA_USERNAME' ~/.config/claude-code/mcp.json)
JIRA_API_TOKEN=$(jq -r '.mcpServers.atlassian.env.JIRA_API_TOKEN' ~/.config/claude-code/mcp.json)

# Fetch your test ticket
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/ENGPROD-XXXX?fields=summary,status,assignee" | jq .

# Expected: JSON response with ticket details
```

**Validation:**
- [ ] No authentication error (401)
- [ ] No "not found" error (404)
- [ ] See your ticket summary
- [ ] See current status
- [ ] See assignee (you or null)

**If this fails:**
- Check credentials in mcp.json
- Verify ticket ID is correct
- Check network/VPN connection

---

### Phase 3: Status Sentinel Dry Run

**Goal:** Run Status Sentinel in dry-run mode (no changes to JIRA)

**Steps:**
```bash
# Go back to repo root
cd /home/cmitchel/src/RH/ai-helpers

# Ensure you're on the test branch
git branch --show-current
# Should show: ENGPROD-XXXX-test-sentinel

# Run Status Sentinel in dry-run mode
/jira:sync-status --dry-run
```

**What to watch for:**
1. Does it detect the JIRA ID from your branch? ✓
2. Does it fetch the ticket successfully? ✓
3. Does it show the current status? ✓
4. Does it check if you're the assignee? ✓
5. Does it analyze git state correctly? ✓
6. Does it suggest an appropriate status? ✓
7. Does it indicate "DRY RUN - no changes made"? ✓

**Validation:**
- [ ] All detection works
- [ ] Correct status shown
- [ ] Appropriate suggestion
- [ ] No actual JIRA update (dry-run mode)

**If this fails:** Debug step-by-step based on where it fails.

---

### Phase 4: Make a Commit (Test Git State Analysis)

**Goal:** Verify git state detection works

**Steps:**
```bash
# Make a trivial commit
echo "Testing Status Sentinel" >> .test-sentinel
git add .test-sentinel
git commit -m "[ENGPROD-XXXX] Test Status Sentinel"

# Run dry-run again
/jira:sync-status --dry-run
```

**Expected changes:**
- Git state should now show "active development (1 commit)"
- Suggestion should still be "In Progress" (if ticket is in Backlog/New)

**Validation:**
- [ ] Detects commits correctly
- [ ] Shows commit count
- [ ] Adjusts suggestion based on git state

---

### Phase 5: Live Update (The Real Test!)

**Goal:** Actually update JIRA status

**⚠️ WARNING:** This will modify your JIRA ticket. Make sure you're okay with that!

**Steps:**
```bash
# Run Status Sentinel for real
/jira:sync-status

# When prompted, choose [y] to approve the update
```

**What should happen:**
1. Detects ticket from branch
2. Shows current status and suggested status
3. Asks for confirmation
4. You type `y`
5. Updates JIRA
6. Shows confirmation message

**Validation:**
- [ ] Prompt appears correctly
- [ ] Update succeeds (no errors)
- [ ] Confirmation message shown
- [ ] **Manually check JIRA ticket** - status should be changed!

**Verification:**
```bash
# Open ticket in browser
echo "https://redhat.atlassian.net/browse/ENGPROD-XXXX"

# Or fetch again via API
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  "$JIRA_URL/rest/api/3/issue/ENGPROD-XXXX?fields=status" | jq '.fields.status.name'

# Should show new status (e.g., "In Progress")
```

---

### Phase 6: Edge Cases (Optional)

Once basic functionality works, test edge cases:

#### Test 6a: Already Correct Status
```bash
# Run again (ticket should already be "In Progress")
/jira:sync-status

# Expected: "Status is already correct, no update needed"
```

#### Test 6b: Skip This Branch
```bash
# Run and choose [s] to skip
/jira:sync-status
# Choose: s

# Verify skip was saved
git config --get jira.status-sentinel.skip.ENGPROD-XXXX-test-sentinel
# Should output: true

# Run again - should skip automatically
/jira:sync-status
# Expected: "This branch is configured to skip status checks"
```

#### Test 6c: No JIRA ID in Branch
```bash
# Create branch without JIRA ID
git checkout -b test-no-jira

# Run Status Sentinel
/jira:sync-status

# Expected: Clear error message with suggestions
```

#### Test 6d: Manual Ticket Specification
```bash
# Still on test-no-jira branch
/jira:sync-status --ticket ENGPROD-XXXX

# Expected: Works despite branch name lacking JIRA ID
```

---

## Troubleshooting Common Issues

### "Could not detect JIRA ticket"
- **Cause:** Branch name doesn't contain JIRA ID
- **Fix:** Rename branch or use `--ticket` flag
- **Test:** Run `extract-jira-id.sh` to debug

### "HTTP 401 Unauthorized"
- **Cause:** Invalid credentials
- **Fix:** Check mcp.json credentials, regenerate token if needed
- **Test:** Try curl command from Phase 2

### "HTTP 404 Not Found"
- **Cause:** Ticket doesn't exist or you don't have access
- **Fix:** Verify ticket ID, check JIRA permissions
- **Test:** Open ticket in browser

### "Transition not allowed"
- **Cause:** JIRA workflow doesn't allow that transition
- **Fix:** Check available transitions in JIRA
- **Test:** Fetch transitions via API to see what's allowed

### "Ticket assigned to someone else"
- **Cause:** Ownership check failed
- **Fix:** Assign ticket to yourself or use different test ticket
- **Test:** Check assignee field in JIRA

---

## Success Criteria

Status Sentinel is working if:

- [x] Detects JIRA ID from branch name
- [x] Fetches ticket details from JIRA
- [x] Analyzes git state (commits, PR status)
- [x] Suggests appropriate status transition
- [x] Updates JIRA when approved
- [x] Handles errors gracefully
- [x] Dry-run mode works

## After Testing

1. **Document bugs:** Note anything that doesn't work
2. **Clean up:** Delete test branch, reset ticket status if needed
3. **Report findings:** Share what worked and what didn't
4. **Iterate:** Fix issues, improve UX

## Your Test Notes

**Ticket used:** ENGPROD-_____

**Test results:**
```
Phase 1 (Detection): ✓ / ✗
Notes: _____________________

Phase 2 (API): ✓ / ✗
Notes: _____________________

Phase 3 (Dry-run): ✓ / ✗
Notes: _____________________

Phase 4 (Git state): ✓ / ✗
Notes: _____________________

Phase 5 (Live update): ✓ / ✗
Notes: _____________________
```

**Issues found:**
1. _____________________
2. _____________________

**Suggested improvements:**
1. _____________________
2. _____________________
