# Security

Security is a core principle of Omakase homelab infrastructure. This section covers security architecture, best practices, and management.

## Security Overview

Omakase implements defense-in-depth with multiple security layers:

```
┌─────────────────────────────────────────────┐
│ External Threats                            │
└──────────────┬──────────────────────────────┘
               │
        ┌──────▼───────┐
        │   CrowdSec   │  ← Layer 1: Intrusion Prevention
        │     (IPS)    │
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │   Authelia   │  ← Layer 2: Authentication
        │     (SSO)    │
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │   Traefik    │  ← Layer 3: Reverse Proxy
        │  (Security   │     + Security Headers
        │   Headers)   │
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │   Network    │  ← Layer 4: Network Isolation
        │  Isolation   │
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │  Container   │  ← Layer 5: Container Security
        │   Security   │
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │   Secrets    │  ← Layer 6: Secret Management
        │  Management  │
        └──────────────┘
```

## Security Layers

### 1. Intrusion Prevention (CrowdSec)

**Purpose**: Block malicious traffic before it reaches services.

**Features**:
- Real-time threat detection
- Automatic IP blocking
- Community threat intelligence
- Attack pattern recognition

**Learn more**: [CrowdSec Documentation](../infrastructure/crowdsec.md)

### 2. Authentication (Authelia)

**Purpose**: Verify user identity and enforce access control.

**Features**:
- Single Sign-On (SSO)
- Two-Factor Authentication (2FA)
- Fine-grained access control
- Session management

**Learn more**: [Authelia Documentation](../infrastructure/authelia.md)

### 3. Reverse Proxy (Traefik)

**Purpose**: Secure routing and SSL termination.

**Features**:
- Automatic SSL certificates
- Security headers
- Request filtering
- Rate limiting

**Learn more**: [Traefik Documentation](../infrastructure/traefik.md)

### 4. Network Isolation

**Purpose**: Segment services to limit blast radius.

**Features**:
- Per-service networks
- Shared network minimization
- No direct inter-service communication
- Docker socket protection

**Learn more**: [Network Architecture](../infrastructure/network-architecture.md)

### 5. Container Security

**Purpose**: Harden containers against compromise.

**Features**:
- No new privileges
- Resource limits
- Read-only filesystems where possible
- Non-root execution

**Mandatory security options**:
```yaml
security_opt:
  - no-new-privileges:true
user: "${PUID}:${PGID}"
read_only: true  # When possible
```

### 6. Secret Management

**Purpose**: Secure storage and injection of credentials.

**Features**:
- External secret vault (Infisical)
- Zero secrets in git
- Environment variable injection
- Encrypted storage

**Learn more**: [Secrets Management](secrets-management.md)

## Security Checklist

### Initial Setup

- [ ] Configure Infisical for secret management
- [ ] Generate strong passwords (use `make pwgen`)
- [ ] Set up Authelia users with 2FA
- [ ] Configure CrowdSec collections
- [ ] Enable automatic SSL certificates
- [ ] Review and configure access control rules
- [ ] Set up backup encryption

### Ongoing Maintenance

- [ ] Review CrowdSec alerts weekly
- [ ] Rotate credentials quarterly
- [ ] Update Docker images regularly
- [ ] Monitor authentication logs
- [ ] Review user access permissions
- [ ] Test backup restores
- [ ] Audit security configurations

### Before Adding Services

- [ ] Review service security documentation
- [ ] Configure dedicated network (`vnet-service`)
- [ ] Set security options (`no-new-privileges`)
- [ ] Define resource limits
- [ ] Store secrets in Infisical
- [ ] Apply Authelia protection
- [ ] Test access controls

## Common Security Patterns

### Web Service with Authentication

```yaml
services:
  myservice:
    image: myservice:latest
    container_name: myservice
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "${PUID}:${PGID}"
    networks:
      - ingress
      - vnet-myservice
    environment:
      SECRET_KEY: "${MYSERVICE_SECRET_KEY:?err}"
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
    labels:
      - traefik.enable=true
      - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
      - traefik.http.routers.myservice.middlewares=chain-authelia@file
      - traefik.http.routers.myservice.tls.certresolver=letsencrypt
```

### Database Service

```yaml
services:
  myservice-db:
    image: postgres:16
    container_name: myservice-db
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    user: "${PUID}:${PGID}"
    networks:
      - vnet-myservice  # Only on service network
    environment:
      POSTGRES_PASSWORD: "${MYSERVICE_DB_PASSWORD:?err}"
    volumes:
      - myservice_db_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 1G
    # NO ingress network - not publicly accessible
    # NO Traefik labels - no external access
```

### Service with Docker API Access

```yaml
services:
  monitoring:
    image: monitoring-tool:latest
    container_name: monitoring
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - ingress
      - vnet-socket  # For Docker API
    environment:
      DOCKER_HOST: tcp://cetusguard:2375  # Never direct socket!
```

## Security Incidents

### Response Procedure

1. **Identify**: Determine scope of incident
   ```bash
   docker compose logs <service> | grep -i error
   docker exec crowdsec cscli alerts list
   ```

2. **Contain**: Stop affected services
   ```bash
   docker compose stop <service>
   ```

3. **Investigate**: Analyze logs and traffic
   ```bash
   docker compose logs <service> > incident.log
   docker exec crowdsec cscli alerts inspect <alert-id>
   ```

4. **Remediate**: Fix vulnerability
   - Rotate compromised credentials
   - Update vulnerable images
   - Adjust security rules

5. **Recover**: Restore from backup if needed
   ```bash
   docker exec restic-backup restic restore latest --target /restore
   ```

6. **Review**: Prevent recurrence
   - Document incident
   - Update security policies
   - Implement additional controls

### Indicators of Compromise

Watch for:
- Unexpected authentication failures
- Unusual resource usage
- Modified configuration files
- Unknown containers/images
- Unexpected network connections
- CrowdSec ban spikes

## Compliance and Standards

### Applied Standards

Omakase follows industry best practices:

- **CIS Docker Benchmark** - Container hardening
- **OWASP Top 10** - Web application security
- **NIST Cybersecurity Framework** - Risk management
- **Zero Trust Architecture** - Never trust, always verify

### Security Features Mapping

| Security Control | Implementation |
|------------------|----------------|
| Authentication | Authelia SSO + 2FA |
| Authorization | Access control rules |
| Encryption in Transit | TLS via Traefik |
| Encryption at Rest | Restic backup encryption |
| Network Segmentation | Per-service networks |
| Intrusion Detection | CrowdSec IPS |
| Secrets Management | Infisical vault |
| Container Hardening | Security options + resource limits |
| Audit Logging | Docker logs + CrowdSec |
| Backup & Recovery | Automated Restic backups |

## Security Resources

### Documentation

- [Secrets Management](secrets-management.md) - Credential handling
- [Best Practices](best-practices.md) - Security guidelines
- [CrowdSec](../infrastructure/crowdsec.md) - Intrusion prevention
- [Authelia](../infrastructure/authelia.md) - Authentication
- [Network Architecture](../infrastructure/network-architecture.md) - Network security

### External Resources

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Traefik Security](https://doc.traefik.io/traefik/https/tls/)

## Security Contact

For security issues:
- Report vulnerabilities via GitHub security advisories
- Report vulnerabilities responsibly
- Never commit sensitive data to git

## Quick Reference

### Check Security Status

```bash
# Service status
docker compose ps

# CrowdSec alerts
docker exec crowdsec cscli alerts list

# Failed auth attempts
docker compose logs authelia | grep "authentication failed"

# Open ports
sudo netstat -tulpn | grep LISTEN

# Resource usage
docker stats
```

### Emergency Actions

```bash
# Block IP immediately
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 24h

# Stop compromised service
docker compose stop <service>

# Rotate credential
make pwgen
# Update in Infisical
docker compose restart <service>

# Full shutdown
make down
```

## See Also

- [Installation](../getting-started/installation.md) - Secure setup
- [Operations](../operations/maintenance.md) - Security maintenance
- [Deployment](../deployment/proxmox-lxc.md) - Secure deployment
