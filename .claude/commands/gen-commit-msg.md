
Your task is to help the user generate a commit message and commit changes following the project's git-cliff conventional commits configuration.

## Guidelines

- DO NOT add any ads such as "Generated with [Claude Code](https://claude.ai/code)"
- Only generate the message for staged files/changes
- Don't add any files using `git add`. The user will decide what to add
- Follow the conventional commits format defined in cliff.toml
- The commit message must be compatible with git-cliff changelog generation

## Format

```
<type>(<scope>): <message>

<optional body with bullet points>
```

**Important**:
- Scope is REQUIRED for better changelog organization
- Message must be lowercase, no period at the end
- Breaking changes: add exclamation mark after scope like `feat(service)!: breaking change`

## Commit Types (per cliff.toml)

| Type       | Changelog Group              | Bump  | Usage                                    |
| ---------- | ---------------------------- | ----- | ---------------------------------------- |
| `feat`     | ✨ Minor Updates             | minor | New features, services, capabilities     |
| `fix`      | 🩹/📌 Patch/Digest Updates   | patch | Bug fixes, corrections, digest updates   |
| `feat!`    | 🚨 Breaking Updates          | major | Breaking changes with exclamation mark   |
| `chore`    | Miscellaneous Tasks          | -     | Maintenance, deps, tooling               |
| `docs`     | (not shown in changelog)     | -     | Documentation updates                    |
| `security` | (implicit in fix/feat)       | -     | Security updates                         |

## Scope Examples

Use service names or infrastructure areas:
- Services: `traefik`, `authelia`, `nextcloud`, `portainer`, `jellyfin`, `crowdsec`
- Infrastructure: `network`, `security`, `backup`, `monitoring`, `ci`, `deploy`
- General: `core`, `config`, `deps`, `docs`

## Commit Message Examples

### New Service
```
feat(jellyfin): add media streaming service
```

### Bug Fix
```
fix(traefik): resolve certificate renewal timeout
```

### Configuration Update
```
chore(authelia): update session timeout configuration
```

### Dependency Update
```
chore(deps): update postgres image to v16.2
```

### Breaking Change
```
feat(postgres)!: upgrade to postgresql 16

- Requires data migration from v15
- Updated backup scripts for new version
- Breaking: connection string format changed
```

### Security Update
```
fix(crowdsec): update bouncer configuration for CVE-2024-xxxxx
```

### Documentation
```
docs(services): add troubleshooting guide for traefik
```

### Multiple Services
```
fix(network): adjust subnet allocations for new services

- Updated vnet-jellyfin subnet
- Fixed conflict with vnet-nextcloud
- Documented in network allocation table
```

## Rules

1. **Message format**: `type(scope): description` - scope is MANDATORY
2. **Lowercase**: Title must be lowercase, no period at the end
3. **Length**: Keep title under 72 characters (50 preferred)
4. **Body**: Optional, use bullet points to explain *why* or provide context
5. **Breaking changes**: Use `feat(scope)!:` format and explain in body
6. **Scope specificity**: Use actual service/component names, not generic terms

## What to Avoid

- ❌ Missing scope: `feat: add service` (should be `feat(service-name): add service`)
- ❌ Vague messages: `fix: update stuff`
- ❌ Capital letters: `Fix(traefik): Update config`
- ❌ Period at end: `feat(api): add endpoint.`
- ❌ Wrong breaking syntax: `feat(api): breaking change` (should use exclamation mark)

## Special Notes for This Project

- All commits are tracked in CHANGELOG.md via git-cliff
- Commits with `chore(doc)` are skipped from changelog
- Use service directory names as scopes when applicable
- For multi-service changes, use the most relevant scope or use `core`/`infra`
