# Troubleshooting

Common issues and solutions for Omakase homelab.

## Service Won't Start

### Symptom
Service fails to start or immediately exits.

### Diagnosis
```bash
# Check service status
docker compose ps <service>

# View logs
docker compose logs <service>

# Inspect container
docker inspect <container-name>
```

### Common Causes

#### Missing Secrets
**Error**: `required variable ... not set`

**Solution**: Verify secrets in Infisical:
```bash
make config | grep <SERVICE>
```

Add missing secrets to Infisical vault.

#### Permission Issues
**Error**: `permission denied` in logs

**Solution**: Fix directory permissions:
```bash
chown -R ${PUID}:${PGID} ${DATA_DIR}/<service>
chmod -R 755 ${DATA_DIR}/<service>
```

#### Port Conflicts
**Error**: `port is already allocated`

**Solution**: Check which service is using the port:
```bash
docker ps
netstat -tulpn | grep <port>
```

#### Network Conflicts
**Error**: `network ... overlaps with other`

**Solution**: Check allocated subnets:
```bash
make network
```

Adjust subnet in compose file to avoid conflicts.

## Infisical Authentication Fails

### Symptom
Commands fail with authentication errors.

### Solution
Verify environment variables:
```bash
echo $INFISICAL_DOMAIN
echo $INFISICAL_PROJECT_ID
echo $INFISICAL_CLIENT_ID
```

Re-authenticate:
```bash
infisical login
```

Check `.env` file or export variables:
```bash
export INFISICAL_DOMAIN="your-domain"
export INFISICAL_PROJECT_ID="your-project-id"
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
```

## Can't Access Service

### Symptom
Service not accessible via browser.

### Diagnosis

#### Check Service Status
```bash
docker compose ps <service>
```

#### Check Traefik Routing
```bash
# View Traefik logs
docker compose logs traefik | grep <service>

# Access Traefik dashboard
# https://traefik.yourdomain.com
```

#### Check DNS
```bash
nslookup <service>.yourdomain.com
ping <service>.yourdomain.com
```

### Common Causes

#### DNS Not Configured
**Solution**: Add DNS record pointing to server IP:
```
*.yourdomain.com -> your-server-ip
```

#### Authelia Blocking Access
**Solution**: Check Authelia logs:
```bash
docker compose logs authelia
```

Verify user is authenticated and has access.

#### Certificate Issues
**Error**: SSL certificate errors

**Solution**: Check Let's Encrypt logs:
```bash
docker compose logs traefik | grep acme
```

Verify domain is publicly accessible on port 80/443.

#### Wrong Network Configuration
**Solution**: Verify service is on `ingress` network:
```yaml
networks:
  - ingress
```

## Database Connection Fails

### Symptom
Service can't connect to database.

### Diagnosis
```bash
# Check database is running
docker compose ps postgres

# Check database logs
docker compose logs postgres

# Test connection from service container
docker exec <service> ping postgres
```

### Solutions

#### Database Not Ready
**Solution**: Add healthcheck and depends_on:
```yaml
depends_on:
  postgres:
    condition: service_healthy
```

#### Wrong Database Credentials
**Solution**: Verify credentials in Infisical:
```bash
make config | grep DB_
```

#### Network Isolation
**Solution**: Ensure both services on same network:
```yaml
networks:
  - vnet-service
```

## Backup Fails

### Symptom
Restic backup fails to complete.

### Diagnosis
```bash
# Check backup logs
docker compose logs backup

# Test Backblaze connection
docker exec restic-backup restic snapshots
```

### Common Causes

#### Invalid Backblaze Credentials
**Solution**: Verify B2 credentials in Infisical:
```bash
make config | grep B2_
```

#### Repository Locked
**Error**: `repository is already locked`

**Solution**: Unlock repository:
```bash
docker exec restic-backup restic unlock
```

#### Storage Full
**Solution**: Check repository size and prune:
```bash
docker exec restic-backup restic stats
docker exec restic-backup restic prune
```

## High Resource Usage

### Symptom
Server running slow, high CPU/memory usage.

### Diagnosis
```bash
# Check container resource usage
docker stats

# Check system resources
htop
df -h
```

### Solutions

#### Memory Leak
Identify problematic container:
```bash
docker stats --no-stream | sort -k 4 -h
```

Restart affected service:
```bash
docker compose restart <service>
```

#### Too Many Services
Stop non-critical services:
```bash
docker compose stop <service>
```

#### Insufficient Resources
Add resource limits to compose files:
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
```

## CrowdSec Blocking Legitimate Traffic

### Symptom
Your IP is blocked by CrowdSec.

### Solution
Check decisions:
```bash
docker exec crowdsec cscli decisions list
```

Remove your IP:
```bash
docker exec crowdsec cscli decisions delete --ip <your-ip>
```

Add IP to whitelist in CrowdSec config.

## Docker Socket Permission Denied

### Symptom
Error: `permission denied while trying to connect to Docker daemon`

### Solution
This should never happen - services should use Cetusguard proxy, not direct socket access.

Check service is connecting to Cetusguard:
```yaml
environment:
  DOCKER_HOST: tcp://cetusguard:2375
```

## Configuration Validation Fails

### Symptom
`make config` shows errors.

### Diagnosis
```bash
# Validate compose syntax
docker compose -f compose.yaml config

# Check for missing secrets
make config 2>&1 | grep "not set"
```

### Solutions

#### YAML Syntax Error
Check compose file syntax:
- Correct indentation (2 spaces)
- No tabs
- Proper quoting

#### Missing Environment Variables
Add to Infisical or `.env` file.

## Logs Not Appearing

### Symptom
`docker compose logs` shows no output.

### Solutions

#### Check Log Driver
Verify logging configuration:
```bash
docker inspect <container> | grep LogConfig
```

#### Increase Log Retention
In compose file:
```yaml
logging:
  options:
    max-size: "10m"
    max-file: "3"
```

## General Debugging Steps

1. **Check service logs**:
   ```bash
   docker compose logs -f <service>
   ```

2. **Verify configuration**:
   ```bash
   make config
   ```

3. **Check service status**:
   ```bash
   docker compose ps
   ```

4. **Inspect container**:
   ```bash
   docker inspect <container>
   ```

5. **Test connectivity**:
   ```bash
   docker exec <container> ping <other-service>
   ```

6. **Check resource usage**:
   ```bash
   docker stats
   ```

7. **Review recent changes**:
   ```bash
   git log --oneline -10
   ```

## Getting Help

If you can't resolve the issue:

1. Check [GitHub Issues](https://github.com/yourusername/omakase/issues)
2. Review service-specific documentation in `docs/services/`
3. Check upstream documentation for the service
4. Search for error messages in service logs

## See Also

- [Maintenance](maintenance.md) - Regular maintenance tasks
- [Backup](backup.md) - Backup and restore procedures
- [Installation](../getting-started/installation.md) - Initial setup
