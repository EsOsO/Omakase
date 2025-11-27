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

Located in `compose/traefik/config/traefik.yml`:

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

### Dynamic Configuration

Located in `compose/traefik/config/dynamic/`:

**Middleware** (`middlewares.yml`):
```yaml
http:
  middlewares:
    chain-authelia:
      chain:
        middlewares:
          - crowdsec
          - authelia
          - security-headers
```

## Service Integration

### Basic Web Service

Add Traefik labels to your service:

```yaml
services:
  myservice:
    image: myapp:latest
    networks:
      - ingress
    labels:
      - traefik.enable=true
      - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
      - traefik.http.routers.myservice.entrypoints=websecure
      - traefik.http.routers.myservice.tls.certresolver=letsencrypt
      - traefik.http.services.myservice.loadbalancer.server.port=8080
```

### Service with Authentication

Protect service with Authelia SSO:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
  - traefik.http.routers.myservice.entrypoints=websecure
  - traefik.http.routers.myservice.tls.certresolver=letsencrypt
  - traefik.http.routers.myservice.middlewares=chain-authelia@file
  - traefik.http.services.myservice.loadbalancer.server.port=8080
```

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

## SSL Certificates

### Let's Encrypt HTTP Challenge

Default method (requires port 80 accessible):

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

### DNS Challenge

For wildcard certificates:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

### Custom Certificates

Mount custom certificates:

```yaml
volumes:
  - ./certs:/certs
labels:
  - traefik.http.routers.myservice.tls.domains[0].main=mydomain.com
  - traefik.http.routers.myservice.tls.domains[0].sans=*.mydomain.com
```

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
# List all HTTP routers
docker exec traefik traefik healthcheck

# View configuration
docker exec traefik cat /etc/traefik/traefik.yml
```

### Test Routing

```bash
# Test specific host
curl -H "Host: myservice.yourdomain.com" http://localhost

# With SSL
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

**Check service on ingress network**:
```bash
docker network inspect ingress | jq '.[]Containers'
```

### SSL Certificate Issues

**Certificate not issued**:
```bash
# Check ACME logs
docker compose logs traefik | grep acme

# Verify port 80 accessible externally
curl http://yourdomain.com/.well-known/acme-challenge/test
```

**Rate limits**: Let's Encrypt has rate limits. Wait if hit.

**Check certificate storage**:
```bash
docker exec traefik cat /letsencrypt/acme.json | jq
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

1. **Always use middleware chains** - Apply security headers, Authelia, CrowdSec
2. **Pin Traefik version** - Don't use `:latest` tag
3. **Monitor certificate renewal** - Check ACME logs regularly
4. **Use specific network** - Always specify `traefik.docker.network=ingress`
5. **Test in development** - Use `compose.dev.yaml` for testing routing
6. **Document custom middleware** - Keep middleware definitions clear
7. **Backup ACME storage** - Include `/letsencrypt/acme.json` in backups

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
