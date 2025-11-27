# Security Best Practices

Comprehensive security guidelines for managing Omakase homelab.

## Core Principles

### 1. Defense in Depth

**Never rely on a single security control**. Layer multiple protections:

```
External Request
  → CrowdSec (Block malicious IPs)
  → Traefik (SSL + Security headers)
  → Authelia (Authentication + 2FA)
  → Network Isolation (Limit access)
  → Container Security (Hardened config)
  → Application (Service-specific security)
```

### 2. Least Privilege

**Grant minimum necessary permissions**:

- Services only connect to required networks
- Use read-only filesystems where possible
- Non-root container execution
- Limited Docker API access via Cetusguard
- Restrictive access control rules

### 3. Zero Trust

**Never trust, always verify**:

- Authenticate every request (Authelia)
- Verify even internal traffic
- Don't skip security for "internal" services
- Assume breach, limit blast radius

### 4. Security by Default

**Secure out of the box**:

- All services protected by Authelia
- Automatic SSL certificates
- Network isolation by default
- Security options mandatory
- Secrets never in git

## Secret Management

### Rule #1: Never Commit Secrets

**NEVER in git**:
- ❌ Passwords
- ❌ API keys
- ❌ Tokens
- ❌ Private keys
- ❌ Certificates

**Always in Infisical**:
- ✅ All credentials
- ✅ Environment variables
- ✅ Service secrets
- ✅ API tokens

### Generate Strong Secrets

```bash
# Use pwgen for passwords
make pwgen

# For API keys (32 bytes)
openssl rand -hex 32

# For tokens (64 bytes)
openssl rand -base64 64
```

### Secret Rotation

Rotate credentials regularly:

**Quarterly**:
- Service passwords
- API keys
- Database passwords

**Annually**:
- SSL certificates (automatic with Let's Encrypt)
- SSH keys
- Backup encryption keys

**Immediately**:
- After suspected compromise
- When employee leaves (if shared homelab)
- After sharing access temporarily

### Secret Naming Convention

Use consistent naming:
```
<SERVICE>_<COMPONENT>_<PURPOSE>

Examples:
NEXTCLOUD_DB_PASSWORD
VAULTWARDEN_ADMIN_TOKEN
TRAEFIK_ACME_EMAIL
```

## Container Security

### Mandatory Security Options

**Every service MUST have**:

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents privilege escalation within containers.

### User Permissions

Run as non-root:

```yaml
user: "${PUID}:${PGID}"  # Typically 1000:1000
```

**Benefits**:
- Limits damage if container compromised
- Prevents host file system modification
- Follows least privilege principle

### Resource Limits

Always set limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

**Prevents**:
- Resource exhaustion attacks
- Runaway processes
- Service starvation
- System crashes

### Read-Only Filesystems

Use when possible:

```yaml
read_only: true
tmpfs:
  - /tmp
  - /var/run
```

**Not always possible** (services need write access), but use when you can.

### Drop Capabilities

Remove unnecessary Linux capabilities:

```yaml
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Only if needed
```

## Network Security

### Network Isolation Rules

1. **Every service gets own network**:
   ```yaml
   networks:
     vnet-myservice:
       name: vnet-myservice
   ```

2. **Only connect to required networks**:
   ```yaml
   networks:
     - ingress  # Only if web-accessible
     - vnet-myservice  # Always
   ```

3. **Never connect databases to ingress**:
   ```yaml
   services:
     myservice-db:
       networks:
         - vnet-myservice  # NOT ingress
   ```

4. **Use Cetusguard for Docker API**:
   ```yaml
   environment:
     DOCKER_HOST: tcp://cetusguard:2375
   ```
   **NEVER** mount Docker socket directly.

### Firewall Configuration

**Host firewall** (UFW):
```bash
# Default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WireGuard (if used)
sudo ufw allow 51820/udp

# Enable
sudo ufw enable
```

### Port Exposure

**Minimize exposed ports**:
- Only expose 80/443 (Traefik)
- WireGuard port if using VPN
- SSH port (consider non-standard port)

**Never expose**:
- Database ports
- Admin interfaces directly
- Docker API
- Internal services

## Authentication

### Authelia Configuration

**Require 2FA for sensitive services**:

```yaml
access_control:
  rules:
    - domain:
        - "vaultwarden.yourdomain.com"
        - "portainer.yourdomain.com"
      policy: two_factor
      subject:
        - "group:admins"
```

**Use one_factor for regular services**:
```yaml
    - domain: "*.yourdomain.com"
      policy: one_factor
```

**Never use bypass unless necessary**:
```yaml
    - domain: "public.yourdomain.com"
      policy: bypass  # Only for truly public services
```

### Password Requirements

**Minimum standards**:
- 16+ characters for admin accounts
- 12+ characters for user accounts
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words
- Unique per service

**Use password manager**:
- Bitwarden/Vaultwarden
- KeePass
- 1Password

### 2FA Enforcement

**Require for**:
- All admin accounts
- Sensitive services (password manager, admin panels)
- Services with financial data
- Services with personal data

**2FA methods**:
1. **TOTP** (recommended) - Google Authenticator, Authy
2. **WebAuthn** (most secure) - YubiKey, hardware keys
3. **Duo Push** (convenient) - Push notifications

## Backup Security

### Encrypted Backups

**Always encrypt**:
```yaml
environment:
  RESTIC_PASSWORD: "${RESTIC_PASSWORD:?err}"
```

**Benefits**:
- Protection if backup storage compromised
- Compliance with data protection regulations
- Peace of mind

### Backup Storage

**3-2-1 Rule**:
- **3** copies of data
- **2** different storage types
- **1** off-site copy

**Omakase implementation**:
- Primary: Production data in `${DATA_DIR}`
- Secondary: Encrypted Restic repository
- Off-site: Backblaze B2 cloud storage

### Test Restores

**Monthly**: Perform test restore to verify backups work.

```bash
# Test restore
docker exec restic-backup restic restore latest --target /tmp/restore-test

# Verify data integrity
ls -la /tmp/restore-test

# Cleanup
rm -rf /tmp/restore-test
```

### Backup Access Control

**Limit backup access**:
- Separate Backblaze credentials from other services
- Restrict who can delete backups
- Enable MFA on Backblaze account
- Monitor backup notifications

## Monitoring and Logging

### Log Everything

**Enable logging for**:
- Authentication attempts (Authelia)
- Access logs (Traefik)
- Security events (CrowdSec)
- Container logs (Docker)
- System logs (syslog)

### Review Logs Regularly

**Daily**:
```bash
# Failed authentication
docker compose logs authelia | grep "authentication failed"

# CrowdSec blocks
docker exec crowdsec cscli decisions list

# Service errors
docker compose logs --since 24h | grep -i error
```

**Weekly**:
```bash
# Security alerts
docker exec crowdsec cscli alerts list

# Resource usage anomalies
docker stats --no-stream

# Unusual network activity
docker compose logs traefik | grep "5xx"
```

### Alerting

**Set up notifications**:
- Backup failures → Telegram
- Authentication failures → Email (Authelia)
- CrowdSec bans → Review dashboard
- Service outages → Uptime Kuma

## Update Management

### Regular Updates

**Weekly**: Pull latest images
```bash
make pull
make restart
```

**Monthly**: Update dependencies
- Review Renovate PRs
- Test in development
- Deploy to production

### Security Updates

**Immediate**: Apply critical security patches
```bash
# Pull specific image
docker pull service:version

# Restart service
docker compose restart service
```

### Update Strategy

1. **Read changelog** - Understand changes
2. **Test in dev** - Use compose.dev.yaml
3. **Backup first** - Create snapshot
4. **Deploy** - Update production
5. **Verify** - Test functionality
6. **Monitor** - Watch logs

## Incident Response

### Preparation

**Before incident**:
- Document recovery procedures
- Keep backups tested and accessible
- Have contact information ready
- Know how to isolate services

### Detection

**Monitor for**:
- CrowdSec alert spikes
- Failed authentication patterns
- Unusual resource usage
- Modified files in `${DATA_DIR}`
- Unknown containers

### Response Steps

1. **Identify**:
   ```bash
   docker compose logs <service>
   docker exec crowdsec cscli alerts list
   ```

2. **Contain**:
   ```bash
   docker compose stop <service>
   docker exec crowdsec cscli decisions add --ip <ip>
   ```

3. **Eradicate**:
   ```bash
   # Rotate credentials
   make pwgen
   # Update in Infisical

   # Update vulnerable image
   docker pull service:patched-version
   ```

4. **Recover**:
   ```bash
   # Restore from backup if needed
   docker exec restic-backup restic restore <snapshot-id>

   # Restart service
   docker compose up -d <service>
   ```

5. **Lessons Learned**:
   - Document incident
   - Update security controls
   - Review and improve monitoring

## Access Control

### User Management

**Principle**: Minimize user accounts

**Admin accounts**:
- Enable 2FA
- Strong passwords
- Regular access reviews
- Audit logs monitoring

**Regular users**:
- Enable 2FA when possible
- Access only to needed services
- Time-limited access for temporary users

### Service Access

**Internal-only services**:
```yaml
access_control:
  rules:
    - domain: "internal-admin.yourdomain.com"
      policy: two_factor
      subject:
        - "group:admins"
      networks:
        - 192.168.1.0/24  # Only from home network
```

**Shared services**:
```yaml
    - domain: "shared.yourdomain.com"
      policy: one_factor
      subject:
        - "group:users"
```

### API Access

**Service-to-service**:
- Use API keys, not passwords
- Store in Infisical
- Rotate regularly
- Minimal scope

**External APIs**:
- Separate keys per service
- Monitor usage
- Implement rate limiting
- Validate all input

## Compliance

### Data Protection

**Minimize data collection**:
- Only collect necessary data
- Delete old logs
- Encrypt sensitive data

**User privacy**:
- Transparent about data usage
- Provide data export if shared homelab
- Secure deletion procedures

### Audit Trail

**Maintain logs for**:
- Authentication attempts
- Configuration changes
- Backup operations
- Security events

**Retention**: 90 days minimum

## Security Checklist

### Daily

- [ ] Check service status: `docker compose ps`
- [ ] Review failed logins: `docker compose logs authelia | grep failed`
- [ ] Check CrowdSec blocks: `docker exec crowdsec cscli decisions list`

### Weekly

- [ ] Pull image updates: `make pull`
- [ ] Review CrowdSec alerts: `docker exec crowdsec cscli alerts list`
- [ ] Check disk usage: `df -h`
- [ ] Review backup status: `docker compose logs backup`

### Monthly

- [ ] Test backup restore
- [ ] Review user access
- [ ] Update collections: `docker exec crowdsec cscli collections upgrade --all`
- [ ] Review security logs
- [ ] Check for security advisories

### Quarterly

- [ ] Rotate passwords
- [ ] Security audit
- [ ] Review access control rules
- [ ] Update documentation
- [ ] Disaster recovery drill

## Red Flags

**Investigate immediately if**:
- Unexpected authentication failures
- Unknown containers running
- Unusual network traffic
- Modified configuration files
- Disabled security features
- Missing logs
- Backup failures
- CPU/memory spikes
- CrowdSec ban surge

## Resources

### Tools

- [Gitleaks](https://github.com/gitleaks/gitleaks) - Secret detection
- [Trivy](https://github.com/aquasecurity/trivy) - Container vulnerability scanning
- [Docker Bench](https://github.com/docker/docker-bench-security) - CIS benchmark

### Learning

- [Docker Security Docs](https://docs.docker.com/engine/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [CrowdSec Documentation](https://docs.crowdsec.net/)

## See Also

- [Secrets Management](secrets-management.md) - Credential handling
- [Security Overview](index.md) - Security architecture
- [CrowdSec](../infrastructure/crowdsec.md) - Intrusion prevention
- [Authelia](../infrastructure/authelia.md) - Authentication
