# Network Architecture

Omakase uses a multi-layered network architecture for security and isolation.

## Network Overview

### Shared Networks

Two shared networks for cross-service communication:

**vnet-ingress** (192.168.90.0/24):
- Public-facing services
- Connected to Traefik reverse proxy
- Protected by Authelia SSO
- Monitored by CrowdSec IPS

**vnet-socket** (192.168.91.0/24):
- Docker API access
- Connected through Cetusguard proxy
- Access via Cetusguard proxy
- Used by monitoring tools (Dozzle, Portainer, Homepage)

### Service-Specific Networks

Each service has its own isolated network: `vnet-<service>`

**Benefits**:
- Network segmentation
- Reduced attack surface
- Traffic isolation
- Simplified firewall rules

## Network Configuration

### Defining Networks

Shared networks are defined in service compose files (e.g., `compose/core/traefik/compose.yaml`):

```yaml
networks:
  vnet-ingress:
    name: vnet-ingress
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.90.0/24

  vnet-socket:
    name: vnet-socket
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.91.0/24
```

### Service Network

Each service defines its own isolated network with small subnet sizes:

```yaml
networks:
  vnet-myservice:
    name: vnet-myservice
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.Y/29  # /29 = 8 IPs, /28 = 16 IPs
```

!!! info "Subnet Sizing"
    - **Shared networks**: /24 (254 hosts) for vnet-ingress and vnet-socket
    - **Service networks**: /29 (6 usable IPs) or /28 (14 usable IPs)
    - Small subnets minimize attack surface and resource usage

### Subnet Allocation

Check allocated subnets:
```bash
make network
```

**Allocation Strategy**:

- **Shared networks** (large /24 subnets):
  - `192.168.90.0/24` - vnet-ingress
  - `192.168.91.0/24` - vnet-socket

- **Service networks** (small /29 or /28 subnets):
  - `192.168.10.0/29` - vnet-traefik
  - `192.168.20.16/29` - vnet-authelia
  - `192.168.20.32/29` - vnet-immich
  - `192.168.21.16/28` - vnet-local-ai

**Subnet Size Guidelines**:
- `/29` (6 usable IPs): Simple service with 1-2 containers
- `/28` (14 usable IPs): Service with multiple containers (3+)
- `/24` (254 usable IPs): Shared networks only

!!! warning "Non-Sequential Allocation"
    Service subnets are **not** allocated sequentially. Always check `make network` before adding a new service to avoid conflicts.

## Service Network Patterns

### Web-Accessible Service

Service with web interface:

```yaml
services:
  myservice:
    networks:
      - vnet-ingress   # For Traefik access
      - vnet-myservice # Service isolation
    labels:
      - traefik.enable=true
      - traefik.docker.network=vnet-ingress
      - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)

networks:
  vnet-ingress:
    external: true
  vnet-myservice:
    name: vnet-myservice
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.Y/29
```

### Service with Database

Service with dedicated database:

```yaml
services:
  myservice:
    networks:
      - vnet-ingress
      - vnet-myservice
    environment:
      DB_HOST: myservice-db

  myservice-db:
    image: postgres:16
    networks:
      - vnet-myservice  # Only on service network
    # No vnet-ingress - not web accessible

networks:
  vnet-ingress:
    external: true
  vnet-myservice:
    name: vnet-myservice
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.Y/29
```

### Docker API Access

Service needing Docker API:

```yaml
services:
  monitoring-tool:
    networks:
      - vnet-ingress
      - vnet-socket    # For Docker API access
    environment:
      DOCKER_HOST: tcp://cetusguard:2375

networks:
  vnet-ingress:
    external: true
  vnet-socket:
    external: true
```

## Network Security

### Isolation Rules

1. **Default deny** - Services only connect to required networks
2. **Minimal exposure** - Databases never on ingress network
3. **Proxy all Docker API** - No direct socket access
4. **Separate data and control** - Service traffic on dedicated networks

### Network Policies

**Web services**:
- ✅ Connect to `vnet-ingress`
- ✅ Connect to own `vnet-service`
- ❌ Never directly to other service networks

**Databases**:
- ✅ Connect to own `vnet-service`
- ❌ Never to `vnet-ingress`
- ❌ Never to other service networks

**Monitoring tools**:
- ✅ Connect to `vnet-ingress`
- ✅ Connect to `vnet-socket`
- ❌ Never directly to service networks

### Firewall Rules

Services communicate through defined networks only:

```yaml
# Service A cannot reach Service B database
# Even though both are running on same host
# Because they're on different networks
```

## Traffic Flow

### Web Request Flow

1. **External request** → Port 80 (Traefik)
2. **Traefik** (on vnet-ingress) → Receives request
3. **CrowdSec** → Analyzes traffic
4. **Authelia** → Authenticates user
5. **Service** (on vnet-ingress) → Receives authorized request
6. **Service → Database** (on vnet-service) → Internal communication

### Service-to-Service

Services that need to communicate must:

1. Share a common network OR
2. Use vnet-ingress (less secure, only if needed) OR
3. Create dedicated shared network (preferred)

Example shared network for service-to-service:
```yaml
networks:
  vnet-shared:
    name: vnet-shared
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.Y/29
```

## DNS Resolution

### Internal DNS

Docker provides automatic DNS resolution within networks:

```yaml
# Service can reach database by name
environment:
  DB_HOST: myservice-db  # Resolves within vnet-myservice
```

### External DNS

Configure DNS to point to your server:
```
*.yourdomain.com → server-ip
```

Traefik handles internal routing based on Host rules.

## Network Troubleshooting

### Check Network Connectivity

```bash
# List networks
docker network ls

# Inspect network
docker network inspect vnet-service

# Check which containers on network
docker network inspect vnet-service | jq '.[0].Containers'

# Test connectivity from container
docker exec myservice ping myservice-db
docker exec myservice nslookup myservice-db
```

### Network Conflicts

If subnet conflicts occur:

```bash
# View all allocated subnets
make network

# Or manually
docker network inspect $(docker network ls -q) | jq '.[].IPAM.Config'
```

Choose unused subnet range for new service.

### Connection Refused

Check if services are on same network:

```bash
docker inspect myservice | jq '.[0].NetworkSettings.Networks'
docker inspect myservice-db | jq '.[0].NetworkSettings.Networks'
```

Both should share at least one network.

## Network Monitoring

### Traffic Analysis

View network traffic:
```bash
docker stats --format "table {{.Name}}\t{{.NetIO}}"
```

### Connection Count

Check active connections:
```bash
docker exec myservice netstat -an | grep ESTABLISHED | wc -l
```

### DNS Resolution

Test DNS:
```bash
docker exec myservice nslookup myservice-db
docker exec myservice ping myservice-db
```

## Best Practices

1. **One service network per service** - Always create dedicated `vnet-<service>`
2. **Minimal network connections** - Only connect to required networks
3. **Never expose Docker socket** - Always use Cetusguard proxy
4. **Document network topology** - Keep subnet allocation updated
5. **Use network aliases** - For complex setups
6. **Monitor network usage** - Track bandwidth consumption
7. **Test network isolation** - Verify services can't reach unrelated services

## Network Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Internet                                                 │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ :443/:80
                  │
┌─────────────────▼───────────────────────────────────────┐
│ Traefik (vnet-ingress)                                  │
│   - HTTP routing (port 80)                              │
│   - SSL upstream                                        │
└─────────┬─────────────────────┬─────────────────────────┘
          │                     │
          │                     │
    ┌─────▼──────┐        ┌────▼────────┐
    │ Authelia   │        │  CrowdSec   │
    │   (SSO)    │        │    (IPS)    │
    └─────┬──────┘        └─────────────┘
          │
          │
    ┌─────▼────────────────────────────────┐
    │ vnet-ingress (192.168.90.0/24)       │
    │   - All web-accessible services      │
    └──────────────────────────────────────┘
          │         │         │
    ┌─────▼───┐ ┌──▼────┐ ┌──▼────────┐
    │ Service │ │Service│ │  Service  │
    │    A    │ │   B   │ │     C     │
    └─────┬───┘ └──┬────┘ └──┬────────┘
          │        │          │
    ┌─────▼───┐ ┌──▼────┐ ┌──▼────────┐
    │vnet-svcA│ │vnet-  │ │ vnet-svcC │
    │         │ │ svcB  │ │           │
    │ ┌─────┐ │ │ ┌───┐ │ │  ┌─────┐  │
    │ │DB A │ │ │ │DB │ │ │  │DB C │  │
    │ └─────┘ │ │ └───┘ │ │  └─────┘  │
    └─────────┘ └───────┘ └───────────┘

┌──────────────────────────────────────────────┐
│ vnet-socket (192.168.91.0/24)                │
│   - Cetusguard (Docker API proxy)            │
│   - Monitoring tools                         │
└──────────────────────────────────────────────┘
```

## See Also

- [Traefik](traefik.md) - Reverse proxy configuration
- [Authelia](authelia.md) - SSO authentication
- [CrowdSec](crowdsec.md) - Intrusion prevention
- [Cetusguard](cetusguard.md) - Docker socket protection
