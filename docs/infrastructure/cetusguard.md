# Cetusguard

Cetusguard is a Docker socket proxy that provides secure, read-only access to the Docker API.

## Overview

Cetusguard provides:
- **Docker API proxy** - Safe access to Docker socket
- **Read-only by default** - Prevents destructive operations
- **Filtered endpoints** - Only exposes necessary APIs
- **Security isolation** - Never expose raw Docker socket
- **Network-based access** - Services connect via dedicated network

## Why Cetusguard?

**Problem**: Many services (Portainer, Homepage, Dozzle) need Docker API access. Directly mounting Docker socket (`/var/run/docker.sock`) gives **full root access** to the host.

**Solution**: Cetusguard proxies Docker API with:
- Read-only access
- Filtered endpoints
- Network isolation
- Audit logging

## Configuration

### Basic Setup

Located in `compose.yaml`:

```yaml
services:
  cetusguard:
    image: ghcr.io/hectorm/cetusguard:latest
    container_name: cetusguard
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - vnet-socket
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      CETUSGUARD_BACKEND_ADDR: unix:///var/run/docker.sock
      CETUSGUARD_FRONTEND_ADDR: tcp://0.0.0.0:2375
      CETUSGUARD_READONLY_ENABLED: "true"

networks:
  vnet-socket:
    name: vnet-socket
    driver: bridge
```

## Service Integration

### Monitoring Tools

Services that need Docker API access:

**Portainer**:
```yaml
services:
  portainer:
    environment:
      DOCKER_HOST: tcp://cetusguard:2375
    networks:
      - vnet-socket
```

**Homepage**:
```yaml
services:
  homepage:
    environment:
      DOCKER_HOST: tcp://cetusguard:2375
    networks:
      - vnet-socket
```

**Dozzle**:
```yaml
services:
  dozzle:
    environment:
      DOCKER_HOST: tcp://cetusguard:2375
    networks:
      - vnet-socket
```

### Network Configuration

All services needing Docker API:

1. Connect to `vnet-socket` network
2. Set `DOCKER_HOST=tcp://cetusguard:2375`
3. **Never** mount Docker socket directly

```yaml
services:
  myservice:
    networks:
      - ingress
      - vnet-socket
    environment:
      DOCKER_HOST: tcp://cetusguard:2375
```

## Permissions

### Read-Only Mode

By default, Cetusguard operates in read-only mode:

**Allowed operations**:
- List containers: `GET /containers/json`
- Inspect containers: `GET /containers/{id}/json`
- View logs: `GET /containers/{id}/logs`
- List images: `GET /images/json`
- List networks: `GET /networks`
- List volumes: `GET /volumes`

**Blocked operations**:
- Create containers: `POST /containers/create`
- Start/stop containers: `POST /containers/{id}/start`
- Delete containers: `DELETE /containers/{id}`
- Pull images: `POST /images/create`

### Writable Mode (Not Recommended)

For services that need write access (use cautiously):

```yaml
environment:
  CETUSGUARD_READONLY_ENABLED: "false"
  CETUSGUARD_ALLOWLIST_ENABLED: "true"
  CETUSGUARD_ALLOWLIST: "/containers/json,/images/json,/containers/create"
```

**Warning**: Only enable write access if absolutely necessary and with minimal permissions.

## Security

### Security Options

Always use security hardening:

```yaml
security_opt:
  - no-new-privileges:true
read_only: true  # Container filesystem read-only
tmpfs:
  - /tmp
```

### Network Isolation

Cetusguard on dedicated network:
- Only monitoring tools connect
- No direct external access
- No connection to other service networks

```yaml
networks:
  vnet-socket:
    name: vnet-socket
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.91.0/24
```

### Socket Mounting

Mount Docker socket read-only:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Monitoring

### Check Cetusguard Status

```bash
# Verify running
docker compose ps cetusguard

# View logs
docker compose logs cetusguard

# Test connection
curl http://cetusguard:2375/version
```

### API Access Test

From service container:

```bash
# List containers
docker exec myservice curl http://cetusguard:2375/v1.43/containers/json

# Try write operation (should fail)
docker exec myservice curl -X POST http://cetusguard:2375/v1.43/containers/create
```

### Audit Logs

Monitor API requests:

```bash
docker compose logs cetusguard | grep "method=POST"
```

## Troubleshooting

### Service Can't Connect

**Check network**:
```bash
docker network inspect vnet-socket
```

Verify both Cetusguard and service are on network.

**Check environment variable**:
```bash
docker exec myservice env | grep DOCKER_HOST
```

Should show: `DOCKER_HOST=tcp://cetusguard:2375`

**Test connectivity**:
```bash
docker exec myservice ping cetusguard
docker exec myservice curl http://cetusguard:2375/version
```

### Permission Denied

**Expected behavior** - Read-only mode blocks write operations.

**If write access needed**:
1. Evaluate if truly necessary
2. Use allowlist for specific endpoints
3. Document why needed
4. Consider alternative solutions

### API Version Mismatch

If service reports API version incompatibility:

**Check Docker API version**:
```bash
docker version --format '{{.Server.APIVersion}}'
```

**Update service configuration** to use correct API version:
```yaml
environment:
  DOCKER_API_VERSION: "1.43"
```

## Advanced Configuration

### Custom Allowlist

Allow specific operations:

```yaml
environment:
  CETUSGUARD_READONLY_ENABLED: "false"
  CETUSGUARD_ALLOWLIST_ENABLED: "true"
  CETUSGUARD_ALLOWLIST: |
    GET /containers/json
    GET /containers/*/json
    GET /containers/*/logs
    POST /containers/*/start
    POST /containers/*/stop
```

### Request Filtering

Filter by user agent:

```yaml
environment:
  CETUSGUARD_FILTER_ENABLED: "true"
  CETUSGUARD_FILTER_USERAGENT: "Portainer,Homepage,Dozzle"
```

### Rate Limiting

Prevent API abuse:

```yaml
environment:
  CETUSGUARD_RATELIMIT_ENABLED: "true"
  CETUSGUARD_RATELIMIT_REQUESTS: "100"
  CETUSGUARD_RATELIMIT_PERIOD: "1m"
```

## Comparison with Alternatives

### Socket Proxy

**Cetusguard advantages**:
- Actively maintained
- More secure defaults
- Better filtering capabilities
- Modern architecture

### Tecnativa Docker Socket Proxy

Alternative option:

```yaml
services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy
    environment:
      CONTAINERS: 1
      POST: 0
```

Cetusguard preferred for:
- Better documentation
- More granular control
- Active development

## Best Practices

1. **Never expose Docker socket directly** - Always use proxy
2. **Use read-only mode** - Enable write only when necessary
3. **Dedicated network** - Isolate socket access
4. **Audit access** - Monitor logs for suspicious activity
5. **Minimal permissions** - Only grant needed API access
6. **Regular updates** - Keep Cetusguard updated
7. **Document exceptions** - Note why write access granted

## Security Implications

### Risk Without Proxy

Direct Docker socket access (`/var/run/docker.sock`):
- ⚠️ Full root access to host
- ⚠️ Can create privileged containers
- ⚠️ Can mount host filesystem
- ⚠️ Can escape to host
- ⚠️ Complete system compromise

### Risk With Cetusguard

Read-only proxy:
- ✅ Limited to read operations
- ✅ Cannot create/modify containers
- ✅ Cannot access host filesystem
- ✅ Network isolated
- ✅ Auditable access

## Migration from Direct Socket

If currently using direct socket mounts:

1. **Deploy Cetusguard**:
   ```bash
   make up
   ```

2. **Update service configurations**:
   ```yaml
   # Remove:
   # volumes:
   #   - /var/run/docker.sock:/var/run/docker.sock

   # Add:
   networks:
     - vnet-socket
   environment:
     DOCKER_HOST: tcp://cetusguard:2375
   ```

3. **Restart services**:
   ```bash
   docker compose restart myservice
   ```

4. **Verify functionality**:
   ```bash
   docker compose logs myservice
   ```

## Performance

### Overhead

Cetusguard adds minimal overhead:
- Network latency: <1ms
- CPU usage: negligible
- Memory usage: ~10MB

### Benchmarking

Test API response times:

```bash
# Direct socket
time docker ps

# Via Cetusguard
time docker -H tcp://cetusguard:2375 ps
```

Difference should be negligible.

## See Also

- [Network Architecture](network-architecture.md) - Network design
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [Services Index](../services/index.md) - Available services
