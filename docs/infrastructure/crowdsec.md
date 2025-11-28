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

Located in `compose/core/traefik/compose.yaml`:

```yaml
services:
  crowdsec:
    image: ghcr.io/crowdsecurity/crowdsec:v1.7.3
    container_name: crowdsec
    environment:
      BOUNCER_KEY_TRAEFIK: ${TRAEFIK_CROWDSEC_BOUNCER}
      COLLECTIONS: |
        crowdsecurity/appsec-generic-rules
        crowdsecurity/appsec-virtual-patching
        crowdsecurity/traefik
        Dominic-Wagner/vaultwarden
        LePresidente/authelia
        openappsec/openappsec
      CROWDSEC_CTI_API_KEY: ${CROWDSEC_CTI_API_KEY}
      DOCKER_HOST: "tcp://cetusguard:2375"
      TELEGRAM_BOT_ID: ${TELEGRAM_BOT_ID}
      TELEGRAM_CHAT_ID: ${TELEGRAM_CHAT_ID}
    networks:
      - vnet-traefik
      - vnet-socket
    volumes:
      - ./crowdsec/config.yaml:/etc/crowdsec/config.yaml.local:ro
      - ./crowdsec/profiles.yaml:/etc/crowdsec/profiles.yaml.local:ro
      - ./crowdsec/telegram.yaml:/etc/crowdsec/notifications/telegram.yaml:ro
      - ./crowdsec/ip-whitelist.yaml:/etc/crowdsec/parsers/s02-enrich/ip-whitelist.yaml:ro
      - ./crowdsec/acquis.d:/etc/crowdsec/acquis.d:ro
      - ${DATA_DIR}/traefik/crowdsec/data:/var/lib/crowdsec/data
      - ${DATA_DIR}/traefik/crowdsec/etc:/etc/crowdsec
```

!!! info "Key Configuration Features"
    - **Docker Label Parsing**: Uses `use_container_labels: true` to read logs directly from containers
    - **AppSec WAF**: Includes Application Security (AppSec) with virtual patching
    - **CTI Integration**: CrowdSec Cyber Threat Intelligence API for enhanced threat detection
    - **Cetusguard Proxy**: Accesses Docker API via secure proxy
    - **Telegram Notifications**: Real-time alerts with CTI scores
    - **Custom Profiles**: Background noise score-based ban duration

### Data Sources

**Docker Container Logs** (`acquis.d/docker.yaml`):
```yaml
source: docker
use_container_labels: true  # Reads logs from containers with crowdsec.enable label
check_interval: 10s
```

Containers are monitored when labeled:
```yaml
labels:
  crowdsec.enable: true
  crowdsec.labels.type: traefik
```

**AppSec WAF** (`acquis.d/appsec.yaml`):
```yaml
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/virtual-patching
name: appsecComponent
source: appsec
```

### Traefik Bouncer

Configured via Traefik middleware in `compose/core/traefik/rules/crowdsec.yml`:

```yaml
http:
  middlewares:
    crowdsec:
      plugin:
        crowdsec-bouncer:
          enabled: true
          crowdseclapihost: 'crowdsec:8080'
          crowdsecappsechost: 'crowdsec:7422'  # AppSec WAF
          crowdseclapikey: '{{ env "BOUNCER_KEY_TRAEFIK" }}'
          rediscacheenabled: true
          rediscachehost: 'traefik-redict:6379'
          clienttrustedips:
            - "10.0.0.0/8"
            - "172.16.0.0/12"
            - "192.168.0.0/16"
          forwardedheaderstrustedips:
            - "10.0.1.1"  # HAProxy upstream
```

!!! important "Redis Cache"
    The bouncer uses Redis (Redict) for caching decisions, significantly improving performance by reducing API calls to CrowdSec.

Applied to all services via middleware chain:

```yaml
labels:
  - traefik.http.routers.myservice.middlewares=chain-authelia@file
```

The `chain-authelia` middleware includes CrowdSec protection automatically.

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

### Pre-installed Collections

These collections are automatically installed via environment variables:

- `crowdsecurity/appsec-generic-rules` - Generic AppSec WAF rules
- `crowdsecurity/appsec-virtual-patching` - Virtual patching for known vulnerabilities
- `crowdsecurity/traefik` - Traefik-specific attack patterns
- `Dominic-Wagner/vaultwarden` - Vaultwarden protection
- `LePresidente/authelia` - Authelia SSO protection
- `openappsec/openappsec` - OpenAppSec integration

### Additional Recommended Collections

- `crowdsecurity/http-cve` - HTTP CVE exploits
- `crowdsecurity/base-http-scenarios` - Common HTTP attacks
- `crowdsecurity/whitelist-good-actors` - Whitelist known good bots
- `crowdsecurity/wordpress` - WordPress protection (if applicable)

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

In `compose/core/traefik/crowdsec/ip-whitelist.yaml`:

```yaml
name: my/whitelists
description: "Custom whitelist"
whitelist:
  reason: "custom whitelist"
  cidr:
    - "192.168.0.0/16"  # Private networks
    - "172.16.0.0/12"
    - "10.0.0.0/8"
```

!!! warning "RFC 1918 Private Networks"
    By default, all RFC 1918 private networks are whitelisted. Add your public IPs if needed:
    ```yaml
    - "203.0.113.0/24"  # Your public IP range
    ```

## Cyber Threat Intelligence (CTI)

### CTI API Integration

CrowdSec integrates with the CTI API for enhanced threat detection (`config.yaml`):

```yaml
api:
  cti:
    key: ${CROWDSEC_CTI_API_KEY}
    cache_timeout: 60m
    cache_size: 50
    enabled: true
    log_level: trace
```

CTI provides:
- **Background Noise Score**: Measures how often an IP attacks globally
- **False Positive Detection**: Identifies legitimate services misidentified as threats
- **Threat Classifications**: Categorizes attack types
- **Attack History**: Global attack statistics per IP

### Custom Profiles with CTI

Ban duration based on CTI background noise score (`profiles.yaml`):

```yaml
name: bn_score
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
  - CrowdsecCTI(Alert.GetValue()).GetBackgroundNoiseScore() > 0
  - !CrowdsecCTI(Alert.GetValue()).IsFalsePositive()
decisions:
  - type: ban
    duration: 12h
duration_expr: "Sprintf('%dm', (240 + (120 * CrowdsecCTI(Alert.GetValue()).GetBackgroundNoiseScore())))"
# Formula: 4 hours + 2 hours per background noise score point
# Max score: 10 = up to 24 hours ban
notifications:
  - telegram
```

**Default IP remediation** (fallback):
```yaml
name: default_ip_remediation
decisions:
  - type: ban
    duration: 12h
duration_expr: "Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 12)"
# Progressive bans: 12h, 24h, 36h, etc.
notifications:
  - telegram
```

## Notifications

### Telegram Alerts

Real-time notifications configured in `telegram.yaml`:

```yaml
type: http
name: telegram
url: https://api.telegram.org/bot${TELEGRAM_BOT_ID}/sendMessage
```

**Alert format includes**:
- Banned IP address
- Action type and duration
- Triggering scenario
- CTI scores (overall, last day, week, month)
- Threat classifications
- Links to Shodan and CrowdSec CTI

**Setup**:
1. Create Telegram bot via [@BotFather](https://t.me/botfather)
2. Get bot token (TELEGRAM_BOT_ID)
3. Get chat ID (TELEGRAM_CHAT_ID)
4. Add to Infisical secrets
5. Restart CrowdSec

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

## Application Security (AppSec) WAF

### AppSec Component

CrowdSec includes a Web Application Firewall (WAF) with virtual patching:

**Configuration** (`acquis.d/appsec.yaml`):
```yaml
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/virtual-patching
name: appsecComponent
source: appsec
```

**Integration with Traefik**:
```yaml
crowdsecappsechost: 'crowdsec:7422'
crowdsecappsecenabled: true
```

### Virtual Patching

AppSec provides protection against:
- **SQL Injection** - Database query manipulation
- **XSS (Cross-Site Scripting)** - JavaScript injection
- **Path Traversal** - Directory traversal attacks
- **Command Injection** - OS command execution
- **SSRF (Server-Side Request Forgery)** - Internal service access
- **Known CVEs** - Exploits for known vulnerabilities

Virtual patches are applied automatically without code changes, protecting against:
- Log4Shell
- Spring4Shell
- ProxyShell
- And many more...

### AppSec Metrics

```bash
# View AppSec metrics
docker exec crowdsec cscli metrics show appsec

# View blocked AppSec attacks
docker exec crowdsec cscli decisions list --origin cscli
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

# Check acquisition sources
docker exec crowdsec cscli metrics show acquisition
```

**Verify Docker API access via Cetusguard**:
```bash
# Check CrowdSec can reach Docker API
docker exec crowdsec wget -O- http://cetusguard:2375/containers/json | jq

# Verify containers are labeled correctly
docker inspect traefik | jq '.[0].Config.Labels' | grep crowdsec
```

**Check container labels**:
Containers must have these labels to be monitored:
```yaml
labels:
  crowdsec.enable: true
  crowdsec.labels.type: traefik  # or other service type
```

**Test scenarios**:
```bash
# Trigger test alert (path traversal)
curl https://yourdomain.com/../../etc/passwd

# Test AppSec WAF (SQL injection)
curl "https://yourdomain.com/?id=1' OR '1'='1"
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

1. **Keep collections updated** - Run `cscli collections upgrade --all` regularly (Renovate handles Docker image updates)
2. **Monitor Telegram alerts** - Real-time notifications keep you informed
3. **Whitelist trusted IPs** - Add your public IPs to `ip-whitelist.yaml`
4. **Review CTI scores** - High background noise scores = serious threats
5. **Test blocking** - Verify decisions are enforced via Traefik bouncer
6. **Monitor AppSec** - Check WAF metrics for blocked attacks
7. **Check Redis cache** - Ensure bouncer cache is working for performance
8. **Enroll in CAPI** - Benefit from global community intelligence
9. **Review profiles** - Adjust ban durations based on your threat model
10. **Backup configuration** - CrowdSec config and data are in `${DATA_DIR}/traefik/crowdsec`

### Required Secrets in Infisical

- `TRAEFIK_CROWDSEC_BOUNCER` - Bouncer API key
- `CROWDSEC_CTI_API_KEY` - CTI API key (from console.crowdsec.net)
- `TELEGRAM_BOT_ID` - Telegram bot token
- `TELEGRAM_CHAT_ID` - Telegram chat ID for notifications

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
