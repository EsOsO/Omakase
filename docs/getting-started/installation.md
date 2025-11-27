# Installation

This guide will walk you through installing Omakase homelab infrastructure.

## Prerequisites

Before proceeding with installation, ensure you have completed all [prerequisites](prerequisites.md).

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/omakase.git
cd omakase
```

### 2. Set Up Infisical

Configure your Infisical authentication:

```bash
export INFISICAL_DOMAIN="your-infisical-domain"
export INFISICAL_PROJECT_ID="your-project-id"
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
```

### 3. Configure Secrets

Add all required secrets to your Infisical vault. See [Secrets Management](../security/secrets-management.md) for details.

Required environment variables:
- `DATA_DIR` - Base directory for persistent data
- `DOMAINNAME` - Base domain for services
- `TRAEFIK_TRUSTED_IPS` - Trusted IP ranges
- `PUID`/`PGID` - User/group IDs for non-root execution
- `TZ` - Timezone

### 4. Validate Configuration

Before deploying, validate your compose files:

```bash
make config
```

This will verify:
- Compose file syntax
- Secret injection from Infisical
- Network configuration

### 5. Deploy Services

For development environment:

```bash
make up
```

For production environment:

```bash
INFISICAL_TOKEN=$(infisical login ...) infisical run --env=prod -- docker compose -f compose.yaml -f compose.prod.yaml up -d
```

### 6. Verify Deployment

Check that all services are running:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f
```

## Post-Installation

### Configure DNS

Point your domain's DNS records to your server's IP address:

```
*.yourdomain.com -> your-server-ip
```

### Access Services

Services will be available at:
- Homepage: `https://home.yourdomain.com`
- Traefik Dashboard: `https://traefik.yourdomain.com`
- Portainer: `https://portainer.yourdomain.com`

All services are protected by Authelia SSO.

## Next Steps

- [Configuration](configuration.md) - Configure individual services
- [Operations Guide](../operations/backup.md) - Set up backups and monitoring
- [Troubleshooting](../operations/troubleshooting.md) - Common issues and solutions
