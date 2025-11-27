# [Service Name]

> **Template Instructions**: Replace all `[placeholders]` with actual values. Remove this note before committing.

## Overview

[Brief 2-3 sentence description of what this service does and why it's included in Omakase]

- **Purpose**: [Main use case - e.g., "Photo management and sharing", "Password vault", "Media streaming"]
- **Version**: `[X.Y.Z]` (pinned in compose.yaml)
- **Official Website**: [https://project.example.com](https://project.example.com)
- **Documentation**: [https://docs.example.com](https://docs.example.com)
- **Docker Image**: `[dockerhub/image:version]`

## Features

- ✅ [Key feature 1]
- ✅ [Key feature 2]
- ✅ [Key feature 3]
- ✅ SSO integration via Authelia (if applicable)
- ✅ Automated backups (if has database)
- ✅ Resource limits configured

## Prerequisites

### Required Services

- [x] Traefik (reverse proxy)
- [x] Authelia (authentication)
- [ ] PostgreSQL 16 (if uses database)
- [ ] [Other dependencies]

### Required Secrets in Infisical

Add these secrets to your Infisical project before deployment:

| Secret Name | Generate With | Purpose | Example |
|-------------|---------------|---------|---------|
| `[SERVICE]_DB_PASSWORD` | `make pwgen` | Database password | `abc123...` |
| `[SERVICE]_API_KEY` | Service UI | External API access | `sk-...` |
| `[SERVICE]_ADMIN_PASSWORD` | `make pwgen` | Initial admin password | `xyz789...` |
| `[SERVICE]_SECRET_KEY` | `make pwgen` | Application secret | `def456...` |

### Data Directories

These directories will be created automatically on first deployment:

```bash
${DATA_DIR}/[service-name]/
├── config/        # Configuration files
├── data/          # Application data
├── cache/         # Cache files (not backed up)
└── logs/          # Log files (optional)
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         ingress                              │
│                    (192.168.90.0/24)                        │
│                                                              │
│  ┌──────────┐              ┌─────────────┐                 │
│  │ Traefik  │─────────────▶│  [Service]  │                 │
│  └──────────┘              └─────────────┘                 │
│                                   │                          │
└───────────────────────────────────┼──────────────────────────┘
                                    │
┌───────────────────────────────────┼──────────────────────────┐
│                          vnet-[service]                      │
│                      (192.168.X.Y/Z)                        │
│                                   │                          │
│                            ┌─────────────┐                  │
│                            │  [Service]  │                  │
│                            └─────────────┘                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Networks Used**:
- `ingress`: For Traefik routing (public access)
- `vnet-[service]`: Isolated service network (databases also on this network)

**Allocated Subnet**: `192.168.X.Y/Z` (see `make network`)

## Configuration

### Step 1: Add Secrets to Infisical

```bash
# Login to Infisical (if not already)
source .env
infisical login \
  --domain=$INFISICAL_DOMAIN \
  --method=universal-auth \
  --client-id=$INFISICAL_CLIENT_ID \
  --client-secret=$INFISICAL_CLIENT_SECRET
```

Add secrets via Infisical UI or CLI:

```bash
# Example: Add database password
PASSWORD=$(make pwgen)
infisical secrets set [SERVICE]_DB_PASSWORD "$PASSWORD" \
  --domain=$INFISICAL_DOMAIN \
  --projectId=$INFISICAL_PROJECT_ID
```

### Step 2: Configure Service Files (if needed)

If service requires configuration files:

```bash
# Copy example configuration
cp compose/[service-name]/config/config.yml.example \
   compose/[service-name]/config/config.yml

# Edit configuration
nano compose/[service-name]/config/config.yml
```

!!! warning "Configuration File Security"
    Ensure sensitive config files are in `.gitignore`:
    ```bash
    git check-ignore compose/[service-name]/config/config.yml
    ```

### Step 3: Configure Authelia Access (Optional)

If service supports OIDC/SSO, configure Authelia integration:

```bash
# Create OIDC client configuration
nano compose/authelia/config/oidc.d/[service-name]
```

See [Authelia OIDC Configuration](../infrastructure/authelia.md#oidc-integration) for details.

## Deployment

### Enable Service

Edit the appropriate compose file:

=== "Production"

    Edit `compose.prod.yaml`:
    ```yaml
    include:
      - compose/[service-name]/compose.yaml
    ```

=== "Development"

    Edit `compose.dev.yaml`:
    ```yaml
    include:
      - compose/[service-name]/compose.yaml
    ```

### Deploy

```bash
# Pull latest image
make pull

# Deploy (creates directories and starts service)
make up

# Verify deployment
docker compose ps [service-name]
docker compose logs -f [service-name]
```

### Verify Service Health

```bash
# Check container status
docker compose ps [service-name]
# Should show: "Up" and "healthy" status

# Check logs for errors
docker compose logs [service-name] | grep -i error

# Test network connectivity
docker exec [service-name] ping -c 3 postgres-16

# Verify in Traefik dashboard
# Access: https://traefik.yourdomain.com
# Look for: [service].yourdomain.com router
```

## First-Time Setup

### Access the Service

1. **Navigate to**: `https://[service].yourdomain.com`
2. **Authenticate**: Login via Authelia SSO
3. **Initial Setup**: Complete first-run wizard

### Initial Configuration

#### Step 1: [First configuration step]

[Detailed instructions with screenshots if complex]

```bash
# Any CLI commands needed
```

#### Step 2: [Second configuration step]

[More instructions]

#### Step 3: [Third configuration step]

[Final setup steps]

### Recommended Settings

Configure these settings for optimal operation:

- **[Setting 1]**: [Recommended value and why]
- **[Setting 2]**: [Recommended value and why]
- **[Setting 3]**: [Recommended value and why]

## Integration with Other Services

### Authelia SSO (Single Sign-On)

[If service supports OIDC]

This service is protected by Authelia. Configuration:

```yaml
# compose/authelia/config/oidc.d/[service-name]
---
id: [service-name]
description: [Service Name] OIDC Client
secret: "{{env "[SERVICE]_OIDC_SECRET"}}"
public: false
authorization_policy: two_factor
redirect_uris:
  - https://[service].{{env "DOMAINNAME"}}/oauth/callback
scopes:
  - openid
  - profile
  - email
  - groups
```

### Backup Integration

[If service has database or important data]

Automated backups configured in:

- **Location**: `compose/backup/restic/commands/pre-commands.sh`
- **Schedule**: Daily at 3:30 AM
- **Retention**: 7 daily, 4 weekly, 12 monthly

Database dump command:

```bash
docker exec [service]-db pg_dump -U [user] [database] > \
  /tmp/backup/[service]-$(date +\%Y\%m\%d).sql
```

### Reverse Proxy (Traefik)

Traefik labels configured in `compose/[service-name]/compose.yaml`:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.[service].rule=Host(`[service].{{env "DOMAINNAME"}}`)
  - traefik.http.routers.[service].entrypoints=websecure
  - traefik.http.routers.[service].tls.certresolver=letsencrypt
  - traefik.http.routers.[service].middlewares=chain-authelia@file
  - traefik.http.services.[service].loadbalancer.server.port=[PORT]
```

### [Other Service Integration]

[If integrates with Jellyfin, Nextcloud, etc.]

## Monitoring & Maintenance

### Logs

View service logs:

```bash
# Real-time logs
docker compose logs -f [service-name]

# Last 100 lines
docker compose logs --tail=100 [service-name]

# Search for errors
docker compose logs [service-name] | grep -i error

# Via Dozzle web UI
# Access: https://dozzle.yourdomain.com
```

### Health Checks

Service health monitoring:

```bash
# Check health status
docker compose ps [service-name]

# Manual health check
curl -f http://localhost:[PORT]/health
# or
docker exec [service-name] [health-check-command]
```

Healthcheck configured in compose file:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:[PORT]/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Resource Usage

Monitor resource consumption:

```bash
# Real-time stats
docker stats [service-name]

# Current resource limits
docker inspect [service-name] | jq '.[0].HostConfig.Memory'
docker inspect [service-name] | jq '.[0].HostConfig.NanoCpus'
```

**Configured Limits**:
- CPU: [X] cores
- Memory: [Y]MB limit, [Z]MB reservation
- Restart policy: `on-failure:3`

### Updates

Updates are automated via Renovate bot:

- **Patch updates**: Auto-merged after CI passes
- **Minor updates**: Manual review required
- **Major updates**: Careful review and testing

Manual update:

```bash
# Pull latest image
docker compose pull [service-name]

# Recreate container
docker compose up -d [service-name]

# Verify
docker compose logs [service-name]
```

### Backup & Restore

#### Manual Backup

```bash
# Backup configuration
tar -czf [service]-config-$(date +%Y%m%d).tar.gz \
  ${DATA_DIR}/[service-name]/config/

# Backup database (if applicable)
docker exec [service]-db pg_dump -U [user] [database] | \
  gzip > [service]-db-$(date +%Y%m%d).sql.gz
```

#### Restore from Backup

```bash
# Stop service
docker compose stop [service-name]

# Restore configuration
tar -xzf [service]-config-backup.tar.gz -C ${DATA_DIR}/[service-name]/

# Restore database (if applicable)
gunzip < [service]-db-backup.sql.gz | \
  docker exec -i [service]-db psql -U [user] [database]

# Start service
docker compose start [service-name]
```

## Troubleshooting

### Common Issues

#### Issue: Service won't start

**Symptoms**:
```
docker compose ps [service-name]
# Shows: "Restarting" or "Exited"
```

**Diagnosis**:
```bash
# Check logs
docker compose logs [service-name]

# Common errors to look for:
# - "permission denied" → Volume permissions issue
# - "connection refused" → Database not ready
# - "secret not found" → Missing Infisical secret
```

**Solutions**:

1. **Check secrets**:
   ```bash
   make config | grep [SERVICE]
   ```

2. **Fix permissions**:
   ```bash
   sudo chown -R $PUID:$PGID ${DATA_DIR}/[service-name]
   ```

3. **Verify database**:
   ```bash
   docker compose ps postgres-16
   ```

#### Issue: Can't access via web browser

**Symptoms**: Timeout or 404 error at `https://[service].yourdomain.com`

**Diagnosis**:
```bash
# Check if container is running
docker compose ps [service-name]

# Check Traefik routing
docker compose logs traefik | grep [service-name]

# Verify DNS
dig [service].yourdomain.com
```

**Solutions**:

1. **Check Traefik labels**:
   ```bash
   docker inspect [service-name] | jq '.[0].Config.Labels'
   ```

2. **Verify network connectivity**:
   ```bash
   docker exec traefik ping [service-name]
   ```

3. **Check Authelia**:
   ```bash
   docker compose logs authelia | grep -i error
   ```

#### Issue: [Service-specific issue]

**Symptoms**: [Description]

**Solutions**: [Steps to resolve]

### Debug Mode

Enable debug logging:

```bash
# Edit compose file
nano compose/[service-name]/compose.yaml

# Add environment variable
environment:
  LOG_LEVEL: debug

# Restart service
docker compose up -d [service-name]

# View debug logs
docker compose logs -f [service-name]
```

### Getting Help

1. **Check logs**: `docker compose logs [service-name]`
2. **Official docs**: [Link to official troubleshooting]
3. **GitHub Issues**: [Link to project issues]
4. **Omakase Discussions**: [GitHub Discussions]
5. **Community**: [r/selfhosted](https://reddit.com/r/selfhosted)

## Security Considerations

### Network Isolation

- ✅ Dedicated network: `vnet-[service]`
- ✅ No direct internet access (via Traefik only)
- ✅ Isolated from other services
- ✅ Database access restricted to service network

### Authentication & Authorization

- ✅ Protected by Authelia SSO
- ✅ [2FA required / Optional based on Authelia config]
- ✅ [OIDC integration / API key authentication]

### Data Protection

- ✅ Daily encrypted backups
- ✅ Secrets in Infisical vault
- ✅ SSL/TLS via Traefik
- ✅ [Database encryption at rest - if supported]

### Security Best Practices

1. **Change default credentials**: [If applicable]
2. **Enable 2FA**: [If service supports it]
3. **Review access logs**: `docker compose logs [service-name] | grep auth`
4. **Keep updated**: Automated via Renovate bot
5. **Restrict API access**: [If service has API]

### Security Checklist

- [ ] All secrets in Infisical (not hardcoded)
- [ ] Authelia authentication enabled
- [ ] Network isolation verified
- [ ] Resource limits configured
- [ ] Backups tested and working
- [ ] Default credentials changed
- [ ] 2FA enabled (if supported)
- [ ] SSL certificate valid

## Performance Tuning

### Resource Optimization

Current limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '[X]'
      memory: [Y]M
    reservations:
      memory: [Z]M
```

**Adjust if needed**:

```bash
# Edit compose file
nano compose/[service-name]/compose.yaml

# Increase memory limit
memory: 512M  # Increase from default

# Restart service
docker compose up -d [service-name]
```

### Caching

[If service uses Redis/Redict]

Cache configuration:

```yaml
environment:
  REDIS_HOST: redict
  REDIS_PORT: 6379
  CACHE_TTL: 3600
```

### Database Optimization

[If service uses PostgreSQL]

Optimize database:

```bash
# Vacuum and analyze
docker exec [service]-db psql -U [user] -c "VACUUM ANALYZE;"

# Check database size
docker exec [service]-db psql -U [user] -c "SELECT pg_size_pretty(pg_database_size('[database]'));"
```

## Advanced Configuration

### [Advanced Feature 1]

[Description and configuration]

### [Advanced Feature 2]

[Description and configuration]

### Custom Configuration

For advanced customization, see:
- [Official documentation](https://docs.example.com/advanced)
- Service configuration: `compose/[service-name]/config/`

## Migration from Other Systems

### From [Other Solution]

[If applicable - migration guide from competing solutions]

### Import Existing Data

[Steps to import data from backups or other sources]

## API Access

[If service provides API]

### API Endpoint

```
https://[service].yourdomain.com/api/v1
```

### Authentication

[API key setup, OAuth, etc.]

### Example API Calls

```bash
# Example: List items
curl -H "Authorization: Bearer $API_KEY" \
  https://[service].yourdomain.com/api/v1/items

# Example: Create item
curl -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}' \
  https://[service].yourdomain.com/api/v1/items
```

## Additional Resources

### Official Documentation

- [Installation Guide](https://docs.example.com/install)
- [User Manual](https://docs.example.com/manual)
- [API Reference](https://docs.example.com/api)

### Community Resources

- [GitHub Repository](https://github.com/project/repo)
- [Discord Server](https://discord.gg/example)
- [Reddit Community](https://reddit.com/r/example)
- [YouTube Tutorials](https://youtube.com/example)

### Omakase Resources

- [Architecture Overview](../architecture/overview.md)
- [Network Design](../architecture/network.md)
- [Backup Guide](../operations/backup.md)
- [Authelia Configuration](../infrastructure/authelia.md)

---

**Maintained by**: Omakase Community
**Service Version**: [X.Y.Z]
**Documentation Version**: 1.0.0
**Last Updated**: 2025-11-25
