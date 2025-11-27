# CrowdSec

CrowdSec is the intrusion prevention system (IPS) that protects Omakase from attacks.

## Overview

CrowdSec provides:
- **Real-time threat detection** - Analyzes logs for attack patterns
- **Automatic blocking** - Bans malicious IPs
- **Community intelligence** - Shares and receives threat intel
- **Bouncer integration** - Enforces decisions in Traefik
- **Multi-service protection** - Protects all web services

## Architecture

### Components

**CrowdSec Agent**:
- Analyzes logs from services
- Detects attack patterns
- Makes blocking decisions
- Shares threat intelligence

**CrowdSec Bouncer**:
- Traefik plugin
- Queries CrowdSec decisions
- Blocks malicious requests
- Integrated via Traefik middleware

## Configuration

### CrowdSec Agent

Located in `compose/crowdsec/compose.yaml`:

```yaml
services:
  crowdsec:
    image: crowdsecurity/crowdsec:latest
    environment:
      COLLECTIONS: crowdsecurity/traefik crowdsecurity/http-cve
      GID: "${GID-1000}"
    volumes:
      - ./config:/etc/crowdsec
      - crowdsec_data:/var/lib/crowdsec/data
      - traefik_logs:/var/log/traefik:ro
```

### Traefik Bouncer

Configured via Traefik middleware:

```yaml
http:
  middlewares:
    crowdsec:
      plugin:
        bouncer:
          enabled: true
          crowdseclapikey: ${CROWDSEC_BOUNCER_API_KEY}
          crowdseclapiurl: http://crowdsec:8080
```

Applied to all services via middleware chain:

```yaml
labels:
  - traefik.http.routers.myservice.middlewares=chain-authelia@file
```

## Collections

### Install Collections

Collections define attack scenarios to detect:

```bash
# List available collections
docker exec crowdsec cscli collections list

# Install collection
docker exec crowdsec cscli collections install crowdsecurity/traefik
docker exec crowdsec cscli collections install crowdsecurity/http-cve
docker exec crowdsec cscli collections install crowdsecurity/whitelist-good-actors

# Update collections
docker exec crowdsec cscli collections upgrade --all
```

### Recommended Collections

- `crowdsecurity/traefik` - Traefik-specific attacks
- `crowdsecurity/http-cve` - HTTP CVE exploits
- `crowdsecurity/base-http-scenarios` - Common HTTP attacks
- `crowdsecurity/whitelist-good-actors` - Whitelist known good bots

## Decisions Management

### View Decisions

List active blocks:

```bash
# All decisions
docker exec crowdsec cscli decisions list

# Filter by IP
docker exec crowdsec cscli decisions list --ip 1.2.3.4

# Filter by type
docker exec crowdsec cscli decisions list --type ban
```

### Add Decision

Manually block an IP:

```bash
# Ban for 24 hours
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 24h --reason "Manual ban"

# Ban forever
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 0 --reason "Permanent ban"

# Ban range
docker exec crowdsec cscli decisions add --range 1.2.3.0/24 --duration 24h
```

### Remove Decision

Unblock an IP:

```bash
# Remove specific decision
docker exec crowdsec cscli decisions delete --ip 1.2.3.4

# Remove all decisions for IP
docker exec crowdsec cscli decisions delete --ip 1.2.3.4 --all

# Remove expired decisions
docker exec crowdsec cscli decisions delete --expired
```

## Alerts

### View Alerts

Alerts show detected attack attempts:

```bash
# List recent alerts
docker exec crowdsec cscli alerts list

# Show alert details
docker exec crowdsec cscli alerts inspect <alert-id>

# Filter by scenario
docker exec crowdsec cscli alerts list --scenario crowdsecurity/http-probing
```

### Alert Statistics

```bash
# View alert stats
docker exec crowdsec cscli alerts stats

# By scenario
docker exec crowdsec cscli alerts stats --scenario
```

## Whitelists

### Whitelist IPs

Prevent blocking trusted IPs:

```bash
# Add to whitelist
docker exec crowdsec cscli decisions add --ip 192.168.1.100 --type whitelist

# Whitelist range
docker exec crowdsec cscli decisions add --range 192.168.1.0/24 --type whitelist
```

### Whitelist Configuration

In `compose/crowdsec/config/parsers/s02-enrich/whitelist.yaml`:

```yaml
name: crowdsecurity/whitelists
description: "Whitelist trusted IPs"
whitelist:
  reason: "Trusted network"
  ip:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
  cidr:
    - "192.168.0.0/16"
```

## Hub Management

### Browse Hub

CrowdSec Hub contains collections, scenarios, and parsers:

```bash
# List all hub items
docker exec crowdsec cscli hub list

# Search hub
docker exec crowdsec cscli hub search wordpress

# Update hub
docker exec crowdsec cscli hub update
```

### Install Scenarios

```bash
# Install specific scenario
docker exec crowdsec cscli scenarios install crowdsecurity/http-bad-user-agent

# List installed scenarios
docker exec crowdsec cscli scenarios list

# Upgrade scenarios
docker exec crowdsec cscli scenarios upgrade --all
```

### Install Parsers

```bash
# Install parser
docker exec crowdsec cscli parsers install crowdsecurity/nginx-logs

# List parsers
docker exec crowdsec cscli parsers list
```

## Monitoring

### Metrics

View CrowdSec metrics:

```bash
# Overall metrics
docker exec crowdsec cscli metrics

# Parser metrics
docker exec crowdsec cscli metrics show parsers

# Scenario metrics
docker exec crowdsec cscli metrics show scenarios

# Local API metrics
docker exec crowdsec cscli metrics show lapi
```

### Dashboard

Access web dashboard (if configured):

```bash
# Set up Metabase dashboard
docker exec crowdsec cscli dashboard setup
```

### Logs

```bash
# View CrowdSec logs
docker compose logs -f crowdsec

# Check specific log level
docker compose logs crowdsec | grep ERROR
```

## Central API

### Enroll Instance

Share and receive threat intelligence:

```bash
# Enroll with CrowdSec Central API
docker exec crowdsec cscli capi register

# View enrollment status
docker exec crowdsec cscli capi status
```

### Threat Intelligence

Once enrolled, your instance:
- Shares attack signals anonymously
- Receives global threat intelligence
- Benefits from community protection

## Bouncer Management

### List Bouncers

```bash
# List registered bouncers
docker exec crowdsec cscli bouncers list
```

### Add Bouncer

```bash
# Create bouncer API key
docker exec crowdsec cscli bouncers add traefik-bouncer

# Returns API key - add to Infisical as CROWDSEC_BOUNCER_API_KEY
```

### Remove Bouncer

```bash
docker exec crowdsec cscli bouncers delete traefik-bouncer
```

## Troubleshooting

### Bouncer Not Blocking

**Check bouncer connection**:
```bash
docker compose logs traefik | grep crowdsec
```

**Verify API key**:
```bash
docker exec crowdsec cscli bouncers list
```

**Test decision enforcement**:
```bash
# Add test ban
docker exec crowdsec cscli decisions add --ip YOUR_IP --duration 5m

# Try accessing site - should be blocked
curl https://yourdomain.com

# Remove ban
docker exec crowdsec cscli decisions delete --ip YOUR_IP
```

### No Alerts Detected

**Check log parsing**:
```bash
# View parsed logs
docker exec crowdsec cscli metrics show parsers
```

**Verify log access**:
```bash
# Check Traefik logs are readable
docker exec crowdsec ls -la /var/log/traefik
docker exec crowdsec cat /var/log/traefik/access.log | head
```

**Test scenarios**:
```bash
# Trigger test alert
curl https://yourdomain.com/../../etc/passwd
```

### Legitimate User Blocked

**Check why blocked**:
```bash
docker exec crowdsec cscli alerts list --ip USER_IP
```

**Remove block**:
```bash
docker exec crowdsec cscli decisions delete --ip USER_IP
```

**Whitelist if trusted**:
```bash
docker exec crowdsec cscli decisions add --ip USER_IP --type whitelist
```

### Performance Issues

**Check metrics**:
```bash
docker exec crowdsec cscli metrics
```

**Reduce log verbosity** if high CPU usage.

**Adjust scenario thresholds** if too sensitive.

## Custom Scenarios

### Create Custom Scenario

In `compose/crowdsec/config/scenarios/custom-scenario.yaml`:

```yaml
type: leaky
name: myorg/custom-attack
description: "Detect custom attack pattern"
filter: "evt.Meta.log_type == 'http_access-log'"
leakspeed: 10s
capacity: 5
groupby: evt.Meta.source_ip
blackhole: 1m
labels:
  service: web
  type: custom_attack
  remediation: true
```

Reload CrowdSec:
```bash
docker compose restart crowdsec
```

## Security Best Practices

1. **Keep collections updated** - Run `cscli collections upgrade --all` regularly
2. **Monitor alerts** - Review alerts weekly
3. **Whitelist trusted IPs** - Prevent blocking your own access
4. **Enroll in CAPI** - Benefit from community intelligence
5. **Test blocking** - Verify decisions are enforced
6. **Review false positives** - Adjust scenarios if needed
7. **Backup configuration** - Include CrowdSec config in backups

## Performance Tuning

### Reduce Memory Usage

```yaml
environment:
  CSCLI_MEMORY_LIMIT: 256M
```

### Optimize Parsers

Disable unused parsers:
```bash
docker exec crowdsec cscli parsers remove unused-parser
```

### Adjust Capacities

Fine-tune scenario capacities in custom scenarios to reduce false positives.

## Integration Examples

### Fail2ban Migration

Migrate from Fail2ban:
- Install equivalent collections
- Adjust thresholds to match Fail2ban rules
- Remove Fail2ban configuration

### Nginx Logs

Parse Nginx logs:
```bash
docker exec crowdsec cscli parsers install crowdsecurity/nginx-logs
```

Mount Nginx log directory to CrowdSec.

### WordPress Protection

```bash
docker exec crowdsec cscli collections install crowdsecurity/wordpress
```

## See Also

- [Traefik](traefik.md) - Reverse proxy integration
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [Monitoring](../operations/monitoring.md) - Monitoring setup
