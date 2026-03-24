# Status Sentinel - Testing Guide

## Prerequisites

Before testing, ensure:

- [ ] JIRA credentials configured in `~/.config/claude-code/mcp.json`
- [ ] Working in a git repository
- [ ] Have access to ENGPROD project in JIRA
- [ ] Have a test ticket assigned to you in ENGPROD

## Test Ticket Setup

1. **Find a suitable test ticket** from `/jira:backlog ENGPROD`:
   - Should be in "Backlog", "To Do", or "New" status
   - Should be assigned to you (or unassigned)
   - Example: ENGPROD-XXXX

2. **Assign ticket to yourself** (if unassigned):
   ```bash
   # Via JIRA web UI or let Status Sentinel handle it
   ```

## Test Scenarios

### Scenario 1: Branch Name Detection (Happy Path)

**Setup:**
```bash
# Create a branch with JIRA ID
git checkout -b ENGPROD-XXXX-test-status-sentinel
```

**Test:**
```bash
# Run Status Sentinel
/jira:sync-status
```

**Expected:**
- ✓ Detects `ENGPROD-XXXX` from branch name
- ✓ Shows ticket title and current status
- ✓ Shows you as assignee (or warns if assigned to someone else)
- ✓ Suggests moving to "In Progress" (if currently in Backlog/New)
- ✓ Prompts for confirmation

**Verify:**
- [ ] JIRA ID detected correctly
- [ ] Ticket details displayed
- [ ] Ownership check passed
- [ ] Suggestion makes sense
- [ ] Able to approve/decline

---

### Scenario 2: After Making Commits

**Setup:**
```bash
# Make some commits
echo "test" >> README.md
git add README.md
git commit -m "[ENGPROD-XXXX] Test commit for Status Sentinel"
```

**Test:**
```bash
/jira:sync-status
```

**Expected:**
- ✓ Detects "active development" state (X commits)
- ✓ Still suggests "In Progress" if not already there
- ✓ Shows commit count in summary

**Verify:**
- [ ] Commit count displayed
- [ ] Status suggestion appropriate

---

### Scenario 3: Branch Without JIRA ID

**Setup:**
```bash
# Create branch without JIRA ID
git checkout -b test-no-jira-id
```

**Test:**
```bash
/jira:sync-status
```

**Expected:**
- ✓ Displays "No JIRA ticket detected" error
- ✓ Suggests remedies:
  - Rename branch
  - Use git config
  - Use --ticket flag

**Verify:**
- [ ] Error message clear and helpful
- [ ] Suggestions provided

---

### Scenario 4: Manual Ticket Specification

**Setup:**
```bash
# Same branch as Scenario 3
```

**Test:**
```bash
/jira:sync-status --ticket ENGPROD-XXXX
```

**Expected:**
- ✓ Uses specified ticket ID
- ✓ Skips detection
- ✓ Works normally

**Verify:**
- [ ] Ticket specified via flag works
- [ ] Detection bypassed

---

### Scenario 5: Someone Else's Ticket

**Setup:**
```bash
# Create branch for a ticket assigned to someone else
# (You'll need to find one in the backlog)
git checkout -b ENGPROD-YYYY-not-mine
```

**Test:**
```bash
/jira:sync-status
```

**Expected:**
- ✓ Detects ticket
- ✓ Shows it's assigned to someone else
- ✓ Warns before allowing update
- ✓ Asks for confirmation

**Verify:**
- [ ] Ownership warning displayed
- [ ] Can choose to proceed or cancel
- [ ] Respectful of other people's work

---

### Scenario 6: Already Correct Status

**Setup:**
```bash
# Use a ticket that's already "In Progress"
# Or manually update your test ticket to "In Progress" in JIRA first
git checkout -b ENGPROD-XXXX-already-in-progress
```

**Test:**
```bash
/jira:sync-status
```

**Expected:**
- ✓ Detects ticket
- ✓ Sees status is already appropriate
- ✓ Displays "No update needed" or similar
- ✓ Doesn't suggest change

**Verify:**
- [ ] Recognizes status is already correct
- [ ] Doesn't suggest unnecessary updates

---

### Scenario 7: Dry Run Mode

**Setup:**
```bash
git checkout -b ENGPROD-XXXX-dry-run-test
```

**Test:**
```bash
/jira:sync-status --dry-run
```

**Expected:**
- ✓ Goes through all detection/analysis
- ✓ Shows what WOULD be updated
- ✓ Does NOT actually update JIRA
- ✓ Clearly indicates dry-run mode

**Verify:**
- [ ] Dry-run mode indicated
- [ ] No actual JIRA update performed
- [ ] Preview shown correctly

---

### Scenario 8: Skip This Branch

**Setup:**
```bash
git checkout -b ENGPROD-XXXX-skip-test
```

**Test:**
```bash
/jira:sync-status
# When prompted, choose [s] to skip
```

**Expected:**
- ✓ Stores skip preference
- ✓ Future runs on this branch are skipped

**Verify:**
```bash
# Check git config was set
git config --get jira.status-sentinel.skip.ENGPROD-XXXX-skip-test
# Should output: true

# Run again
/jira:sync-status
# Should skip automatically
```

---

## Error Scenarios

### No Credentials

**Setup:**
```bash
# Temporarily rename mcp.json
mv ~/.config/claude-code/mcp.json ~/.config/claude-code/mcp.json.bak
```

**Test:**
```bash
/jira:sync-status
```

**Expected:**
- ✓ Detects missing credentials
- ✓ Shows helpful error message
- ✓ Points to configuration docs

**Cleanup:**
```bash
mv ~/.config/claude-code/mcp.json.bak ~/.config/claude-code/mcp.json
```

**Verify:**
- [ ] Error message clear
- [ ] Helpful guidance provided

---

### Invalid Ticket ID

**Test:**
```bash
/jira:sync-status --ticket INVALID-99999
```

**Expected:**
- ✓ JIRA returns 404
- ✓ Clear error message
- ✓ Suggests checking ticket ID

**Verify:**
- [ ] 404 handled gracefully
- [ ] Error message helpful

---

## Success Criteria

Status Sentinel is working correctly if:

- [x] JIRA ID detection works from branch names
- [x] Git state analysis is accurate (commits, PR status)
- [x] Status suggestions are appropriate
- [x] Ownership checks prevent updating others' tickets
- [x] JIRA API integration works (fetch + update)
- [x] User confirmation flow is clear
- [x] Error handling is robust
- [x] Dry-run mode works
- [x] Skip functionality works

## Next Steps After Testing

1. **Document any bugs** found during testing
2. **Refine status transition logic** based on actual JIRA workflows
3. **Add project-specific configurations** if needed
4. **Consider git hook integration** (Phase 2)
5. **Share with team** for feedback

## Testing Notes

Use this space to document your testing experience:

```
Date: _______
Tester: _______

Test Results:
- Scenario 1: ✓ / ✗ / Notes: _______________
- Scenario 2: ✓ / ✗ / Notes: _______________
- Scenario 3: ✓ / ✗ / Notes: _______________
...

Issues Found:
1. _______________________
2. _______________________

Suggested Improvements:
1. _______________________
2. _______________________
```
