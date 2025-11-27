# Network Architecture

Omakase uses a multi-layered network architecture for security and isolation.

## Network Overview

### Shared Networks

Two shared networks for cross-service communication:

**ingress** (192.168.90.0/24):
- Public-facing services
- Connected to Traefik reverse proxy
- Protected by Authelia SSO
- Monitored by CrowdSec IPS

**vnet-socket** (192.168.91.0/24):
- Docker API access
- Connected through Cetusguard proxy
- Read-only API access
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

In `compose.yaml`:

```yaml
networks:
  ingress:
    name: ingress
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.90.0/24
          gateway: 192.168.90.1

  vnet-socket:
    name: vnet-socket
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.91.0/24
          gateway: 192.168.91.1
```

### Service Network

Each service defines its own network:

```yaml
networks:
  vnet-myservice:
    name: vnet-myservice
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.92.0/24
          gateway: 192.168.92.1
```

### Subnet Allocation

Check allocated subnets:
```bash
make network
```

**Reserved ranges**:
- `192.168.90.0/24` - ingress
- `192.168.91.0/24` - vnet-socket
- `192.168.92.0/24` - vnet-authelia
- `192.168.93.0/24` - vnet-traefik
- Continue incrementing for new services

## Service Network Patterns

### Web-Accessible Service

Service with web interface:

```yaml
services:
  myservice:
    networks:
      - ingress        # For Traefik access
      - vnet-myservice # Service isolation
    labels:
      - traefik.enable=true
      - traefik.docker.network=ingress
      - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)

networks:
  ingress:
    external: true
  vnet-myservice:
    name: vnet-myservice
    driver: bridge
```

### Service with Database

Service with dedicated database:

```yaml
services:
  myservice:
    networks:
      - ingress
      - vnet-myservice
    environment:
      DB_HOST: myservice-db

  myservice-db:
    image: postgres:16
    networks:
      - vnet-myservice  # Only on service network
    # No ingress network - not web accessible

networks:
  ingress:
    external: true
  vnet-myservice:
    name: vnet-myservice
```

### Docker API Access

Service needing Docker API:

```yaml
services:
  monitoring-tool:
    networks:
      - ingress
      - vnet-socket    # For Docker API access
    environment:
      DOCKER_HOST: tcp://cetusguard:2375

networks:
  ingress:
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
- ✅ Connect to `ingress`
- ✅ Connect to own `vnet-service`
- ❌ Never directly to other service networks

**Databases**:
- ✅ Connect to own `vnet-service`
- ❌ Never to `ingress`
- ❌ Never to other service networks

**Monitoring tools**:
- ✅ Connect to `ingress`
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

1. **External request** → Port 443
2. **Traefik** (on ingress) → Receives request
3. **CrowdSec** → Analyzes traffic
4. **Authelia** → Authenticates user
5. **Service** (on ingress) → Receives authorized request
6. **Service → Database** (on vnet-service) → Internal communication

### Service-to-Service

Services that need to communicate must:

1. Share a network OR
2. Use ingress network (less secure) OR
3. Create shared network (better)

Example shared network:
```yaml
networks:
  vnet-shared:
    name: vnet-shared
    driver: bridge
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
│ Traefik (ingress network)                               │
│   - SSL termination                                     │
│   - Routing                                             │
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
    │ ingress network (192.168.90.0/24)    │
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
