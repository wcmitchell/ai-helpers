# Status Sentinel

Automatically sync JIRA ticket status based on git branch and commit activity.

## Quick Start

```bash
# Create a branch with JIRA ID
git checkout -b ENGPROD-9711-fix-bug

# Check if status needs updating
/jira:sync-status

# Follow the prompts to update JIRA
```

## Files

- `SKILL.md` - Complete implementation guide
- `extract-jira-id.sh` - Helper script to extract JIRA IDs from branches/commits
- `README.md` - This file

## How It Works

1. Detects JIRA ticket from your branch name
2. Checks current git state (commits, PRs, etc.)
3. Suggests appropriate JIRA status transition
4. Updates JIRA on your approval

## Development Status

**Phase 1: Manual Command** ✅ (Current)
- [x] SKILL.md implementation guide
- [x] Command definition (`/jira:sync-status`)
- [x] Helper scripts for JIRA ID extraction
- [ ] Full implementation (pending)
- [ ] Testing

**Phase 2: Git Hooks** (Future)
- [ ] post-checkout hook (branch creation)
- [ ] prepare-commit-msg hook (commit message enhancement)
- [ ] post-commit hook (status suggestions)

## Testing

To test the JIRA ID extraction:

```bash
# Test with current branch
./extract-jira-id.sh

# Test with specific branch name
./extract-jira-id.sh "ENGPROD-1234-feature"

# Should output:
# ENGPROD-1234
# source: branch_name (to stderr)
# confidence: high (to stderr)
```

## Configuration

See [Command Documentation](../../commands/sync-status.md#configuration) for configuration options.

## See Also

- [SKILL.md](./SKILL.md) - Full implementation details
- [sync-status command](../../commands/sync-status.md) - User-facing command docs
- [Progress Chronicler](../progress-chronicler/) - Auto-generate progress updates (coming soon)
