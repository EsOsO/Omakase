# Secrets Management with Infisical

Omakase uses [Infisical](https://infisical.com/) as the central secrets management solution. All sensitive data (passwords, API keys, tokens) are stored in Infisical vault and injected at runtime.

!!! warning "Security First"
    **NEVER commit secrets to git.** All secrets must be stored in Infisical or another secure vault.

## Why Infisical?

- **Centralized**: Single source of truth for all secrets
- **Encrypted**: End-to-end encryption at rest and in transit
- **Access Control**: Role-based permissions and audit logs
- **Versioning**: Track secret changes over time
- **Multi-Environment**: Separate dev, staging, prod secrets
- **Developer Friendly**: CLI integration with Docker Compose

## Deployment Options

### Option A: Infisical Cloud (Easiest)

Best for: Quick start, no additional infrastructure

**Pros**:
- No setup required
- Always available
- Automatic backups
- Free tier for personal use

**Cons**:
- External dependency
- Secrets stored outside your network (encrypted)
- Requires internet connection

**Setup**:

1. Sign up at [Infisical Cloud](https://app.infisical.com/)
2. Create organization
3. Create project "omakase"
4. Create environments: `dev`, `prod`
5. Generate Machine Identity (for CLI auth)

### Option B: Infisical Self-Hosted (Recommended) {#infisical-self-hosted}

Best for: Homelab, complete control, air-gapped

**Pros**:
- Full control and privacy
- No external dependencies
- Free and open source
- Can run alongside Omakase

**Cons**:
- Requires additional infrastructure
- Manual backup responsibility

**Setup Guide Below** ⬇️

## Self-Hosted Infisical Setup

### Prerequisites

- Separate server/VM/LXC container
- 2 CPU cores
- 2 GB RAM
- 20 GB storage
- Docker + Docker Compose

### Step 1: Prepare Infrastructure

#### On Proxmox (Recommended Setup)

```bash
# Create LXC container on Proxmox host
pct create 101 \
  local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname infisical \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --storage local-lvm \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.101/24,gw=192.168.1.1

# Enable Docker support
pct set 101 -features nesting=1,keyctl=1

# Start container
pct start 101
pct enter 101
```

#### On Bare Metal / VM

```bash
# Just use your existing Linux system
# Ensure Docker is installed (see Prerequisites)
```

### Step 2: Install Docker

```bash
# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify
docker --version
docker compose version
```

### Step 3: Deploy Infisical

```bash
# Create directory
mkdir -p /opt/infisical
cd /opt/infisical

# Download production docker-compose
curl -o docker-compose.yml https://raw.githubusercontent.com/Infisical/infisical/main/docker-compose.prod.yml

# Generate encryption keys
cat > .env <<EOF
# Infisical Core Configuration
ENCRYPTION_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)

# MongoDB Connection
MONGO_URL=mongodb://mongo:27017/infisical

# Frontend Configuration
SITE_URL=https://infisical.yourdomain.com  # Change to your domain
NEXT_PUBLIC_INFISICAL_URL=https://infisical.yourdomain.com

# Mail Configuration (Optional, for invites/notifications)
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_FROM=noreply@yourdomain.com
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password
EOF

# Secure .env file
chmod 600 .env

# Start Infisical
docker compose up -d

# Check status
docker compose ps
docker compose logs -f infisical
```

### Step 4: Initial Configuration

1. **Access Infisical**: Open browser to `https://infisical.yourdomain.com` (or `http://192.168.1.101:80` for local)

2. **Complete Setup Wizard**:
   - Create admin account
   - Set up organization
   - Create first project

3. **Create Project for Omakase**:
   - Name: `omakase`
   - Environments: `dev`, `prod`

4. **Generate Machine Identity** (for Omakase CLI):
   - Project Settings → Machine Identities → Create
   - Name: `omakase-deployment`
   - Permissions: Read/Write on all environments
   - Save `Client ID` and `Client Secret`

### Step 5: Configure SSL (Production)

#### Option A: Let's Encrypt via Traefik

Add labels to Infisical frontend container in `docker-compose.yml`:

```yaml
services:
  infisical:
    labels:
      - traefik.enable=true
      - traefik.http.routers.infisical.rule=Host(`infisical.yourdomain.com`)
      - traefik.http.routers.infisical.entrypoints=websecure
      - traefik.http.routers.infisical.tls.certresolver=letsencrypt
      - traefik.http.services.infisical.loadbalancer.server.port=8080
```

#### Option B: Reverse Proxy (HAProxy, Nginx)

Configure your external reverse proxy to forward to `http://192.168.1.101:80`.

See [Proxmox LXC deployment guide](../deployment/proxmox-lxc.md#step-5-configuration-haproxy) for HAProxy example.

## Omakase Integration

### Step 1: Install Infisical CLI

On your Omakase host:

```bash
# Install Infisical CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo bash
sudo apt update
sudo apt install -y infisical

# Verify installation
infisical --version
```

### Step 2: Configure Omakase .env

In your Omakase project directory:

```bash
cd ~/omakase

# Create .env file (NEVER commit this!)
cat > .env <<EOF
# Infisical Configuration
INFISICAL_DOMAIN=https://infisical.yourdomain.com  # or http://192.168.1.101
INFISICAL_PROJECT_ID=<project-id-from-settings>
INFISICAL_CLIENT_ID=<machine-identity-client-id>
INFISICAL_CLIENT_SECRET=<machine-identity-client-secret>
EOF

# Secure .env
chmod 600 .env

# Add to .gitignore
echo ".env" >> .gitignore
```

### Step 3: Populate Secrets in Infisical

Access Infisical Web UI and add secrets to the `omakase` project:

#### Required Base Secrets (Environment: `dev`)

```bash
# Path Configuration
DATA_DIR=/home/omakase/omakase/data
COMPOSE_PROJECT_NAME=omakase

# Domain Configuration
DOMAINNAME=yourdomain.com
TRAEFIK_DOMAIN=traefik.yourdomain.com

# Network Configuration
TRAEFIK_TRUSTED_IPS=192.168.0.0/16,172.16.0.0/12

# User/Group (match your host user)
PUID=1000
PGID=1000
TZ=Europe/Rome  # Your timezone

# PostgreSQL
POSTGRES_PASSWORD=<generate-secure-password>

# Authelia Database
AUTHELIA_DB_PASSWORD=<generate-secure-password>

# Authelia Secrets (generate with: openssl rand -hex 32)
AUTHELIA_JWT_SECRET=<hex-32>
AUTHELIA_SESSION_SECRET=<hex-32>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<hex-32>

# Traefik Dashboard
TRAEFIK_API_USER=admin
TRAEFIK_API_PASSWORD=<generate-secure-password>

# Backup (Restic + Backblaze B2)
RESTIC_PASSWORD=<generate-secure-password>
B2_ACCOUNT_ID=<backblaze-key-id>
B2_ACCOUNT_KEY=<backblaze-app-key>
RESTIC_REPOSITORY=b2:<bucket-name>:omakase

# Notifications (Optional)
TELEGRAM_BOT_TOKEN=<telegram-bot-token>
TELEGRAM_CHAT_ID=<telegram-chat-id>
```

#### Generate Secure Passwords

```bash
# Random password
openssl rand -base64 32

# Hex secret (for JWT, encryption keys)
openssl rand -hex 32

# Using Makefile
make pwgen
```

#### Service-Specific Secrets

As you enable more services, add their secrets following the naming pattern:

```
<SERVICE>_<COMPONENT>_<PURPOSE>
```

Examples:
```bash
NEXTCLOUD_DB_PASSWORD=<password>
NEXTCLOUD_ADMIN_PASSWORD=<password>
JELLYFIN_API_KEY=<key>
SONARR_API_KEY=<key>
```

### Step 4: Test Integration

```bash
cd ~/omakase

# Test Infisical connection
infisical export --env=dev

# Should output all secrets (don't run in untrusted environments!)

# Test Docker Compose with secret injection
make config

# Verify secrets are injected (look for values, not ${VAR})
make config | grep POSTGRES_PASSWORD
```

## Using Secrets in Compose Files

### Standard Environment Variable Syntax

```yaml
services:
  myservice:
    image: myimage:latest
    environment:
      # Required variable (will fail if not in Infisical)
      DB_PASSWORD: "${POSTGRES_PASSWORD:?err}"

      # Optional with default
      DB_HOST: "${DB_HOST:-postgres}"

      # Simple reference
      DB_USER: "${DB_USER}"
```

### Template Syntax (Alternative)

Some services use Go template syntax:

```yaml
services:
  myservice:
    image: myimage:latest
    environment:
      API_KEY: "{{env \"SERVICE_API_KEY\"}}"
```

### Secrets in Config Files

For services that load config from files:

```yaml
# compose/myservice/config/config.yml
database:
  password: "${MYSERVICE_DB_PASSWORD}"
```

Mount as volume:

```yaml
services:
  myservice:
    volumes:
      - ./compose/myservice/config:/config:ro
```

## Secret Rotation

### Rotating Secrets

1. **Update in Infisical**: Change the secret value in Infisical UI
2. **Restart services**: `make restart` or `docker compose restart <service>`
3. **Verify**: Check service logs for successful authentication

### Rotation Schedule (Recommended)

| Secret Type | Rotation Frequency |
|-------------|-------------------|
| Database passwords | Every 90 days |
| API keys (external services) | Every 180 days |
| JWT secrets | Every 180 days |
| Encryption keys | Yearly |
| Service-to-service tokens | Every 90 days |

### Automated Rotation (Advanced)

Use Infisical API or webhooks to automate rotation:

```bash
# Example: Rotate PostgreSQL password via API
curl -X PATCH https://infisical.yourdomain.com/api/v1/secrets/POSTGRES_PASSWORD \
  -H "Authorization: Bearer $INFISICAL_TOKEN" \
  -d '{"value": "new-password"}'

# Restart service
docker compose restart postgres
```

## Backup & Recovery

### Backup Infisical Data

Infisical stores all data in MongoDB:

```bash
# On Infisical host
cd /opt/infisical

# Backup MongoDB
docker compose exec -T mongo mongodump --archive --gzip > infisical-backup-$(date +%Y%m%d).gz

# Copy backup off-host
rsync infisical-backup-*.gz backup-server:/backups/infisical/
```

### Restore Infisical

```bash
# Stop Infisical
docker compose down

# Restore MongoDB
docker compose up -d mongo
sleep 10
docker compose exec -T mongo mongorestore --archive --gzip < infisical-backup-20250125.gz

# Start Infisical
docker compose up -d
```

### Disaster Recovery

If Infisical is completely lost:

1. **Restore from backup** (preferred)
2. **Manual secret recreation**:
   - Refer to documentation
   - Check git history for config templates
   - Regenerate secrets (invalidates old ones)

**Prevention**: Schedule regular automated backups!

## Security Best Practices

### Access Control

- **Limit Machine Identities**: Create separate identities per environment/team
- **Rotate Credentials**: Rotate Machine Identity credentials regularly
- **Audit Logs**: Review Infisical audit logs monthly
- **Least Privilege**: Grant minimum required permissions

### Network Security

- **Firewall**: Block Infisical port from public internet
- **VPN Access**: Access Infisical only via VPN if self-hosted
- **HTTPS Only**: Always use HTTPS/TLS for Infisical
- **Internal Network**: Keep Infisical on internal network segment

### Secret Hygiene

- **No Defaults**: Never use example/default passwords
- **Complexity**: Use strong, random secrets (32+ characters)
- **Unique**: Different password for each service
- **No Reuse**: Don't reuse secrets across environments
- **No Sharing**: Don't share secrets via email/chat

### .env File Security

```bash
# Secure permissions
chmod 600 .env

# Never commit
echo ".env" >> .gitignore

# Verify not in git
git status --ignored

# Store backup securely (encrypted)
gpg -c .env -o .env.gpg
```

## Troubleshooting

### Cannot connect to Infisical

```bash
# Test connectivity
curl -I https://infisical.yourdomain.com

# Check Infisical logs
docker compose logs -f infisical

# Verify credentials
cat .env | grep INFISICAL

# Test CLI auth
infisical export --env=dev
```

### Secrets not injected

```bash
# Verify .env exists
ls -la .env

# Test Infisical CLI
infisical export --env=dev

# Check make config output
make config | head -50

# Verify secret exists in Infisical UI
```

### Permission denied errors

```bash
# Check file permissions
ls -la .env

# Should be: -rw------- (600)
chmod 600 .env
```

## Next Steps

- [Configure services](../getting-started/configuration.md)
- [Security Best Practices](best-practices.md)
- [Backup Setup](../operations/backup.md)
