# Traefik

Traefik is the reverse proxy and ingress controller for all web services in Omakase.

## Overview

Traefik provides:
- **Automatic SSL certificates** via Let's Encrypt
- **Dynamic routing** based on Docker labels
- **Load balancing** for scaled services
- **Middleware chains** for authentication and security
- **Dashboard** for monitoring and troubleshooting

## Configuration

### Core Configuration

Traefik is configured via command-line arguments in `compose/core/traefik/compose.yaml`. Key configuration includes:

**Entry Points:**
```yaml
'--entrypoints.web.address=:80'
'--entrypoints.web.asDefault=true'
'--entryPoints.web.forwardedHeaders.trustedIPs=${TRAEFIK_TRUSTED_IPS}'
'--entryPoints.web.proxyProtocol.trustedIPs=${TRAEFIK_TRUSTED_IPS}'
```

**Additional Entry Points** (for specific services):
- `metrics` (8899) - Prometheus metrics
- `deluge` (7623/tcp) - Deluge torrent client
- `jellyfin-svc` (1900/udp) - Jellyfin service discovery
- `jellyfin-clt` (7359/udp) - Jellyfin client discovery
- `unifi-stun` (3487/udp) - UniFi STUN
- `unifi-speed` (6789/udp) - UniFi speed test
- `unifi-discovery` (10001/udp) - UniFi device discovery

**Docker Provider:**
```yaml
'--providers.docker.endpoint=tcp://cetusguard:2375'  # Via Cetusguard proxy
'--providers.docker.exposedByDefault=false'          # Explicit opt-in
'--providers.docker.network=vnet-ingress'            # Default network
```

**File Provider:**
```yaml
'--providers.file.directory=/rules'  # Dynamic configuration files
```

!!! info "No traefik.yml File"
    Unlike typical Traefik setups, this configuration uses command-line arguments instead of a `traefik.yml` file. All static configuration is defined in the compose file's `command:` section.

### Dynamic Configuration

Located in `compose/core/traefik/rules/`:

**Middleware Chain** (`chain-authelia.yml`):
```yaml
http:
  middlewares:
    chain-authelia:
      chain:
        middlewares:
          - middlewares-rate-limit      # Rate limiting
          - middlewares-secure-headers  # Security headers
          - middlewares-authelia        # SSO authentication
          - middlewares-compress        # Gzip compression
          - crowdsec                    # IPS protection
```

**CrowdSec Integration** (`crowdsec.yml`):
```yaml
http:
  middlewares:
    crowdsec:
      plugin:
        crowdsec-bouncer:
          enabled: true
          crowdseclapihost: 'crowdsec:8080'
          crowdsecappsechost: 'crowdsec:7422'
          rediscacheenabled: true
          rediscachehost: 'traefik-redict:6379'
```

**Security Headers** (`middlewares-secure-headers.yml`):
```yaml
http:
  middlewares:
    middlewares-secure-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        customFrameOptionsValue: SAMEORIGIN
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 15552000
        referrerPolicy: same-origin
        permissionsPolicy: camera=(), microphone=(self), geolocation=()
```

## Service Integration

### Basic Web Service

Add Traefik labels to your service:

```yaml
services:
  myservice:
    image: myapp:latest
    networks:
      - vnet-ingress  # Must be on the ingress network
    labels:
      - traefik.enable=true
      - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
      - traefik.http.routers.myservice.entrypoints=web
      - traefik.http.services.myservice.loadbalancer.server.port=8080
```

!!! warning "Network Requirement"
    Services must be on the `vnet-ingress` network to be accessible via Traefik. This is Omakase's shared network for public-facing services.

!!! info "No SSL Configuration in Labels"
    Unlike typical Traefik setups, **this configuration does not use Let's Encrypt directly**. SSL termination is handled upstream (e.g., HAProxy, Cloudflare, or external load balancer). You don't need `tls.certresolver` labels.

### Service with Authentication

Protect service with Authelia SSO:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
  - traefik.http.routers.myservice.entrypoints=web
  - traefik.http.routers.myservice.middlewares=chain-authelia@file
  - traefik.http.services.myservice.loadbalancer.server.port=8080
```

The `chain-authelia@file` middleware applies:
- Rate limiting
- Security headers
- Authelia SSO authentication
- Gzip compression
- CrowdSec IPS protection

### Service with Custom Domain

Use custom subdomain:

```yaml
labels:
  - traefik.http.routers.myservice.rule=Host(`custom.${DOMAINNAME}`)
```

Multiple subdomains:

```yaml
labels:
  - traefik.http.routers.myservice.rule=Host(`app1.${DOMAINNAME}`) || Host(`app2.${DOMAINNAME}`)
```

### Service with Path Prefix

Route based on path:

```yaml
labels:
  - traefik.http.routers.myservice.rule=Host(`${DOMAINNAME}`) && PathPrefix(`/api`)
  - traefik.http.middlewares.myservice-strip.stripprefix.prefixes=/api
  - traefik.http.routers.myservice.middlewares=myservice-strip
```

## Middlewares

### Security Headers

Automatically applied via middleware chain:

```yaml
http:
  middlewares:
    security-headers:
      headers:
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        forceSTSHeader: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "strict-origin-when-cross-origin"
```

### Rate Limiting

Limit request rates:

```yaml
labels:
  - traefik.http.middlewares.myservice-ratelimit.ratelimit.average=100
  - traefik.http.middlewares.myservice-ratelimit.ratelimit.burst=50
  - traefik.http.routers.myservice.middlewares=myservice-ratelimit
```

### IP Whitelist

Allow specific IPs only:

```yaml
labels:
  - traefik.http.middlewares.myservice-whitelist.ipwhitelist.sourcerange=192.168.1.0/24,10.0.0.0/8
  - traefik.http.routers.myservice.middlewares=myservice-whitelist
```

### Basic Auth

Alternative to Authelia for simple services:

```yaml
labels:
  - traefik.http.middlewares.myservice-auth.basicauth.users=user:$$apr1$$...
  - traefik.http.routers.myservice.middlewares=myservice-auth
```

Generate password:
```bash
htpasswd -nb username password
```

### Redirect

Redirect to another URL:

```yaml
labels:
  - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
  - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
```

## SSL/TLS Certificates

!!! info "Upstream SSL Termination"
    **Omakase's Traefik does not handle SSL certificates directly**. This is by design for the reference architecture where SSL termination happens upstream (e.g., OPNSense HAProxy, Cloudflare, cloud load balancer).

### Architecture Options

**Option 1: Upstream SSL Termination** (Default/Recommended)
```
Internet → [Firewall/HAProxy with SSL] → Traefik (HTTP only) → Services
```

- SSL certificates managed at firewall/load balancer level
- Traefik receives traffic on port 80 (HTTP)
- Internal communication uses HTTP or can be encrypted separately
- `TRAEFIK_TRUSTED_IPS` validates requests come from trusted proxy

**Option 2: Direct SSL with Let's Encrypt** (Requires modification)
```
Internet → Traefik (HTTPS) → Services
```

To enable Let's Encrypt, you would need to:
1. Add `websecure` entrypoint (port 443)
2. Add `certificatesResolvers` configuration
3. Update service labels to use `entrypoints=websecure` and `tls.certresolver=letsencrypt`
4. Expose port 443 in compose file

This is not the default configuration but can be adapted for simpler deployments.

## Dashboard

### Access

Dashboard protected by Authelia:
- URL: `https://traefik.${DOMAINNAME}`

### Features

- **HTTP routers**: View all routes
- **Services**: Backend service status
- **Middlewares**: Applied middleware chains
- **Certificates**: SSL certificate status

## Monitoring

### View Logs

```bash
docker compose logs -f traefik
```

### Check Routes

```bash
# Health check
docker exec traefik traefik healthcheck --ping

# View running command/configuration
docker inspect traefik | jq '.[0].Args'

# View dynamic configuration files
docker exec traefik ls -la /rules/
docker exec traefik cat /rules/chain-authelia.yml
```

### Docker API Access

!!! important "Cetusguard Proxy"
    Traefik **does not** connect to the Docker socket directly. Instead, it uses the Cetusguard proxy for security:

    ```yaml
    '--providers.docker.endpoint=tcp://cetusguard:2375'
    ```

    This provides:
    - Read-only access to Docker API
    - No container manipulation capabilities
    - Network isolation from host Docker socket
    - Audit logging of API requests

See [Cetusguard documentation](cetusguard.md) for more details.

### Test Routing

```bash
# Test specific host (internal)
curl -H "Host: myservice.yourdomain.com" http://localhost

# Test from external (if SSL upstream)
curl https://myservice.yourdomain.com
```

## Troubleshooting

### Service Not Accessible

**Check Traefik can see service**:
```bash
docker compose logs traefik | grep myservice
```

**Verify Docker labels**:
```bash
docker inspect myservice | jq '.[0].Config.Labels'
```

**Check service on vnet-ingress network**:
```bash
docker network inspect vnet-ingress | jq '.[].Containers'
```

**Verify Traefik can reach Docker API**:
```bash
# Check Cetusguard is running
docker compose ps cetusguard

# Check Traefik can communicate with Cetusguard
docker exec traefik ping -c 2 cetusguard
```

### Upstream SSL/Proxy Issues

**Trusted IPs not configured**:
```bash
# Verify TRAEFIK_TRUSTED_IPS is set correctly
docker inspect traefik | jq '.[0].Args[] | select(contains("trustedIPs"))'
```

**Check forwarded headers**:
```bash
# Enable access logs temporarily to see headers
docker compose logs traefik | grep "User-Agent"
```

### Wrong Backend

**Check service port**:
```yaml
labels:
  - traefik.http.services.myservice.loadbalancer.server.port=8080
```

Ensure port matches container's exposed port.

### Redirect Loop

**Check middleware chain**:
```bash
docker compose logs traefik | grep middleware
```

**Avoid duplicate redirects**:
- Don't redirect to HTTPS if Traefik already does it
- Check application's redirect configuration

## Advanced Configuration

### Load Balancing

For scaled services:

```yaml
deploy:
  replicas: 3
labels:
  - traefik.http.services.myservice.loadbalancer.sticky.cookie=true
  - traefik.http.services.myservice.loadbalancer.sticky.cookie.name=lb
```

### Circuit Breaker

Prevent cascading failures:

```yaml
labels:
  - traefik.http.middlewares.myservice-cb.circuitbreaker.expression=NetworkErrorRatio() > 0.30
```

### Retry

Retry failed requests:

```yaml
labels:
  - traefik.http.middlewares.myservice-retry.retry.attempts=3
  - traefik.http.middlewares.myservice-retry.retry.initialinterval=100ms
```

### Compression

Enable gzip compression:

```yaml
labels:
  - traefik.http.middlewares.myservice-compress.compress=true
```

### Request Headers

Modify request headers:

```yaml
labels:
  - traefik.http.middlewares.myservice-headers.headers.customrequestheaders.X-Forwarded-Proto=https
```

## Best Practices

1. **Always use middleware chains** - Apply the full `chain-authelia@file` for protected services
2. **Pin Traefik version** - Don't use `:latest` tag (Renovate manages updates)
3. **Use vnet-ingress network** - All public services must be on this network
4. **Specify network in labels** - When service is on multiple networks: `traefik.docker.network=vnet-ingress`
5. **Test in development** - Use `compose.dev.yaml` for testing routing
6. **Monitor CrowdSec** - Check that CrowdSec bouncer is working via dashboard
7. **Verify trusted IPs** - Ensure `TRAEFIK_TRUSTED_IPS` includes all upstream proxies
8. **Document custom middleware** - Keep middleware definitions in `/rules/` directory
9. **Never expose Docker socket** - Always use Cetusguard proxy
10. **Check Redis cache** - CrowdSec bouncer uses Redis for performance

## Performance Tuning

### Connection Limits

```yaml
entryPoints:
  websecure:
    transport:
      respondingTimeouts:
        readTimeout: 60s
        writeTimeout: 60s
      lifeCycle:
        requestAcceptGraceTimeout: 10s
        graceTimeOut: 10s
```

### Buffer Sizes

```yaml
entryPoints:
  websecure:
    transport:
      respondingTimeouts:
        idleTimeout: 180s
```

## See Also

- [Authelia](authelia.md) - SSO authentication
- [CrowdSec](crowdsec.md) - Intrusion prevention
- [Network Architecture](network-architecture.md) - Network design
