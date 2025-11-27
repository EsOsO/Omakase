# Contributing to Omakase

Thank you for your interest in contributing to Omakase! This guide will help you get started.

## Ways to Contribute

### 1. Documentation

- Improve existing documentation
- Add guides for new deployment scenarios
- Fix typos and clarify instructions
- Add screenshots and diagrams
- Translate documentation (coming soon)

### 2. Code Contributions

- Add new services
- Improve existing service configurations
- Fix bugs
- Optimize resource usage
- Enhance security

### 3. Community Support

- Answer questions in GitHub Discussions
- Help troubleshoot issues
- Share your deployment experiences
- Write blog posts or tutorials

### 4. Testing

- Test new releases
- Report bugs
- Verify documentation accuracy
- Test on different platforms

## Getting Started

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR-USERNAME/omakase.git
cd omakase

# Add upstream remote
git remote add upstream https://github.com/esoso/omakase.git
```

### Keep Your Fork Updated

```bash
# Fetch upstream changes
git fetch upstream

# Merge upstream main into your local main
git checkout main
git merge upstream/main

# Push to your fork
git push origin main
```

### Create a Branch

```bash
# Create a feature branch
git checkout -b feature/my-new-feature

# Or a fix branch
git checkout -b fix/issue-description
```

## Development Workflow

### 1. Make Your Changes

Edit files following the project standards:

- Review the project standards and guidelines
- Follow existing code style
- Test your changes
- Update documentation

### 2. Test Locally

```bash
# Validate compose files
make config

# Test deployment
make up

# Check service status
docker compose ps

# View logs
docker compose logs -f <service>
```

### 3. Documentation Changes

If you modified documentation:

```bash
# Install MkDocs dependencies
pip install -r requirements.txt

# Serve docs locally
mkdocs serve

# Open http://127.0.0.1:8000
```

### 4. Commit Changes

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Good commit messages
git commit -m "feat(service): add Uptime Kuma monitoring"
git commit -m "fix(traefik): resolve SSL certificate renewal issue"
git commit -m "docs(deployment): add bare metal installation guide"
git commit -m "chore(deps): update Docker images"

# Commit types:
# feat: New feature
# fix: Bug fix
# docs: Documentation only
# style: Code style (formatting, no logic change)
# refactor: Code refactoring
# test: Adding tests
# chore: Maintenance tasks
# security: Security improvements
```

### 5. Push and Create PR

```bash
# Push to your fork
git push origin feature/my-new-feature

# Create Pull Request on GitHub
# - Provide clear description
# - Reference related issues
# - Wait for review
```

## Pull Request Guidelines

### PR Title

Use conventional commit format:

```
feat(service): add new service description
fix(traefik): resolve issue description
docs(guide): improve installation instructions
```

### PR Description

Include:

1. **What**: Brief description of changes
2. **Why**: Reason for the change
3. **How**: Implementation details (if complex)
4. **Testing**: How you tested the changes
5. **Screenshots**: If UI changes
6. **Checklist**: Complete the PR template checklist

### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Configuration change
- [ ] Security improvement

## Related Issues
Fixes #123
Related to #456

## Testing
How did you test these changes?

## Checklist
- [ ] I have read PROJECT_STANDARDS.md
- [ ] I have tested my changes
- [ ] I have updated documentation
- [ ] I have followed commit message conventions
- [ ] No secrets are committed
- [ ] Pre-commit hooks pass
```

## Code Review Process

1. **Automated Checks**: CI/CD runs validation
   - Docker Compose validation
   - YAML linting
   - Secret detection
   - Documentation build

2. **Manual Review**: Maintainer reviews code
   - Code quality
   - Security implications
   - Documentation completeness
   - Adherence to standards

3. **Feedback**: Address review comments
   - Make requested changes
   - Push updates to same branch
   - Re-request review

4. **Merge**: Once approved
   - Maintainer merges PR
   - Automatic deployment (if main branch)
   - Changelog updated automatically

## Coding Standards

### Docker Compose Files

```yaml
services:
  myservice:
    # Use extends for common config
    extends:
      file: ../common/compose.yaml
      service: base

    # Pin image versions with digest
    image: myimage:1.0.0@sha256:abc123...

    # Mandatory security options
    security_opt:
      - no-new-privileges:true

    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

    # Dedicated network
    networks:
      - vnet-myservice
      - ingress  # Only if web-accessible

    # Secrets from Infisical
    environment:
      DB_PASSWORD: "${MYSERVICE_DB_PASSWORD:?err}"
```

### Documentation

- Use Markdown format
- Follow Material for MkDocs syntax
- Include code examples
- Add diagrams where helpful
- Keep language clear and concise

### Security

- **NEVER** commit secrets
- Use Infisical for all sensitive data
- Follow principle of least privilege
- Enable security options on containers
- Document security implications

## Adding a New Service

See detailed guide: [Adding Services](adding-services.md)

Quick checklist:

1. Create `compose/<service>/compose.yaml`
2. Configure dedicated network
3. Add security options
4. Configure secrets in Infisical
5. Add Traefik labels (if web service)
6. Create `docs/services/<service>.md`
7. Update `mkdocs.yml`
8. Test deployment
9. Create PR

## Documentation Contributions

### File Organization

```
docs/
├── getting-started/    # Installation and setup
├── deployment/         # Platform-specific guides
├── infrastructure/     # Core component docs
├── security/          # Security guides
├── operations/        # Maintenance and ops
├── services/          # Individual service docs
└── contributing/      # This section
```

### Writing Style

- **Clear and concise**: Get to the point
- **Step-by-step**: Number installation steps
- **Examples**: Provide code examples
- **Screenshots**: Add visuals when helpful
- **Links**: Reference related docs

### Admonitions

Use Material for MkDocs admonitions:

```markdown
!!! note "Optional Title"
    General information

!!! tip "Pro Tip"
    Helpful advice

!!! warning "Important"
    Warning about potential issues

!!! danger "Critical"
    Critical security or data loss warnings
```

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on the issue, not the person
- Assume good intentions

### Getting Help

- **Questions**: Use [GitHub Discussions](https://github.com/esoso/omakase/discussions)
- **Bugs**: Open [GitHub Issues](https://github.com/esoso/omakase/issues)
- **Security**: Report security issues via GitHub security advisories

### Communication Channels

- **GitHub Discussions**: General questions and discussion
- **GitHub Issues**: Bug reports and feature requests
- **Pull Requests**: Code and documentation contributions

## Recognition

Contributors are recognized:

- Listed in repository contributors
- Mentioned in changelog (if significant contribution)
- PR comments and reviews
- Community acknowledgment

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search GitHub Discussions
3. Ask in a new Discussion
4. Tag maintainers if needed

Thank you for contributing to Omakase! 🎉
