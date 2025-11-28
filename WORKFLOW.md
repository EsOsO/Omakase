# Development Workflow Quick Reference

This document provides a quick reference for the development workflow used in this repository.

## 🔄 Standard Development Workflow

### 1️⃣ Start a New Feature/Fix

```bash
# Update main branch
git checkout main
git pull

# Create feature branch (use appropriate prefix)
git checkout -b feat/feature-name      # For new features
git checkout -b fix/bug-name           # For bug fixes
git checkout -b docs/documentation     # For documentation
git checkout -b chore/maintenance      # For maintenance tasks
```

### 2️⃣ Make Your Changes

```bash
# Make changes to files
# ...

# Stage changes
git add .

# Commit with conventional commit message
git commit -m "feat(scope): description of change"
```

### 3️⃣ Push and Create PR

```bash
# Push feature branch to remote
git push -u origin feat/feature-name

# Create pull request
gh pr create \
  --title "feat(scope): description" \
  --body "Detailed description of changes..."

# Or use interactive mode
gh pr create
```

### 4️⃣ Review and Merge

```bash
# View PR status
gh pr status

# View PR diff
gh pr diff [PR-NUMBER]

# Approve your PR (solo maintainer)
gh pr review [PR-NUMBER] --approve

# Merge PR (squash commits and delete branch)
gh pr merge [PR-NUMBER] --squash --delete-branch

# Or merge interactively
gh pr merge [PR-NUMBER]
```

### 5️⃣ Clean Up Local Branch

```bash
# Switch back to main
git checkout main

# Pull the merged changes
git pull

# Delete local feature branch (if not auto-deleted)
git branch -d feat/feature-name
```

## 📝 Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types:
- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `perf`: Performance improvements
- `ci`: CI/CD changes

### Breaking Changes:
- Add `!` after type/scope: `feat(api)!: change endpoint`
- Or add `BREAKING CHANGE:` in footer

### Examples:

```bash
# Feature
git commit -m "feat(authelia): add new OIDC client for Nextcloud"

# Bug fix
git commit -m "fix(traefik): resolve SSL certificate issue"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Breaking change
git commit -m "feat(api)!: change authentication endpoint"
```

## 🚨 Branch Protection Rules

The `main` branch is protected:

- ✅ **Pull requests required** - No direct pushes allowed
- ✅ **Pre-push hook** - Warns you before pushing to main
- ⚠️  **Admin bypass available** - You CAN push directly, but DON'T
- 🤖 **Bot exception** - Automated changelog commits allowed

### What This Means:

- **Always use feature branches** - Even for small changes
- **Always create PRs** - Provides audit trail and CI validation
- **Self-approval is OK** - As solo maintainer, you can approve your own PRs
- **Emergency bypass** - Available but discouraged (use `git push --no-verify`)

## 🛠️ Common Operations

### View Current Branch

```bash
git branch --show-current
```

### List All Branches

```bash
git branch -a
```

### Switch Branches

```bash
git checkout main
git checkout feat/feature-name
```

### View PR List

```bash
gh pr list
gh pr list --state all
```

### View Recent Commits

```bash
git log --oneline -10
```

### Update CHANGELOG

```bash
# Automatic - triggered on merge to main
# Or manually:
git-cliff --config cliff.toml -o CHANGELOG.md
```

## 🔍 Troubleshooting

### "Protected branch update failed"

You're trying to push directly to main. Use the PR workflow instead:

```bash
git checkout -b fix/my-fix
git push -u origin fix/my-fix
gh pr create
```

### "Your branch is behind origin/main"

Update your local main branch:

```bash
git checkout main
git pull
git checkout your-feature-branch
git merge main  # or git rebase main
```

### Pre-push Hook Not Working

Ensure hooks are configured:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

## 📚 Additional Resources

- [Contributing Guidelines](.github/CONTRIBUTING.md)
- [Branch Protection Configuration](.github/BRANCH_PROTECTION.md)
- [Project Standards](.github/PROJECT_STANDARDS.md)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Conventional Commits](https://www.conventionalcommits.org/)

## 💡 Tips

1. **Keep branches short-lived** - Merge frequently to avoid conflicts
2. **One feature per branch** - Makes review and rollback easier
3. **Write descriptive PR titles** - They become part of the changelog
4. **Test before pushing** - Run `make config` and pre-commit checks
5. **Clean up merged branches** - Keep repository tidy

---

**Remember**: The PR workflow is your friend! It provides documentation, validation, and safety.
