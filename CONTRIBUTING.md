# Contributing to Omakase

First off, thank you for considering contributing to Omakase! It's people like you that make Omakase such a great tool for the self-hosting community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Workflow](#development-workflow)
- [Project Standards](#project-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible using our bug report template.

**Good bug reports include:**
- Clear, descriptive title
- Exact steps to reproduce the issue
- Expected vs actual behavior
- Docker Compose logs (`docker compose logs <service>`)
- Environment details (OS, Docker version, etc.)
- Screenshots if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:
- Use a clear and descriptive title
- Provide a detailed description of the proposed functionality
- Explain why this enhancement would be useful
- Include examples of how it would work

### Adding New Services

Want to add a new service to Omakase? Great! Please follow these steps:

1. **Check if it fits**: Ensure the service aligns with Omakase's goals (self-hosted, production-ready, security-first)
2. **Open a discussion**: Before spending time on implementation, open a GitHub Discussion to gather feedback
3. **Follow service standards**: See [.github/PROJECT_STANDARDS.md](.github/PROJECT_STANDARDS.md) section 2-3 for the complete checklist
4. **Document thoroughly**: Every service needs comprehensive documentation in `docs/services/<service-name>.md`

### Improving Documentation

Documentation improvements are always welcome! This includes:
- Fixing typos or clarifying existing docs
- Adding examples or use cases
- Improving installation/configuration guides
- Translating documentation (future)

## Development Workflow

### Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+
- Git
- Python 3.8+ (for documentation)
- pre-commit

### Setting Up Development Environment

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/omakase.git
cd omakase

# 3. Add upstream remote
git remote add upstream https://github.com/esoso/omakase.git

# 4. Install pre-commit hooks
pip install pre-commit
pre-commit install

# 5. Install documentation dependencies
pip install -r requirements.txt
```

### Working on Your Contribution

```bash
# 1. Create a feature branch from main
git checkout -b feat/my-new-service

# 2. Make your changes following project standards

# 3. Test your changes locally
make config  # Validate compose syntax
make up      # Deploy and test

# 4. Run pre-commit checks
pre-commit run --all-files

# 5. Commit with conventional commit messages
git add .
git commit -m "feat(service): add my-new-service"

# 6. Push to your fork
git push origin feat/my-new-service

# 7. Open a Pull Request on GitHub
```

### Testing Your Changes

Before submitting a PR, ensure:

- [ ] Service starts successfully: `docker compose up -d <service>`
- [ ] Healthcheck passes: `docker compose ps <service>`
- [ ] No secrets in code: `git secrets --scan` or pre-commit hook
- [ ] Compose syntax valid: `make config`
- [ ] Documentation builds: `mkdocs build`
- [ ] Pre-commit hooks pass: `pre-commit run --all-files`
- [ ] Service accessible via web (if applicable)
- [ ] Backup configured (if service has database)

## Project Standards

All contributions must follow our project standards defined in [.github/PROJECT_STANDARDS.md](.github/PROJECT_STANDARDS.md).

### Critical Requirements

**Security** (MANDATORY):
- ✅ All secrets in Infisical vault, NEVER in git
- ✅ `no-new-privileges:true` on all containers
- ✅ Dedicated network isolation per service
- ✅ Resource limits (CPU/memory) configured

**Service Structure** (MANDATORY):
```
compose/<service-name>/
├── compose.yaml              # Service definition
├── config/                   # Configuration files
└── scripts/                  # Optional scripts
```

**Documentation** (MANDATORY):
- Service documentation in `docs/services/<service-name>.md`
- Follow documentation template in PROJECT_STANDARDS.md
- Update `mkdocs.yml` navigation

### Code Style

**Docker Compose:**
- Use specific image versions, not `:latest`
- Include comments for complex configurations
- Use template syntax for environment variables: `{{env "VAR"}}`
- Follow existing patterns in the codebase

**Documentation:**
- Use clear, concise language
- Provide step-by-step instructions
- Include code examples with comments
- Add screenshots for complex UIs

## Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for automatic changelog generation.

### Commit Message Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature or service
- `fix`: Bug fix
- `docs`: Documentation only changes
- `security`: Security improvements
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `ci`: CI/CD changes

### Examples

```bash
feat(nextcloud): add Nextcloud file sync service

- Add compose configuration with network isolation
- Configure Traefik routing and SSL
- Add comprehensive documentation
- Include backup configuration

Closes #42

fix(traefik): resolve SSL certificate renewal issue

The Let's Encrypt certificates were not renewing due to incorrect
DNS provider configuration. Updated to use proper credentials.

Fixes #123

docs(jellyfin): improve initial setup guide

Added screenshots for first-time configuration wizard and
clarified hardware transcoding setup steps.

security(authelia): rotate OIDC client secrets

Scheduled rotation of OIDC secrets as part of quarterly
security maintenance.
```

### Scope

The scope should be the name of the service or component affected:
- Service names: `nextcloud`, `traefik`, `jellyfin`
- Components: `docs`, `ci`, `backup`, `network`

## Pull Request Process

### Before Submitting

1. **Update documentation**: All code changes require documentation updates
2. **Run tests locally**: Ensure everything works in your environment
3. **Update changelog**: For significant changes, add entry to `CHANGELOG.md`
4. **Rebase on latest main**: Keep your branch up to date

### PR Checklist

When opening a PR, ensure:

- [ ] PR title follows conventional commit format
- [ ] Description clearly explains the changes and motivation
- [ ] All CI checks pass (compose validation, linting, secret detection)
- [ ] Documentation is complete and accurate
- [ ] No secrets or sensitive information in code
- [ ] Service follows security standards
- [ ] Breaking changes are clearly documented
- [ ] Screenshots included for UI changes

### PR Review Process

1. **Automated checks**: CI must pass (compose validation, YAML linting, secret detection)
2. **Maintainer review**: At least one maintainer approval required
3. **Testing**: Maintainers may test in their environment
4. **Feedback**: Address any requested changes
5. **Merge**: Once approved, maintainer will merge

### After Your PR is Merged

- Your changes will be included in the next release
- Changelog will be automatically generated
- Documentation will be deployed to GitHub Pages
- Consider joining [GitHub Discussions](https://github.com/esoso/omakase/discussions) to help others

## Issue Guidelines

### Creating Issues

**Bug Reports:**
- Use the bug report template
- Include reproduction steps
- Attach relevant logs
- Specify environment details

**Feature Requests:**
- Use the feature request template
- Explain the use case
- Describe expected behavior
- Consider implementation complexity

**Questions:**
- First check documentation and existing issues
- Use GitHub Discussions for general questions
- Use issues for specific problems only

### Issue Labels

Issues are automatically labeled, but common labels include:
- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Documentation improvements
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `security`: Security-related issues
- `service:<name>`: Service-specific issues

## Getting Help

Need help contributing?

- 📖 **Documentation**: https://esoso.github.io/Omakase/
- 💬 **Discussions**: https://github.com/esoso/omakase/discussions
- 🐛 **Issues**: https://github.com/esoso/omakase/issues
- 📧 **Security**: See [SECURITY.md](.github/SECURITY.md)

## Recognition

Contributors will be recognized:
- In release notes for significant contributions
- In the project README (future contributors section)
- In commit history

Thank you for contributing to Omakase! 🎉
