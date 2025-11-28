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

Located in `compose/core/cetusguard/compose.yaml`:

```yaml
services:
  cetusguard:
    image: docker.io/hectorm/cetusguard:v1.1.2
    container_name: cetusguard
    extends:
      file: ../common/compose.yaml
      service: base  # Includes: restart, no-new-privileges, etc.
    privileged: true  # Required for Docker socket access
    read_only: true   # Container filesystem read-only
    mem_limit: 64M
    mem_reservation: 32M
    networks:
      - vnet-socket
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    expose:
      - 2375  # Not exposed to host, only to vnet-socket network
    environment:
      CETUSGUARD_BACKEND_ADDR: unix:///var/run/docker.sock
      CETUSGUARD_FRONTEND_ADDR: tcp://:2375
      CETUSGUARD_LOG_LEVEL: '7'  # Debug level
      CETUSGUARD_RULES: |
        GET %API_PREFIX_EVENTS%
        GET,HEAD,POST %API_PREFIX_EXEC%(/.*)?
        GET,HEAD,POST %API_PREFIX_CONTAINERS%(/.*)?
        GET,HEAD %API_PREFIX_IMAGES%(/.*)?
        GET,HEAD %API_PREFIX_VOLUMES%(/.*)?
        GET,HEAD %API_PREFIX_NETWORKS%(/.*)?
        GET,HEAD %API_PREFIX_BUILD%(/.*)?

networks:
  vnet-socket:
    name: vnet-socket
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.91.0/24
```

!!! warning "Privileged Mode Required"
    Cetusguard runs in **privileged mode** to access the Docker socket. This is necessary for socket proxying but the container filesystem is read-only and it's isolated on a dedicated network.

!!! info "Rule-Based Access Control"
    Cetusguard uses a **rules-based system** instead of simple read-only mode. Rules define which HTTP methods are allowed for which API endpoints using pattern matching with API prefix variables.

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
      - vnet-ingress  # For web access via Traefik
      - vnet-socket   # For Docker API via Cetusguard
    environment:
      DOCKER_HOST: tcp://cetusguard:2375
```

## Permissions & Rules

### Rule-Based Access Control

Cetusguard uses a rules-based system with pattern matching:

```yaml
CETUSGUARD_RULES: |
  GET %API_PREFIX_EVENTS%                        # Event stream
  GET,HEAD,POST %API_PREFIX_EXEC%(/.*)?         # Container exec
  GET,HEAD,POST %API_PREFIX_CONTAINERS%(/.*)?   # Container operations
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?            # Image read-only
  GET,HEAD %API_PREFIX_VOLUMES%(/.*)?           # Volume read-only
  GET,HEAD %API_PREFIX_NETWORKS%(/.*)?          # Network read-only
  GET,HEAD %API_PREFIX_BUILD%(/.*)?             # Build read-only
```

### API Prefix Variables

Cetusguard uses variables for API versioning:

- `%API_PREFIX_EVENTS%` → `/events`, `/v1.*/events`
- `%API_PREFIX_EXEC%` → `/containers/.*/exec`, `/v1.*/containers/.*/exec`
- `%API_PREFIX_CONTAINERS%` → `/containers`, `/v1.*/containers`
- `%API_PREFIX_IMAGES%` → `/images`, `/v1.*/images`
- `%API_PREFIX_VOLUMES%` → `/volumes`, `/v1.*/volumes`
- `%API_PREFIX_NETWORKS%` → `/networks`, `/v1.*/networks`
- `%API_PREFIX_BUILD%` → `/build`, `/v1.*/build`

### Allowed Operations

Based on the rules configuration:

**Read Operations** (GET, HEAD):
- ✅ List/inspect containers
- ✅ View container logs
- ✅ List/inspect images
- ✅ List/inspect volumes
- ✅ List/inspect networks
- ✅ Event stream monitoring
- ✅ Build information

**Write Operations** (POST):
- ✅ Container exec (for interactive shells)
- ✅ Container operations (start, stop, restart, pause, unpause)
- ✅ Container creation (for management tools)

**Blocked Operations**:
- ❌ DELETE operations (cannot delete containers, images, etc.)
- ❌ Image pull/push
- ❌ PUT operations (cannot update configs)

!!! warning "POST Operations Allowed"
    Unlike typical "read-only" proxies, this configuration **allows POST operations** on containers and exec endpoints. This is necessary for management tools like Portainer to function properly, but it means services can start/stop containers and execute commands.

### Modifying Rules

To restrict further, edit the rules:

```yaml
# Example: True read-only (no POST operations)
CETUSGUARD_RULES: |
  GET %API_PREFIX_EVENTS%
  GET,HEAD %API_PREFIX_EXEC%(/.*)?
  GET,HEAD %API_PREFIX_CONTAINERS%(/.*)?
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?
  GET,HEAD %API_PREFIX_VOLUMES%(/.*)?
  GET,HEAD %API_PREFIX_NETWORKS%(/.*)?
  GET,HEAD %API_PREFIX_BUILD%(/.*)?
```

```yaml
# Example: Allow specific operations only
CETUSGUARD_RULES: |
  GET %API_PREFIX_CONTAINERS%/json              # List only
  GET %API_PREFIX_CONTAINERS%/.*/json          # Inspect only
  GET %API_PREFIX_CONTAINERS%/.*/logs          # Logs only
  GET %API_PREFIX_IMAGES%/json                  # Image list only
```

## Security

### Security Options

Cetusguard configuration includes:

```yaml
extends:
  file: ../common/compose.yaml
  service: base  # Includes no-new-privileges:true
privileged: true     # Required for Docker socket
read_only: true      # Container filesystem read-only
mem_limit: 64M       # Memory constraint
mem_reservation: 32M # Reserved memory
```

!!! danger "Privileged Mode Caveat"
    While Cetusguard runs in **privileged mode** (required for Docker socket access), security is maintained through:

    - ✅ Read-only container filesystem
    - ✅ Network isolation (`vnet-socket` only)
    - ✅ Rule-based API filtering
    - ✅ Memory limits
    - ✅ Docker socket mounted read-only
    - ✅ No host network access
    - ✅ Not exposed to external network

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
# List containers (allowed)
docker exec myservice curl http://cetusguard:2375/v1.43/containers/json

# Try container start (allowed by rules)
docker exec myservice curl -X POST http://cetusguard:2375/v1.43/containers/{id}/start

# Try delete operation (should fail - not in rules)
docker exec myservice curl -X DELETE http://cetusguard:2375/v1.43/containers/{id}

# Try image pull (should fail - POST not allowed for images)
docker exec myservice curl -X POST http://cetusguard:2375/v1.43/images/create
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

### Custom Rules

The `CETUSGUARD_RULES` environment variable uses a pattern-based syntax:

**Format**: `<methods> <pattern>`

**Examples**:
```yaml
CETUSGUARD_RULES: |
  # Allow GET and HEAD for all container endpoints
  GET,HEAD %API_PREFIX_CONTAINERS%(/.*)?

  # Allow POST only for specific actions
  POST %API_PREFIX_CONTAINERS%/.*/start
  POST %API_PREFIX_CONTAINERS%/.*/stop
  POST %API_PREFIX_CONTAINERS%/.*/restart

  # Allow exec access (GET for info, POST for execution)
  GET,POST %API_PREFIX_EXEC%(/.*)?

  # Read-only image access
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?
```

**Pattern Syntax**:
- `%API_PREFIX_*%` - Expands to API paths with version support
- `(/.*)?` - Optional regex for subpaths
- `.*` - Wildcard matching

### Log Level

Adjust logging verbosity (0-7):

```yaml
CETUSGUARD_LOG_LEVEL: '7'  # Debug (most verbose)
CETUSGUARD_LOG_LEVEL: '6'  # Info
CETUSGUARD_LOG_LEVEL: '4'  # Warning
CETUSGUARD_LOG_LEVEL: '3'  # Error (least verbose)
```

### Frontend Address

Change listening address/port:

```yaml
CETUSGUARD_FRONTEND_ADDR: tcp://:2375      # Default - all interfaces in container
CETUSGUARD_FRONTEND_ADDR: tcp://0.0.0.0:2375  # Explicit all interfaces
CETUSGUARD_FRONTEND_ADDR: tcp://127.0.0.1:2375 # Loopback only (less useful in container)
```

!!! info "No Rate Limiting or User-Agent Filtering"
    The current Cetusguard configuration does not implement rate limiting or user-agent filtering. Access control is purely rule-based. All services on `vnet-socket` have equal access to allowed endpoints.

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

### Risk With Cetusguard (Current Configuration)

With POST operations enabled:
- ✅ Network isolated (vnet-socket only)
- ✅ Cannot DELETE containers/images
- ✅ Cannot pull/push images
- ✅ Auditable access (logs)
- ⚠️ **Can start/stop/restart containers**
- ⚠️ **Can execute commands in containers**
- ⚠️ **Can create new containers** (if Portainer-like tools need it)

!!! danger "Important Security Considerations"
    The current configuration is **not truly read-only**. Services with access to Cetusguard can:

    - Start, stop, restart, pause, unpause containers
    - Execute arbitrary commands in running containers (`docker exec`)
    - Potentially create containers (depends on exact rule interpretation)

    This is a **trade-off for functionality** (Portainer, management tools). If compromised, a service on `vnet-socket` could:
    - Stop critical services
    - Execute commands in other containers
    - Cause denial of service

    **Mitigation**:
    - Only trusted services connect to `vnet-socket`
    - Monitor Cetusguard logs for suspicious activity
    - Consider separate Cetusguard instances with different rules for different service tiers
    - Regularly audit services with Docker API access

### Recommended Rule Sets by Trust Level

**High Trust (Management Tools)**:
```yaml
# Full management capability
CETUSGUARD_RULES: |
  GET %API_PREFIX_EVENTS%
  GET,HEAD,POST %API_PREFIX_EXEC%(/.*)?
  GET,HEAD,POST %API_PREFIX_CONTAINERS%(/.*)?
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?
```

**Medium Trust (Monitoring Tools)**:
```yaml
# Read-only plus exec for troubleshooting
CETUSGUARD_RULES: |
  GET %API_PREFIX_EVENTS%
  GET,HEAD,POST %API_PREFIX_EXEC%(/.*)?
  GET,HEAD %API_PREFIX_CONTAINERS%(/.*)?
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?
```

**Low Trust (Display Only)**:
```yaml
# Pure read-only
CETUSGUARD_RULES: |
  GET,HEAD %API_PREFIX_CONTAINERS%(/.*)?
  GET,HEAD %API_PREFIX_IMAGES%(/.*)?
```

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

### Resource Limits

Cetusguard is configured with conservative memory limits:

```yaml
mem_limit: 64M        # Hard limit - container killed if exceeded
mem_reservation: 32M  # Soft limit - guaranteed memory
```

**Actual usage**:
- Typical memory usage: 8-15MB
- CPU usage: negligible (<1%)
- Startup time: instant

### Network Overhead

Cetusguard adds minimal network overhead:
- Latency: <1ms for most operations
- Throughput: No significant impact
- Connection pooling: Maintains persistent connections

### Benchmarking

Test API response times:

```bash
# Direct socket
time docker ps

# Via Cetusguard
time docker -H tcp://cetusguard:2375 ps
```

Expected difference: 1-5ms (negligible for typical operations).

## See Also

- [Network Architecture](network-architecture.md) - Network design
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [Services Index](../services/index.md) - Available services
