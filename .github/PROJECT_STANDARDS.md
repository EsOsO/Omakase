# Omakase Project Standards

This document defines the core principles, standards, and best practices for the Omakase project. All contributions and new services must adhere to these guidelines.

**Last Updated**: 2025-11-25
**Version**: 1.0.0

---

## 🎯 Core Principles

### 1. Security First
- **Zero secrets in git**: All sensitive data stored in Infisical vault
- **Network isolation**: Each service in dedicated, isolated network
- **Least privilege**: Containers run with minimal permissions
- **Defense in depth**: Multiple security layers (Authelia, CrowdSec, network isolation)

### 2. Automation & CI/CD
- **Automated testing**: Docker Compose validation in CI
- **Automated updates**: Renovate bot for dependency management
- **Automated backups**: Daily encrypted backups with verification
- **Infrastructure as Code**: Everything defined in version control

### 3. Documentation
- **Comprehensive docs**: Every service must have documentation
- **Onboarding friendly**: Clear getting started guides
- **Maintainable**: Documentation kept up-to-date with code

### 4. Modularity
- **Service isolation**: Each service in separate directory
- **Independent deployment**: Services can be enabled/disabled individually
- **Reusable components**: Common configurations templated

---

## 📁 Repository Structure Standards

### Directory Organization

```
omakase/
├── compose/                          # Service definitions
│   ├── common/                      # Shared resources (databases, redis)
│   │   ├── compose.yaml            # Database services
│   │   ├── scripts/                # Initialization scripts
│   │   └── redict/                 # Redis configuration
│   │
│   ├── <service-name>/             # Individual service directory
│   │   ├── compose.yaml            # Service definition (REQUIRED)
│   │   ├── config/                 # Configuration files
│   │   │   ├── *.yml              # Config templates with {{env "VAR"}}
│   │   │   └── *.example          # Example configs for sensitive files
│   │   ├── scripts/                # Service-specific scripts
│   │   └── README.md               # Service-specific notes (optional)
│   │
│   └── [other services]/
│
├── docs/                            # Documentation (MkDocs)
│   ├── services/                    # Service documentation (REQUIRED)
│   │   ├── <service-name>.md       # One doc per service
│   │   └── index.md                # Services overview
│   ├── infrastructure/              # Core infrastructure docs
│   ├── security/                    # Security documentation
│   ├── operations/                  # Operational guides
│   └── best-practices/              # Best practices guides
│
├── .github/workflows/               # CI/CD pipelines
│   ├── validate.yml                # PR validation
│   ├── deploy.yml                  # Deployment automation
│   └── docs.yml                    # Documentation deployment
│
├── compose.yaml                     # Core infrastructure services
├── compose.prod.yaml                # Production services
├── compose.dev.yaml                 # Development overrides
├── Makefile                         # Operational commands
├── .pre-commit-config.yaml          # Pre-commit hooks
├── renovate.json                    # Dependency automation
└── mkdocs.yml                       # Documentation configuration
```

---

## 🔒 Security Standards

### 1. Secret Management (MANDATORY)

#### ✅ Required Practices

**All secrets MUST be stored in Infisical vault:**

```yaml
# ✅ CORRECT - Use environment variable template
environment:
  DB_PASSWORD: "{{env "POSTGRES_PASSWORD"}}"
  API_KEY: "{{env "SERVICE_API_KEY"}}"
```

```yaml
# ❌ WRONG - Never hardcode secrets
environment:
  DB_PASSWORD: "mysecretpassword123"
  API_KEY: "sk-1234567890abcdef"
```

#### Secret Naming Convention

```bash
# Pattern: SERVICE_COMPONENT_PURPOSE
NEXTCLOUD_DB_PASSWORD          # ✅ Clear and specific
JELLYFIN_API_KEY              # ✅ Service-specific
AUTHELIA_JWT_SECRET           # ✅ Component and purpose

# Avoid generic names
DB_PASSWORD                    # ❌ Too vague
SECRET                        # ❌ Not descriptive
```

#### Configuration Files with Secrets

For config files that contain secrets:

1. Create `.example` template with placeholders
2. Add real file to `.gitignore`
3. Document in service README
4. Use `{{env "VAR"}}` syntax where possible

Example:
```bash
# Create template
compose/service/config/config.yml.example

# Real file (git-ignored)
compose/service/config/config.yml

# In .gitignore
compose/service/config/config.yml
```

### 2. Network Isolation (MANDATORY)

#### Every Service MUST Have:

1. **Dedicated service network** (`vnet-<service>`)
2. **Connection to required shared networks only**
3. **No direct internet access unless necessary**

#### Network Types

```yaml
networks:
  # Shared networks (defined in compose.yaml)
  ingress:              # Public-facing services (Traefik routing)
  docker_socket:        # Docker API access (via Cetusguard)

  # Service-specific networks (define per service)
  vnet-servicename:     # Isolated service network
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.Y/Z  # See network allocation table
```

#### Network Configuration Template

```yaml
services:
  app:
    image: myapp:latest
    networks:
      - vnet-myapp          # Own isolated network
      - ingress             # Only if needs Traefik routing
    # No docker_socket unless absolutely necessary

  app-db:
    image: postgres:16
    networks:
      - vnet-myapp          # Only on service network

networks:
  vnet-myapp:
    name: vnet-myapp
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.X.Y/Z  # Allocate from subnet table
```

#### Network Allocation

Reserved ranges in `192.168.0.0/16`:

```
192.168.10.0/29   - vnet-traefik
192.168.20.0/28   - vnet-authelia
192.168.20.16/28  - vnet-crowdsec
192.168.20.32/29  - vnet-immich
192.168.20.40/29  - vnet-nextcloud
192.168.20.48/29  - vnet-vaultwarden
192.168.20.56/29  - vnet-paperless
...
192.168.90.0/24   - ingress (shared)
192.168.91.0/24   - docker_socket (shared)
```

**Before adding new service**: Check `make network` to see allocated subnets.

### 3. Container Security

#### Required Security Options

```yaml
services:
  myservice:
    security_opt:
      - no-new-privileges:true    # MANDATORY - prevents privilege escalation

    user: "${PUID}:${PGID}"       # RECOMMENDED - run as non-root

    read_only: true               # IF POSSIBLE - read-only root filesystem
    tmpfs:
      - /tmp                      # If read_only is true

    cap_drop:                     # IF POSSIBLE - drop unnecessary capabilities
      - ALL
    cap_add:
      - NET_BIND_SERVICE          # Only add required capabilities
```

#### Resource Limits (MANDATORY)

```yaml
services:
  myservice:
    deploy:
      resources:
        limits:
          cpus: '1'               # REQUIRED - prevent CPU hogging
          memory: 256M            # REQUIRED - prevent memory exhaustion
        reservations:
          memory: 128M            # RECOMMENDED - ensure minimum resources
    restart: on-failure:3         # REQUIRED - limit restart loops
```

---

## 📦 Service Standards

### Adding a New Service - Checklist

#### 1. Service Directory Structure

```bash
compose/<service-name>/
├── compose.yaml              # REQUIRED - Service definition
├── config/                   # Configuration files
│   ├── *.yml                # Templates with {{env "VAR"}}
│   └── *.yml.example        # Examples for sensitive configs
├── scripts/                  # Optional - Init/maintenance scripts
└── .env.example             # Optional - Service-specific env vars
```

#### 2. Service compose.yaml Template

```yaml
---
# Service: <service-name>
# Description: <brief description>
# Documentation: docs/services/<service-name>.md

services:
  <service-name>:
    container_name: <service-name>
    image: <image>:<version>  # Use specific version, not :latest

    # Security
    security_opt:
      - no-new-privileges:true
    user: "${PUID}:${PGID}"

    # Resources
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 256M
        reservations:
          memory: 128M
    restart: on-failure:3

    # Networks
    networks:
      - vnet-<service-name>
      - ingress  # Only if exposed via Traefik

    # Environment
    environment:
      TZ: "{{env "TZ"}}"
      # All secrets from Infisical
      DB_PASSWORD: "{{env "SERVICE_DB_PASSWORD"}}"

    # Volumes
    volumes:
      - "${DATA_DIR}/<service-name>/config:/config"
      - "${DATA_DIR}/<service-name>/data:/data"

    # Labels for Traefik (if exposed)
    labels:
      - traefik.enable=true
      - traefik.http.routers.<service-name>.rule=Host(`<service>.{{env "DOMAINNAME"}}`)
      - traefik.http.routers.<service-name>.entrypoints=websecure
      - traefik.http.routers.<service-name>.tls.certresolver=letsencrypt
      - traefik.http.routers.<service-name>.middlewares=chain-authelia@file
      - traefik.http.services.<service-name>.loadbalancer.server.port=8080

    # Healthcheck (recommended)
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  vnet-<service-name>:
    name: vnet-<service-name>
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.X.Y/Z  # Allocate from available range

  # Shared networks (external)
  ingress:
    external: true
```

#### 3. Service Documentation (REQUIRED)

Create `docs/services/<service-name>.md`:

```markdown
# <Service Name>

Brief description of what the service does.

## Overview

- **Purpose**: What problem does it solve?
- **Version**: Current version deployed
- **Homepage**: Official project website
- **Documentation**: Official docs link

## Prerequisites

- Required secrets in Infisical
- Required data directories
- Dependencies on other services

## Configuration

### Required Secrets

Add to Infisical:

| Secret Name | Example | Purpose |
|-------------|---------|---------|
| `SERVICE_DB_PASSWORD` | Generate with `make pwgen` | Database password |
| `SERVICE_API_KEY` | From service settings | API access |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID |
| `PGID` | `1000` | Group ID |

### Configuration Files

Copy and configure:

```bash
cp compose/<service>/config/config.yml.example \
   compose/<service>/config/config.yml
```

## Deployment

### Enable Service

Edit `compose.prod.yaml` to include:

```yaml
include:
  - compose/<service-name>/compose.yaml
```

### Deploy

```bash
make pull
make up
```

### Verify

```bash
docker compose ps <service-name>
docker compose logs <service-name>
```

Access at: `https://<service>.yourdomain.com`

## First-Time Setup

Step-by-step guide for initial configuration:

1. Access web UI
2. Complete setup wizard
3. Configure integrations
4. Test functionality

## Integration with Other Services

### Authelia SSO

If supporting OIDC:

```yaml
# Add to compose/authelia/config/oidc.d/<service>
# See docs/infrastructure/authelia.md
```

### Backup

Database backups configured in:
- `compose/backup/restic/commands/pre-commands.sh`

## Monitoring

- Logs: `docker compose logs -f <service-name>`
- Health: `docker compose ps <service-name>`
- Metrics: Available in Traefik dashboard

## Maintenance

### Updates

Automated via Renovate bot. Manual update:

```bash
make pull
make up
```

### Backup

Included in automated daily backups.

### Troubleshooting

#### Issue: Service won't start

Check logs:
```bash
docker compose logs <service-name>
```

Common causes:
- Missing secrets
- Permission issues on volumes
- Port conflicts

#### Issue: Can't access via web

Verify:
- Container is running and healthy
- Traefik labels configured correctly
- Domain DNS pointing to server
- Authelia authentication working

## Security Considerations

- Network isolation: `vnet-<service>`
- Authentication: Protected by Authelia
- Secrets: All in Infisical vault
- Updates: Automated via Renovate

## Additional Resources

- [Official Documentation](https://example.com/docs)
- [GitHub Repository](https://github.com/project/repo)
- [Community Forum](https://forum.example.com)
```

#### 4. Update Main Files

**Add to `compose.prod.yaml` or `compose.dev.yaml`:**

```yaml
include:
  - compose/<service-name>/compose.yaml
```

**Update `docs/services/index.md`:**

Add service to category listing.

**Update `mkdocs.yml`:**

```yaml
- Services:
    - services/index.md
    - <Service Name>: services/<service-name>.md
```

#### 5. Testing Checklist

- [ ] Service starts successfully: `docker compose up -d`
- [ ] Healthcheck passes: `docker compose ps`
- [ ] Network isolation verified: `docker network inspect vnet-<service>`
- [ ] Accessible via Traefik: `https://<service>.yourdomain.com`
- [ ] Authelia authentication working
- [ ] Secrets loaded from Infisical: `make config`
- [ ] Pre-commit hooks pass: `pre-commit run --all-files`
- [ ] Documentation complete
- [ ] Backup configured (if has database)

---

## 🚀 CI/CD Standards

### GitHub Actions Workflows

#### 1. Pull Request Validation (MANDATORY)

All PRs must pass:

- ✅ Docker Compose syntax validation
- ✅ YAML linting
- ✅ Secret detection (Gitleaks)
- ✅ Documentation build test

**File**: `.github/workflows/validate.yml`

#### 2. Automated Deployment

On merge to `main`:

- ✅ Generate changelog
- ✅ Deploy to server (if configured)
- ✅ Notification on success/failure

**File**: `.github/workflows/deploy.yml`

#### 3. Documentation Deployment

On docs changes:

- ✅ Build MkDocs site
- ✅ Deploy to GitHub Pages

**File**: `.github/workflows/docs.yml`

### Renovate Bot Configuration

Automated dependency updates:

- **Auto-merge**: Digest updates, patch versions
- **Manual review**: Minor and major versions
- **Security alerts**: Immediate attention required
- **Grouping**: Updates grouped by service directory

**File**: `renovate.json`

#### Adding Service to Renovate

Services are automatically detected. To customize:

```json
{
  "packageRules": [
    {
      "matchPaths": ["compose/myservice/**"],
      "groupName": "myservice",
      "schedule": ["before 6am on monday"]
    }
  ]
}
```

---

## 📝 Documentation Standards

### MkDocs Structure

```
docs/
├── index.md                      # Homepage
├── getting-started/              # New user guides
│   ├── quick-start.md           # 30-min quickstart
│   └── ...
├── deployment/                   # Deployment scenarios
├── architecture/                 # System design
├── infrastructure/               # Core services (Traefik, Authelia)
├── services/                     # SERVICE DOCS (MANDATORY)
│   ├── index.md                 # Services overview
│   ├── <service-name>.md        # One doc per service
│   └── ...
├── operations/                   # Maintenance guides
├── security/                     # Security docs
├── best-practices/               # QoL improvements
└── reference/                    # Command reference
```

### Documentation Requirements

Every service MUST have:

1. **Overview section**: What it does, why included
2. **Prerequisites**: Required secrets, dependencies
3. **Configuration guide**: Step-by-step setup
4. **Deployment instructions**: How to enable
5. **Troubleshooting**: Common issues and solutions
6. **Integration guides**: How it connects to other services

### Writing Style

- ✅ Clear, concise language
- ✅ Step-by-step instructions
- ✅ Code examples with comments
- ✅ Screenshots for complex UIs
- ✅ Links to official documentation
- ❌ Avoid jargon without explanation
- ❌ No assumptions about user knowledge

---

## 🔄 Maintenance Standards

### Update Process

#### Automated (Renovate Bot)

- Patch updates: Auto-merged after CI passes
- Digest updates: Auto-merged
- Minor/Major: Manual review required

#### Manual Updates

```bash
# 1. Check for updates
make pull

# 2. Review changes
docker compose config

# 3. Deploy updates
make up

# 4. Verify
docker compose ps
docker compose logs
```

### Backup Verification

**Weekly**: Verify last backup completed

```bash
docker compose logs restic | grep snapshot
```

**Monthly**: Test restore procedure

```bash
# Documented in docs/operations/backup.md
```

### Security Audits

**Monthly**:
- Review CrowdSec decisions
- Check for security updates
- Rotate credentials (as needed)

**Quarterly**:
- Full security audit
- Penetration testing (optional)
- Dependency vulnerability scan

---

## 🤝 Contributing Standards

### Before Submitting PR

1. ✅ Pre-commit hooks installed and passing
2. ✅ Service documentation written
3. ✅ Secrets in Infisical (documented)
4. ✅ Network isolation configured
5. ✅ Resource limits set
6. ✅ Security options enabled
7. ✅ Tested locally
8. ✅ CI passes

### PR Template

```markdown
## Description

Brief description of changes.

## Type of Change

- [ ] New service
- [ ] Service update
- [ ] Documentation
- [ ] Bug fix
- [ ] Security fix

## Service Checklist (if applicable)

- [ ] Service documentation created in `docs/services/`
- [ ] Dedicated network configured (`vnet-<service>`)
- [ ] All secrets in Infisical
- [ ] Resource limits configured
- [ ] Security options enabled (`no-new-privileges`)
- [ ] Healthcheck configured
- [ ] Backup configured (if has database)
- [ ] Tested locally

## Testing

Describe testing performed:

- [ ] Service starts successfully
- [ ] Accessible via Traefik
- [ ] Authelia authentication works
- [ ] No secrets in code
- [ ] Pre-commit hooks pass

## Documentation

- [ ] Service documentation complete
- [ ] README updated (if needed)
- [ ] CHANGELOG updated
```

### Commit Message Convention

```bash
# Format: <type>(<scope>): <subject>

feat(nextcloud): add Nextcloud file sync service
fix(traefik): resolve SSL certificate renewal issue
docs(services): improve Jellyfin setup guide
security(authelia): rotate OIDC secrets
chore(renovate): update dependency groups
```

Types:
- `feat`: New feature/service
- `fix`: Bug fix
- `docs`: Documentation only
- `security`: Security improvement
- `chore`: Maintenance
- `refactor`: Code restructuring
- `test`: Testing improvements

---

## 📊 Metrics & Monitoring

### Key Metrics to Track

1. **Service Availability**
   - Uptime percentage
   - Health check status
   - Response times

2. **Resource Usage**
   - CPU utilization
   - Memory consumption
   - Disk space
   - Network bandwidth

3. **Security Events**
   - CrowdSec decisions
   - Failed authentication attempts
   - Certificate expiry dates

4. **Backup Status**
   - Last successful backup
   - Backup size trends
   - Failed backups

### Alerting

Configure alerts for:

- ❌ Service down > 5 minutes
- ⚠️ CPU > 80% for > 10 minutes
- ⚠️ Memory > 90%
- ⚠️ Disk > 85% full
- ❌ Backup failed
- ❌ Certificate expiring < 7 days

---

## 🎓 Learning & Improvement

### Regular Reviews

**Monthly**: Technology review
- New services to consider
- Deprecated services to remove
- Performance optimizations

**Quarterly**: Architecture review
- Network design improvements
- Security enhancements
- Automation opportunities

### Knowledge Sharing

- Document lessons learned
- Share configurations with community
- Contribute back to upstream projects
- Write blog posts about setup

---

## 📞 Support & Resources

### Internal Documentation

- This document: Project standards
- `.github/SECURITY.md`: Security policy
- `CLEANUP_SUMMARY.md`: Pre-publication checklist
- `docs/`: Comprehensive documentation

### External Resources

- [Docker Documentation](https://docs.docker.com/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Authelia Documentation](https://www.authelia.com/)
- [/r/selfhosted](https://reddit.com/r/selfhosted)

---

**Maintained by**: Omakase Community
**Questions**: Open GitHub Discussion
**Issues**: GitHub Issues
**Security**: See .github/SECURITY.md
