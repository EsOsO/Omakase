# Adding Services

Comprehensive guide for adding new services to Omakase.

## Overview

Omakase's modular architecture makes adding services straightforward. Follow this guide to ensure proper integration with security, networking, and backup systems.

## Quick Start

1. Create service directory: `compose/<service-name>/`
2. Create `compose.yaml` with service definition
3. Document in `docs/services/<service-name>.md`
4. Add to include list in `compose.prod.yaml` or `compose.dev.yaml`
5. Test deployment

## Step-by-Step Guide

### 1. Create Service Directory

```bash
mkdir -p compose/<service-name>
cd compose/<service-name>
```

### 2. Create compose.yaml

Use this template:

```yaml
# compose/<service-name>/compose.yaml

services:
  <service-name>:
    image: <image>:<tag>@sha256:<digest>
    container_name: <service-name>
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "${PUID}:${PGID}"
    networks:
      - ingress  # Only if web-accessible
      - vnet-<service-name>
    environment:
      # Service configuration
      SERVICE_KEY: "${SERVICE_KEY:?err}"
    volumes:
      - ${DATA_DIR}/<service-name>/config:/config
      - ${DATA_DIR}/<service-name>/data:/data
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    labels:
      # Traefik labels (if web-accessible)
      - traefik.enable=true
      - traefik.docker.network=ingress
      - traefik.http.routers.<service-name>.rule=Host(`<service-name>.${DOMAINNAME}`)
      - traefik.http.routers.<service-name>.entrypoints=websecure
      - traefik.http.routers.<service-name>.tls.certresolver=letsencrypt
      - traefik.http.routers.<service-name>.middlewares=chain-authelia@file
      - traefik.http.services.<service-name>.loadbalancer.server.port=<port>

networks:
  ingress:
    external: true
  vnet-<service-name>:
    name: vnet-<service-name>
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.X.0/24
          gateway: 192.168.X.1

volumes:
  <service-name>_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/<service-name>/data
```

### 3. Check Network Subnet

Find available subnet:

```bash
make network
```

Choose an unused subnet in the `192.168.X.0/24` range.

### 4. Add Secrets to Infisical

Add all required secrets to Infisical vault:

```bash
# Example secrets
SERVICE_NAME_DB_PASSWORD
SERVICE_NAME_ADMIN_PASSWORD
SERVICE_NAME_API_KEY
```

Follow naming convention: `<SERVICE>_<COMPONENT>_<PURPOSE>`

### 5. Document the Service

Create `docs/services/<service-name>.md`:

```markdown
# Service Name

Brief description of the service.

## Overview

What the service does, key features.

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SERVICE_KEY` | Description | `value` |

### Volumes

- `config/`: Configuration files
- `data/`: Persistent data

## Access

**URL**: `https://<service-name>.${DOMAINNAME}`

**Default credentials**:
- Username: Set via `SERVICE_ADMIN_USER`
- Password: Set via `SERVICE_ADMIN_PASSWORD`

## First-Time Setup

1. Access service URL
2. Complete setup wizard
3. Configure settings

## Usage

How to use the service.

## Backup

Service data backed up via Restic from `${DATA_DIR}/<service-name>/`.

## Troubleshooting

Common issues and solutions.

## See Also

- [Official Documentation](https://example.com)
- [Related Service](other-service.md)
```

### 6. Add to Include List

Edit `compose.prod.yaml` (or `compose.dev.yaml`):

```yaml
include:
  # ... existing services ...
  - compose/<service-name>/compose.yaml
```

### 7. Update mkdocs.yml

Add to navigation:

```yaml
nav:
  - Services:
      # ... existing services ...
      - Service Name: services/<service-name>.md
```

### 8. Test Deployment

```bash
# Validate configuration
make config

# Deploy
make up

# Check status
docker compose ps <service-name>

# View logs
docker compose logs -f <service-name>

# Test access
curl https://<service-name>.yourdomain.com
```

### 9. Run Pre-commit Checks

```bash
pre-commit run --all-files
```

### 10. Commit Changes

```bash
git add compose/<service-name>/
git add docs/services/<service-name>.md
git add compose.prod.yaml
git add mkdocs.yml
git commit -m "feat(service): add <service-name>"
git push
```

## Service Patterns

### Web Service Only

```yaml
services:
  myservice:
    image: myservice:latest
    networks:
      - ingress
      - vnet-myservice
    labels:
      - traefik.enable=true
      # ... Traefik labels
```

### Service with Database

```yaml
services:
  myservice:
    image: myservice:latest
    networks:
      - ingress
      - vnet-myservice
    environment:
      DB_HOST: myservice-db
      DB_NAME: myservice
      DB_USER: myservice
      DB_PASSWORD: "${MYSERVICE_DB_PASSWORD:?err}"
    depends_on:
      - myservice-db

  myservice-db:
    image: postgres:16
    container_name: myservice-db
    networks:
      - vnet-myservice  # NOT on ingress
    environment:
      POSTGRES_DB: myservice
      POSTGRES_USER: myservice
      POSTGRES_PASSWORD: "${MYSERVICE_DB_PASSWORD:?err}"
    volumes:
      - myservice_db_data:/var/lib/postgresql/data
```

### Service with Docker API Access

```yaml
services:
  myservice:
    image: myservice:latest
    networks:
      - ingress
      - vnet-socket  # For Docker API
    environment:
      DOCKER_HOST: tcp://cetusguard:2375

networks:
  ingress:
    external: true
  vnet-socket:
    external: true
```

### Service Without Authentication

For services with built-in auth:

```yaml
labels:
  - traefik.http.routers.myservice.middlewares=chain-no-auth@file
```

Or configure bypass in Authelia access rules.

## Security Checklist

Before adding service, ensure:

- [ ] `security_opt: no-new-privileges:true` set
- [ ] Resource limits configured
- [ ] Secrets in Infisical, not hardcoded
- [ ] Dedicated network (`vnet-service`)
- [ ] Only connects to required networks
- [ ] Non-root user (`user: "${PUID}:${PGID}"`) if possible
- [ ] Traefik labels correct if web-accessible
- [ ] Authentication configured (Authelia or service-specific)
- [ ] Database not on ingress network
- [ ] No direct Docker socket access

## Common Patterns

### Extend Base Service

Use common base definitions:

```yaml
services:
  myservice:
    extends:
      file: ../common/compose.yaml
      service: base
    image: myservice:latest
    # Additional config
```

### Multiple Instances

Run multiple instances of same service:

```yaml
services:
  myservice-1:
    # Config for instance 1

  myservice-2:
    # Config for instance 2
    # Use different ports, volumes, networks
```

### Init Containers (Workaround)

Docker Compose doesn't have init containers, but you can use depends_on with healthcheck:

```yaml
services:
  myservice:
    depends_on:
      init-task:
        condition: service_completed_successfully

  init-task:
    image: myservice:latest
    command: /init.sh
    restart: "no"
```

## Testing

### Local Testing

Test in development environment:

```bash
# Use dev compose
docker compose -f compose.yaml -f compose.dev.yaml up -d <service-name>

# Check logs
docker compose logs -f <service-name>

# Test functionality
```

### Validation

```bash
# Validate compose syntax
docker compose config

# Check secret injection
make config | grep SERVICE_NAME

# Verify network
docker network inspect vnet-<service-name>

# Check resources
docker stats <service-name>
```

## Troubleshooting

### Service Won't Start

Check logs:
```bash
docker compose logs <service-name>
```

Common issues:
- Missing secrets
- Permission errors
- Port conflicts
- Network issues

### Can't Access via Web

Check:
- Service on `ingress` network?
- Traefik labels correct?
- DNS configured?
- Authelia allowing access?

### Database Connection Fails

Check:
- Both services on same network?
- DB_HOST correct?
- Credentials correct?
- Database ready? (add healthcheck)

## Best Practices

1. **Pin versions** - Use specific tags with digests
2. **Document thoroughly** - Complete service documentation
3. **Test extensively** - Before committing
4. **Follow conventions** - Naming, structure, security
5. **Minimal networks** - Only connect to required networks
6. **Resource limits** - Prevent resource exhaustion
7. **Health checks** - Add healthcheck where possible
8. **Graceful shutdown** - Use proper stop signals
9. **Backup considerations** - Document what needs backup
10. **Update mkdocs** - Keep navigation updated

## Service Template

Copy this template for new services:

```yaml
# compose/<service-name>/compose.yaml

services:
  <service-name>:
    image: <image>:<version>@sha256:<digest>
    container_name: <service-name>
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "${PUID}:${PGID}"
    networks:
      - ingress
      - vnet-<service-name>
    environment:
      TZ: ${TZ}
      # Service-specific vars
    volumes:
      - ${DATA_DIR}/<service-name>/config:/config
      - ${DATA_DIR}/<service-name>/data:/data
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:<port>/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - traefik.enable=true
      - traefik.docker.network=ingress
      - traefik.http.routers.<service-name>.rule=Host(`<service-name>.${DOMAINNAME}`)
      - traefik.http.routers.<service-name>.entrypoints=websecure
      - traefik.http.routers.<service-name>.tls.certresolver=letsencrypt
      - traefik.http.routers.<service-name>.middlewares=chain-authelia@file
      - traefik.http.services.<service-name>.loadbalancer.server.port=<port>

networks:
  ingress:
    external: true
  vnet-<service-name>:
    name: vnet-<service-name>
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.X.0/24
          gateway: 192.168.X.1
```

## See Also

- [Network Architecture](../infrastructure/network-architecture.md) - Network design
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [Services Index](../services/index.md) - Existing services
- [How to Contribute](index.md) - Contribution guidelines
