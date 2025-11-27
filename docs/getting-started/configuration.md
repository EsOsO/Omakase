# Configuration

This guide covers post-installation configuration of Omakase services.

## Environment Variables

All environment variables are managed through Infisical. See [Secrets Management](../security/secrets-management.md) for details.

### Core Variables

Required for all deployments:

| Variable | Description | Example |
|----------|-------------|---------|
| `DATA_DIR` | Base directory for persistent data | `/mnt/storage/omakase` |
| `DOMAINNAME` | Base domain for services | `example.com` |
| `TRAEFIK_TRUSTED_IPS` | Trusted IP ranges | `192.168.1.0/24` |
| `PUID` | User ID for non-root execution | `1000` |
| `PGID` | Group ID for non-root execution | `1000` |
| `TZ` | Timezone | `Europe/Rome` |

### Service-Specific Variables

Each service requires its own set of secrets following the pattern:
`<SERVICE>_<COMPONENT>_<PURPOSE>`

Example:
```
NEXTCLOUD_DB_PASSWORD=secure-password
NEXTCLOUD_ADMIN_PASSWORD=another-secure-password
VAULTWARDEN_ADMIN_TOKEN=token-here
```

## Service Configuration

### Authelia (SSO)

Authelia provides single sign-on for all services.

1. Configure users in `compose/authelia/config/users_database.yml`
2. Set up SMTP for password resets
3. Configure 2FA requirements

### Traefik (Reverse Proxy)

Traefik automatically discovers services via Docker labels.

Configure TLS:
- Automatic Let's Encrypt certificates
- Custom certificate resolver: `letsencrypt`
- DNS challenge for wildcard certificates

### CrowdSec (IPS)

Configure security collections:
```bash
docker exec crowdsec cscli collections list
docker exec crowdsec cscli collections install crowdsecurity/traefik
```

## Network Configuration

Services use isolated networks. See [Network Architecture](../infrastructure/network-architecture.md) for details.

To check allocated subnets:
```bash
make network
```

## Storage Configuration

### Directory Structure

Standard layout:
```
${DATA_DIR}/
├── service-name/
│   ├── config/
│   ├── data/
│   └── logs/
```

### Permissions

Ensure correct ownership:
```bash
chown -R ${PUID}:${PGID} ${DATA_DIR}/service-name
```

## Backup Configuration

See [Backup Guide](../operations/backup.md) for configuring automated backups.

## Monitoring Configuration

Configure monitoring dashboards:
- Dozzle: Real-time container logs
- Homepage: Service dashboard
- Portainer: Container management

## Next Steps

- [Add Services](../contributing/adding-services.md) - Add new services to your stack
- [Network Architecture](../infrastructure/network-architecture.md) - Understand network isolation
- [Backup](../operations/backup.md) - Configure automated backups
