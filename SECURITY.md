# Security Policy

## Reporting a Vulnerability

We take the security of Omakase seriously. If you discover a security vulnerability, please follow these steps:

### 1. **Do Not** Open a Public Issue

Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.

### 2. Report Privately

Send a detailed report via one of these methods:

- **GitHub Security Advisories**: Use the "Security" tab → "Report a vulnerability" (preferred)
- **Email**: Contact the maintainer directly (see GitHub profile)

### 3. Include in Your Report

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact and attack scenarios
- Suggested fix (if you have one)
- Your contact information for follow-up

### 4. Response Time

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity (critical issues prioritized)

## Security Best Practices for Users

### Secrets Management

✅ **DO:**
- Use Infisical or similar secrets manager
- Generate strong passwords with `make pwgen`
- Rotate credentials regularly
- Use `.env.example` files for templates
- Install pre-commit hooks to prevent secret leaks

❌ **DON'T:**
- Commit `.env` files or `users.yml` to git
- Hardcode secrets in YAML files
- Share credentials in issues or pull requests
- Use default/example passwords in production

### Network Security

✅ **DO:**
- Keep Authelia SSO enabled for all services
- Configure CrowdSec for threat detection
- Use strong firewall rules (OPNsense/iptables)
- Limit exposed ports to only necessary services
- Use VPN for remote access when possible

❌ **DON'T:**
- Expose Docker socket directly to the internet
- Disable Authelia for convenience
- Use weak or default admin passwords
- Open unnecessary ports in your firewall

### Container Security

✅ **DO:**
- Keep all images updated (Renovate bot helps)
- Use `no-new-privileges` security option (enabled by default)
- Run containers as non-root user with PUID/PGID
- Enable resource limits (CPU/memory)
- Review Trivy scan results in CI/CD

❌ **DON'T:**
- Run containers as root when avoidable
- Disable security options without understanding risks
- Ignore Renovate bot security updates
- Use `:latest` tags in production (pinned versions preferred)

### Backup Security

✅ **DO:**
- Encrypt backups at rest (Restic does this)
- Use strong encryption passwords
- Store backups off-site (Backblaze B2, etc.)
- Test backup restoration regularly
- Limit backup access with IAM policies

❌ **DON'T:**
- Store backups unencrypted
- Keep only local backups
- Use weak backup encryption passwords
- Forget to test restore procedures

### Access Control

✅ **DO:**
- Use 2FA/TOTP for Authelia accounts
- Create separate users with appropriate permissions
- Use OIDC integration for application SSO
- Review access logs regularly
- Disable unused services/accounts

❌ **DON'T:**
- Share admin credentials
- Use same password across services
- Leave default accounts enabled
- Skip 2FA setup

## Security Features in Omakase

### Multi-Layer Security

1. **Network Isolation**: Per-service Docker networks (vnet-*)
2. **Authentication Gateway**: Authelia SSO with 2FA support
3. **Threat Detection**: CrowdSec collaborative IPS
4. **Docker API Protection**: Cetusguard read-only proxy
5. **Secret Management**: Infisical external vault
6. **HTTPS/TLS**: Automatic certificate management via Traefik
7. **Security Headers**: CSP, HSTS, X-Frame-Options, etc.

### Automated Security

- **Renovate Bot**: Automated dependency updates
- **GitHub Actions**: Docker Compose validation, security scanning
- **Pre-commit Hooks**: Secret detection (Gitleaks), key scanning
- **CrowdSec**: Real-time threat blocking and IP reputation

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest (main) | ✅ Active support |
| Older releases | ⚠️ Security fixes only |

## Security Updates

Security patches are released as soon as possible after discovery. Update your stack with:

```bash
make pull
make up
```

## Vulnerability Disclosure Policy

After a security issue is fixed:

1. **Fix Released**: Patch merged to main branch
2. **Notification**: Security advisory published on GitHub
3. **Details Published**: After 30 days or when 90% of users have updated
4. **Credit**: Reporter credited (unless they prefer anonymity)

## Security Checklist for New Deployments

- [ ] All secrets stored in Infisical (not in git)
- [ ] `users.yml` configured with strong passwords
- [ ] Authelia 2FA/TOTP enabled for admin users
- [ ] CrowdSec enrollment completed
- [ ] Firewall configured (only necessary ports open)
- [ ] Traefik SSL certificates obtained
- [ ] Backup encryption configured and tested
- [ ] Pre-commit hooks installed
- [ ] All default passwords changed
- [ ] Network subnets reviewed (no conflicts)
- [ ] Resource limits verified
- [ ] Monitoring/alerting configured (Telegram, email)

## Additional Resources

- [Secrets Management Guide](docs/security/secrets-management.md)
- [Network Architecture](docs/architecture/network-design.md)
- [Authelia Configuration](docs/infrastructure/authelia.md)
- [CrowdSec Setup](docs/infrastructure/crowdsec.md)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

## Contact

For non-security issues, please use GitHub Issues.
For security concerns, follow the reporting process above.

---

**Last Updated**: 2025-11-25
