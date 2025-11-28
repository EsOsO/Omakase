# Git Hooks

This directory contains custom git hooks for the Omakase repository.

## Pre-Push Hook

The `pre-push` hook prevents accidental direct pushes to the `main` branch and reminds you to use the PR workflow.

### What it does:

- ✅ Detects when you're pushing to `main`
- ⚠️  Shows a warning with the correct workflow
- 🤖 Automatically allows pushes with `[skip ci]` (for bots)
- 🛑 Asks for confirmation before allowing manual pushes to `main`

### Setup

This hook is automatically configured when you run:

```bash
git config core.hooksPath .githooks
```

This is already set up in your local repository.

### Testing

To test the hook, try pushing to main:

```bash
git checkout main
git push
# You should see a warning and be asked for confirmation
```

## Workflow Reminder

**Correct workflow:**

```bash
# 1. Create feature branch
git checkout -b feat/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat(scope): description"

# 3. Push feature branch
git push -u origin feat/my-feature

# 4. Create PR
gh pr create --title "feat(scope): description" --body "..."

# 5. Merge PR
gh pr merge --squash --delete-branch
```

## Bypassing the Hook

If you absolutely need to push to main (emergency), you can:

```bash
# Option 1: Answer 'yes' to the confirmation prompt
git push
# Type 'yes' when asked

# Option 2: Skip hooks (not recommended)
git push --no-verify
```

**Note**: Only use bypass for emergencies. The PR workflow is there for a reason!
