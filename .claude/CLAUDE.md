# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Omakase is a production-ready Docker homelab infrastructure managing 25+ containerized services with a security-first architecture. This is an Infrastructure-as-Code project using Docker Compose with Infisical for secret management.

**Key Technologies**: Docker Compose, Infisical (secrets), Traefik (reverse proxy), Authelia (SSO), CrowdSec (security), Restic (backups)

## Essential Development Commands

All commands require Infisical authentication and use environment variables from Infisical vault.

### Core Operations

```bash
# Deploy stack (dev environment)
make up

# Deploy stack (production)
INFISICAL_TOKEN=$(infisical login ...) infisical run --env=prod ... docker compose -f compose.yaml -f compose.prod.yaml up -d

# Pull latest images
make pull

# Stop services
make down

# Restart services
make restart

# View resolved configuration (with secrets injected)
make config

# Show network subnet allocations
make network

# Clean unused Docker resources
make clean

# Generate secure password
make pwgen
```

### Working with Individual Services

```bash
# View logs for a service
docker compose logs -f <service-name>

# Restart a specific service
docker compose restart <service-name>

# Check service status
docker compose ps <service-name>

# Execute command in container
docker exec -it <container-name> sh
```

### Documentation

```bash
# Install MkDocs dependencies
pip install -r requirements.txt

# Serve documentation locally
mkdocs serve
# Access at http://127.0.0.1:8000

# Build documentation
mkdocs build
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run manually
pre-commit run --all-files
```

## Architecture Overview

### Compose File Structure

The project uses a modular multi-file Docker Compose setup:

- **compose.yaml**: Core infrastructure (Traefik, Authelia, Cetusguard, Dozzle, Homepage, Portainer)
- **compose.prod.yaml**: Production services (media, productivity, development tools)
- **compose.dev.yaml**: Development overrides
- **compose/**: Individual service directories, each with their own `compose.yaml`

Services are included using the `include:` directive, allowing modular enabling/disabling.

### Network Architecture

Two shared networks plus per-service isolated networks:

**Shared Networks** (defined in compose.yaml):
- `ingress` (192.168.90.0/24): Public-facing services via Traefik
- `vnet-socket` (192.168.91.0/24): Docker API access via Cetusguard proxy
- `vnet-<service>`: Per-service isolation networks with dedicated subnets

**Network Isolation Rules**:
- Every service MUST have its own `vnet-<service>` network
- Only connect to shared networks when necessary (ingress for web access, vnet-socket for Docker API)
- Use `make network` to check allocated subnets before adding new services
- Never expose Docker socket directly; always use Cetusguard proxy

### Secret Management with Infisical

**Critical**: All secrets are stored in Infisical vault, NEVER in git or compose files.

Pattern in compose files:
```yaml
environment:
  DB_PASSWORD: "${POSTGRES_PASSWORD:?err}"  # Loaded from Infisical
  API_KEY: "{{env "SERVICE_API_KEY"}}"      # Template syntax alternative
```

Secret naming convention: `SERVICE_COMPONENT_PURPOSE` (e.g., `NEXTCLOUD_DB_PASSWORD`)

### Service Directory Structure

Standard layout for each service:
```
compose/<service-name>/
├── compose.yaml              # Service definition (REQUIRED)
├── config/                   # Configuration files
│   ├── *.yml                # Config templates with {{env "VAR"}}
│   └── *.yml.example        # Example configs (git-tracked)
└── scripts/                  # Optional init/maintenance scripts
```

### Security Model

Multi-layered security approach:

1. **Authentication**: Authelia SSO gateway protects all services
2. **Network Security**: CrowdSec IPS with automated threat blocking
3. **Container Security**:
   - `no-new-privileges:true` on all containers (MANDATORY)
   - Resource limits (CPU/memory) prevent exhaustion
   - Non-root users (`PUID`/`PGID`)
4. **Secret Management**: External vault (Infisical), zero secrets in git
5. **Docker Socket Protection**: Cetusguard proxy with read-only API access

### Backup System

Restic-based automated backups (compose/backup/compose.yaml):
- Daily backups at 3:30 AM
- Daily integrity checks at 5:15 AM
- Automated pruning at 4:00 AM
- Encrypted to Backblaze B2
- Telegram notifications for status

## Adding a New Service

Follow this checklist when adding services:

1. **Create service directory**: `compose/<service-name>/`
2. **Create compose.yaml** with:
   - Dedicated `vnet-<service>` network with allocated subnet (check `make network`)
   - Security options: `no-new-privileges:true`
   - Resource limits: CPU and memory
   - All secrets from Infisical (never hardcoded)
   - Traefik labels if web-accessible
   - Connection to `ingress` network only if needs web access
3. **Document in** `docs/services/<service-name>.md` (MANDATORY)
4. **Add to** `compose.prod.yaml` or `compose.dev.yaml` include list
5. **Update** `mkdocs.yml` navigation
6. **Test**:
   - `make config` (validates compose and secret injection)
   - `make up` (deploy)
   - `docker compose ps <service>` (verify running)
   - `pre-commit run --all-files` (validate)

See .github/PROJECT_STANDARDS.md sections 2-3 for complete service template and checklist.

## Common Development Patterns

### Extending Base Services

Common base definitions in `compose/common/compose.yaml`:
- `base`: Standard security options and restart policy
- `postgres`: PostgreSQL with security hardening
- `redict`: Redis alternative
- `restic`: Backup container template

Use `extends` to inherit:
```yaml
services:
  myservice:
    extends:
      file: ../common/compose.yaml
      service: base
```

### Traefik Integration

Standard Traefik labels for web-accessible services:
```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.<service>.rule=Host(`<service>.${DOMAINNAME}`)
  - traefik.http.routers.<service>.entrypoints=websecure
  - traefik.http.routers.<service>.tls.certresolver=letsencrypt
  - traefik.http.routers.<service>.middlewares=chain-authelia@file  # SSO protection
  - traefik.http.services.<service>.loadbalancer.server.port=8080
```

### Environment Variable Handling

Required environment variables (set in Infisical):
- `DATA_DIR`: Base directory for persistent data
- `DOMAINNAME`: Base domain for services
- `TRAEFIK_TRUSTED_IPS`: Trusted IP ranges
- `PUID`/`PGID`: User/group IDs for non-root execution
- `TZ`: Timezone

Service-specific secrets follow naming pattern: `<SERVICE>_<COMPONENT>_<PURPOSE>`

## CI/CD Pipeline

### GitHub Actions Workflows

**.github/workflows/validate.yml** (on PRs):
- Docker Compose validation
- YAML linting
- Secret detection (Gitleaks)
- Documentation build test

**.github/workflows/deploy.yml** (on push to main):
- Changelog generation (git-cliff)
- Optional deployment to server via rsync
- Automatic version tagging

**.github/workflows/docs.yml**:
- MkDocs site build and deployment to GitHub Pages

### Renovate Bot

Automated dependency updates configured in `renovate.json`:
- **Auto-merge**: Digest updates, patch versions
- **Manual review**: Minor/major version updates
- Rate limiting: 5 concurrent PRs, 2 per hour
- 3-day minimum release age for stability
- Updates grouped by service directory

## Important Files

- **.github/PROJECT_STANDARDS.md**: Comprehensive standards document - READ THIS for detailed guidelines on security, service templates, and best practices
- **.github/SECURITY.md**: Security policy and reporting
- **Makefile**: All operational commands with Infisical integration
- **.pre-commit-config.yaml**: Pre-commit hooks for validation and security checks
- **renovate.json**: Dependency automation configuration
- **cliff.toml**: Changelog generation configuration

## Conventions

### Commit Messages

Follow conventional commits for automatic changelog:
```
feat(service): add new service
fix(traefik): resolve SSL issue
docs(readme): update installation steps
security(authelia): rotate secrets
chore(deps): update dependencies
```

### Container Naming

Container names match service names: `container_name: <service-name>`

### Volume Mounts

Standard pattern: `${DATA_DIR}/<service-name>/<subdir>:/container/path`

## Testing and Validation

Before committing:
1. Run `make config` to validate compose syntax and secret injection
2. Run `pre-commit run --all-files` to check for issues
3. Test service deployment: `make up && docker compose ps`
4. Verify no secrets in code: Check pre-commit output
5. Ensure documentation is complete

## Critical Security Rules

1. **NEVER commit secrets** - All secrets in Infisical vault
2. **NEVER skip security options** - `no-new-privileges:true` is MANDATORY
3. **NEVER connect directly to Docker socket** - Always use Cetusguard
4. **NEVER skip network isolation** - Every service needs dedicated `vnet-<service>`
5. **NEVER use `:latest` tags** - Pin specific versions with digests (Renovate manages)

## Common Issues

### Infisical Authentication
If commands fail, check `INFISICAL_*` environment variables are set:
- `INFISICAL_DOMAIN`
- `INFISICAL_PROJECT_ID`
- `INFISICAL_CLIENT_ID`
- `INFISICAL_CLIENT_SECRET`

### Service Won't Start
1. Check logs: `docker compose logs <service>`
2. Verify secrets loaded: `make config | grep <SERVICE>`
3. Check permissions on `${DATA_DIR}/<service>` directories
4. Verify network connectivity: `docker network inspect vnet-<service>`

### Network Subnet Conflicts
Use `make network` to view allocated subnets before adding new services. Avoid conflicts in `192.168.0.0/16` range.

## Documentation Resources

- Full documentation: https://esoso.github.io/Omakase/
- Local docs: `mkdocs serve` (requires `pip install -r requirements.txt`)
- Service docs: `docs/services/<service-name>.md`
- Infrastructure docs: `docs/infrastructure/`
- Operational guides: `docs/operations/`
