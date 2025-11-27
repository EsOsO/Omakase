# Branch Protection Configuration

This document describes the branch protection rules for the Omakase repository and how to manage them.

## Current Configuration (Solo Maintainer)

The `main` branch is currently configured for a **solo maintainer** workflow:

### Protection Rules

| Rule | Status | Description |
|------|--------|-------------|
| **Pull Requests Required** | ✅ Enabled | All changes must go through PR |
| **Approvals Required** | ❌ Disabled | No approval needed (solo maintainer) |
| **Status Checks** | ✅ Enabled | CI checks must pass before merge |
| **Conversation Resolution** | ✅ Enabled | All comments must be resolved |
| **Enforce on Admins** | ❌ Disabled | Admins can bypass restrictions |
| **Force Pushes** | ❌ Blocked | No force pushes allowed |
| **Branch Deletion** | ❌ Blocked | Cannot delete main branch |

### What This Means

As the sole maintainer, you:
- ✅ **MUST** create pull requests for all changes (no direct pushes to `main`)
- ✅ **CAN** merge your own PRs without external approval
- ✅ **MUST** resolve all PR comments before merging
- ✅ **MUST** wait for CI checks to pass (when configured)
- ❌ **CANNOT** force push to main
- ❌ **CANNOT** delete the main branch

## Workflow for Solo Maintainer

```bash
# 1. Create feature branch
git checkout -b feat/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat(scope): description"

# 3. Push branch
git push -u origin feat/my-feature

# 4. Create PR
gh pr create --title "feat(scope): description" --body "..."

# 5. Merge PR (no approval needed)
gh pr merge --squash --delete-branch
```

## When You Add More Maintainers

When you invite additional maintainers to the project, update the branch protection to require peer reviews:

### Configuration for Multiple Maintainers

```bash
# Update branch protection to require 1 approval
cat > /tmp/branch_protection_team.json << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
EOF

# Apply the new configuration
gh api -X PUT "repos/EsOsO/Omakase/branches/main/protection" \
  --input /tmp/branch_protection_team.json
```

### Team Workflow

With multiple maintainers:
- ✅ **1 approval required** from another maintainer
- ✅ **Enforce on admins** - Even admins need approval
- ✅ **Stale reviews dismissed** - Re-review after new commits
- ✅ Maintainers review each other's PRs

## Managing Branch Protection with GitHub CLI

### View Current Protection

```bash
gh api "repos/EsOsO/Omakase/branches/main/protection" | jq
```

### Add Status Check Requirements

When you enable CI workflows (validate.yml), add them as required checks:

```bash
gh api -X PATCH "repos/EsOsO/Omakase/branches/main/protection/required_status_checks" \
  -f strict=true \
  -f contexts[]="validate" \
  -f contexts[]="docs"
```

### Temporarily Disable Protection

For emergency fixes (use sparingly):

```bash
# Disable protection
gh api -X DELETE "repos/EsOsO/Omakase/branches/main/protection"

# Make emergency fix directly on main
git checkout main
# ... make changes ...
git push

# Re-enable protection
gh api -X PUT "repos/EsOsO/Omakase/branches/main/protection" \
  --input /path/to/protection-config.json
```

## Best Practices

### For Solo Maintainers

1. **Always use PRs** - Even without required approvals, PRs provide:
   - Clear change history
   - CI validation
   - Documentation of decisions
   - Easy rollback if needed

2. **Self-review your PRs** - Before merging:
   - Review the diff carefully
   - Check CI results
   - Verify documentation is updated
   - Ensure tests pass

3. **Keep PRs focused** - One feature/fix per PR for easier review and rollback

### For Teams

1. **Constructive reviews** - Focus on:
   - Code quality and maintainability
   - Security implications
   - Documentation completeness
   - Test coverage

2. **Timely reviews** - Aim to review PRs within 24-48 hours

3. **Clear communication** - Use PR comments to explain decisions

## Status Check Configuration

### Available Workflows

| Workflow | File | Purpose | Required |
|----------|------|---------|----------|
| **Documentation** | `docs.yml` | Build MkDocs site | ✅ Yes |
| **Validation** | `validate.yml` | Lint, test, security | ⏸️ Disabled |
| **Deploy** | `deploy.yml` | Deployment automation | ⏸️ Disabled |

### Enabling Workflows as Status Checks

1. **Enable disabled workflows** (move from `workflows-disabled/`)
2. **Wait for first successful run**
3. **Add as required checks**:

```bash
gh api -X PATCH \
  "repos/EsOsO/Omakase/branches/main/protection/required_status_checks" \
  -f strict=true \
  -f contexts[]="docs" \
  -f contexts[]="validate"
```

## Troubleshooting

### "Required status checks not found"

- Workflows must run at least once before being added as required checks
- Push a commit to trigger the workflow
- Then add it as a required check

### "Changes must be made through a pull request"

- This is expected! Create a PR instead of pushing directly
- Even as admin, follow the PR workflow

### "Pull request cannot be merged"

Check:
- ✅ All conversations resolved?
- ✅ CI checks passed?
- ✅ Branch up to date with main?

## References

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub CLI API Reference](https://cli.github.com/manual/gh_api)
- [Project Standards](.github/PROJECT_STANDARDS.md)

---

**Last Updated**: 2025-11-27
**Current Mode**: Solo Maintainer
**Maintainers**: @EsOsO
