# Proxmox LXC Container Deployment

This guide describes deploying Omakase in a Debian LXC container on Proxmox VE, based on a real production setup.

## Architecture Overview

```
Internet
   ↓
OPNsense Firewall
   ├─ HAProxy (Reverse Proxy)
   ├─ Let's Encrypt (SSL Certificates)
   └─ VPN (Optional: Wireguard/OpenVPN)
   ↓
Proxmox VE Host
   ├─ LXC: Infisical (Secrets Management)
   └─ LXC: Omakase (Docker Stack)
          ├─ Traefik (Internal Routing)
          └─ 25+ Services
```

## Advantages of This Setup

- **Isolation**: LXC containers with minimal overhead vs full VMs
- **Security**: Firewall handles SSL and external access, Omakase isolated internally
- **Scalability**: Resources dynamically allocated by Proxmox
- **Backup**: LXC snapshots + Restic for application data
- **Performance**: Near bare-metal, efficient kernel sharing

## Hardware Requirements

### Production Configuration (Tested)

- **CPU**: 8+ cores allocated to LXC
- **RAM**: 16GB+ allocated to LXC
- **Storage**: 500GB+ for Omakase LXC
  - System: 50GB
  - Docker volumes: 450GB+
- **Network**: 1Gbps NIC

### Minimum Configuration (Basic Homelab)

- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 200GB
  - System: 30GB
  - Docker volumes: 170GB

### Proxmox Host Requirements

- Proxmox VE 8.0+
- Storage backend: LVM, ZFS, or Ceph
- Network: Configured bridge (vmbr0)

## Software Prerequisites

### On Proxmox Host

```bash
# Check Proxmox version
pveversion

# Expected output: pve-manager/8.x.x
```

### Firewall/Router (OPNsense or alternative)

- **OPNsense** 24.x+ (recommended) or:
  - pfSense
  - Linux firewall (iptables/nftables)
- **HAProxy** or nginx for external reverse proxy
- **Certbot** or ACME client for Let's Encrypt

### Separate LXC for Infisical (Recommended)

- Debian 12 LXC container
- 2 CPU / 2GB RAM / 20GB storage
- Docker + Docker Compose

## Step 1: Create LXC Container on Proxmox

### 1.1 Download Debian Template

```bash
# On Proxmox host, download Debian 12 template
pveam update
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

### 1.2 Create Omakase Container

Via **Proxmox Web UI** (recommended):

1. **Datacenter → Create CT**
2. **General**:
   - **Node**: Select Proxmox node
   - **CT ID**: 100 (or free ID)
   - **Hostname**: `omakase`
   - **Password**: Set root password
   - **SSH public key**: (Optional) Add your SSH key
   - **Unprivileged container**: ✓ (recommended for security)

3. **Template**:
   - **Storage**: local
   - **Template**: debian-12-standard

4. **Disks**:
   - **Storage**: Select storage backend (local-lvm, ZFS, etc.)
   - **Disk size**: 500 GB (or according to needs)

5. **CPU**:
   - **Cores**: 8 (or 4 for minimum setup)

6. **Memory**:
   - **Memory**: 16384 MB (16GB)
   - **Swap**: 4096 MB

7. **Network**:
   - **Bridge**: vmbr0
   - **IPv4**: Static
   - **IPv4/CIDR**: `192.168.1.100/24` (adapt to your network)
   - **Gateway**: `192.168.1.1` (your router/firewall)
   - **IPv6**: SLAAC (or disable if not using IPv6)

8. **DNS**:
   - **DNS domain**: `home.arpa` (or your local domain)
   - **DNS servers**: `192.168.1.1` (your DNS resolver)

9. **Confirm** → **Finish**

### 1.3 Configure LXC Features

After creation, configure features needed for Docker:

```bash
# On Proxmox host
pct set 100 -features nesting=1,keyctl=1
pct set 100 -unprivileged 1

# Enable FUSE for some containers (e.g. rclone)
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/100.conf
echo "lxc.cgroup2.devices.allow: c 10:229 rwm" >> /etc/pve/lxc/100.conf
echo "lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file 0 0" >> /etc/pve/lxc/100.conf
```

### 1.4 Start Container

```bash
# Start container
pct start 100

# Open console
pct enter 100
```

## Step 2: Configure Omakase Container

### 2.1 System Update

```bash
# Inside LXC container
apt update && apt upgrade -y
apt install -y curl git vim wget ca-certificates gnupg sudo
```

### 2.2 Docker Installation

```bash
# Add Docker repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
docker --version
docker compose version

# Expected output:
# Docker version 28.x.x
# Docker Compose version v2.x.x
```

### 2.3 Install Infisical CLI

```bash
# Install Infisical CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | bash
apt update
apt install -y infisical

# Verify installation
infisical --version

# Expected output: infisical version 0.42.x
```

### 2.4 User Configuration

```bash
# Create dedicated user (optional but recommended)
useradd -m -s /bin/bash -G docker omakase
passwd omakase

# Add SSH key (if configured)
sudo -u omakase mkdir -p /home/omakase/.ssh
sudo -u omakase chmod 700 /home/omakase/.ssh
# Copy your public key to /home/omakase/.ssh/authorized_keys
```

## Step 3: Self-Hosted Infisical Setup

### 3.1 Create Infisical LXC

Follow the same steps as Step 1 to create a second LXC with:

- **CT ID**: 101
- **Hostname**: `infisical`
- **CPU**: 2 cores
- **RAM**: 2048 MB
- **Storage**: 20 GB
- **IP**: `192.168.1.101/24`

Install Docker the same way (Step 2.2).

### 3.2 Deploy Infisical

```bash
# In Infisical container (CT 101)
mkdir -p /opt/infisical
cd /opt/infisical

# Download Infisical docker-compose.yml
curl -o docker-compose.yml https://raw.githubusercontent.com/Infisical/infisical/main/docker-compose.prod.yml

# Generate encryption keys
cat > .env <<EOF
# Infisical Configuration
ENCRYPTION_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
MONGO_URL=mongodb://mongo:27017/infisical

# Frontend URL (adapt to your domain)
SITE_URL=https://infisical.home.arpa
EOF

# Start Infisical
docker compose up -d

# Verify status
docker compose ps
```

### 3.3 Initial Infisical Configuration

1. Open browser at `http://192.168.1.101` (or configured domain)
2. Complete setup wizard:
   - Create admin account
   - Create organization
   - Create project "omakase"
3. Generate **Machine Identity** for Omakase:
   - Settings → Machine Identities → Create
   - Save `INFISICAL_CLIENT_ID` and `INFISICAL_CLIENT_SECRET`

## Step 4: Clone and Configure Omakase

### 4.1 Clone Repository

```bash
# In Omakase container (CT 100), as omakase user
su - omakase
cd ~
git clone https://github.com/esoso/omakase.git
cd omakase
```

### 4.2 Configure Base Variables

```bash
# Create .env file for Infisical auth
cat > .env <<EOF
# Infisical Configuration
INFISICAL_DOMAIN=http://192.168.1.101  # Infisical LXC URL
INFISICAL_PROJECT_ID=<your-project-id>
INFISICAL_CLIENT_ID=<machine-identity-client-id>
INFISICAL_CLIENT_SECRET=<machine-identity-client-secret>
EOF

# DO NOT commit .env
echo ".env" >> .gitignore
```

### 4.3 Configure Secrets in Infisical

Access Infisical Web UI and add secrets to the "omakase" project:

**Base Secrets (Environment: dev):**

```bash
# Data paths
DATA_DIR=/home/omakase/omakase/data
COMPOSE_PROJECT_NAME=omakase

# Domains
DOMAINNAME=home.arpa
TRAEFIK_DOMAIN=traefik.home.arpa

# Network
TRAEFIK_TRUSTED_IPS=192.168.0.0/16,172.16.0.0/12

# User/Group
PUID=1000
PGID=1000
TZ=Europe/Rome

# Database passwords
POSTGRES_PASSWORD=<generate-secure-password>
AUTHELIA_DB_PASSWORD=<generate-secure-password>

# Authelia secrets
AUTHELIA_JWT_SECRET=<generate-with-openssl-rand-hex-32>
AUTHELIA_SESSION_SECRET=<generate-with-openssl-rand-hex-32>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generate-with-openssl-rand-hex-32>

# Traefik
TRAEFIK_API_USER=admin
TRAEFIK_API_PASSWORD=<generate-secure-password>

# Backup (Restic + Backblaze B2)
RESTIC_PASSWORD=<generate-secure-password>
B2_ACCOUNT_ID=<backblaze-key-id>
B2_ACCOUNT_KEY=<backblaze-application-key>
RESTIC_REPOSITORY=b2:<bucket-name>:omakase

# Telegram notifications (optional)
TELEGRAM_BOT_TOKEN=<bot-token>
TELEGRAM_CHAT_ID=<chat-id>
```

**Generate Secure Passwords:**

```bash
# In Omakase container
make pwgen  # Generate secure password
# or
openssl rand -base64 32
```

### 4.4 Prepare Directories

```bash
# Create directory for persistent data
mkdir -p ~/omakase/data

# Verify permissions
ls -la ~/omakase/
```

## Step 5: Configure OPNsense HAProxy

### 5.1 Install HAProxy on OPNsense

1. **System → Firmware → Plugins**
2. Search and install: `os-haproxy`
3. **Services → HAProxy → Settings**
4. Enable HAProxy

### 5.2 Configure Backend (Omakase/Traefik)

**Services → HAProxy → Settings → Real Servers:**

- **Name**: `omakase_traefik`
- **FQDN/IP**: `192.168.1.100`
- **Port**: `80`
- **SSL**: No (Traefik handles SSL internally)
- **Verify SSL**: No
- **Health Check**: HTTP

### 5.3 Configure HTTPS Frontend

**Services → HAProxy → Settings → Virtual Services → Public Services:**

- **Name**: `https_frontend`
- **Listen Addresses**: `WAN address:443`
- **Type**: `HTTP / HTTPS (SSL offloading)`
- **Default Backend**: `omakase_traefik`
- **SSL Offloading**: Yes
- **Certificates**: Select Let's Encrypt certificate (see next step)
- **Add ACL**: Optional (for hostname-based routing)

### 5.4 Configure Let's Encrypt on OPNsense

**System → Firmware → Plugins** → Install `os-acme-client`

**Services → ACME Client → Settings:**

1. **Create Account**:
   - Name: `letsencrypt_prod`
   - ACME CA: `Let's Encrypt (Production v2)`
   - Email: `your-email@example.com`

2. **Create Challenge**:
   - Name: `http01_challenge`
   - Challenge Type: `HTTP-01`
   - HTTP Service: `HAProxy`

3. **Create Certificate**:
   - **Common Name**: `*.yourdomain.com`
   - **Account**: `letsencrypt_prod`
   - **Challenge**: `http01_challenge`
   - **Auto Renewal**: Yes (80 days)
   - **Domains**: Add all necessary subdomains

4. **Issue Certificate** → Wait for completion

5. **Bind Certificate to HAProxy**:
   - Return to HAProxy → Virtual Services
   - Select newly created certificate

### 5.5 Port Forwarding (If Needed)

**Firewall → NAT → Port Forward:**

- **Interface**: WAN
- **Protocol**: TCP
- **Destination port**: 443
- **Redirect target IP**: 192.168.1.1 (OPNsense LAN IP)
- **Redirect target port**: 443
- **Description**: HTTPS to HAProxy

## Step 6: First Omakase Deployment

### 6.1 Configuration Validation

```bash
# In Omakase container
cd ~/omakase

# Test Infisical connection
infisical export --env=dev

# Validate compose with secrets
make config

# Verify no errors and secrets are injected
```

### 6.2 Deploy Stack

```bash
# Deploy dev environment
make up

# Monitor logs
docker compose logs -f

# Verify all services are running
docker compose ps
```

### 6.3 Verify Traefik Dashboard

```bash
# Get Traefik IP
docker compose exec traefik ip addr show eth0

# Open browser at http://192.168.1.100:8080
# (or https://traefik.home.arpa if configured via HAProxy)
```

## Step 7: Configure Authelia

### 7.1 Configure Users

```bash
# Generate password hash for Authelia
docker compose exec authelia authelia crypto hash generate argon2 --password 'your-password'

# Add user in Infisical:
# AUTHELIA_USERS_<USERNAME>_PASSWORD=<generated-hash>
```

### 7.2 Test SSO

1. Access a protected service (e.g. https://portainer.yourdomain.com)
2. You'll be redirected to Authelia
3. Login with configured credentials
4. Configure 2FA (optional but recommended)

## Step 8: Configure Restic Backups

### 8.1 Initialize Backblaze Repository

```bash
# Verify Restic variables are in Infisical
make config | grep RESTIC

# Initialize repository (first time only)
docker compose run --rm backup restic init

# Output: created restic repository xyz at b2:...
```

### 8.2 Test Manual Backup

```bash
# Run first backup
docker compose run --rm backup /app/scripts/backup.sh

# Verify backup
docker compose run --rm backup restic snapshots
```

### 8.3 Automated Backups

Backups are already configured in `compose/backup/compose.yaml`:

- **Daily backup**: 3:30 AM
- **Check**: 5:15 AM
- **Prune**: 4:00 AM

Verify with:

```bash
docker compose logs backup
```

## Step 9: Monitoring and Maintenance

### 9.1 Access Dashboards

- **Homepage**: https://home.yourdomain.com
- **Traefik**: https://traefik.yourdomain.com
- **Portainer**: https://portainer.yourdomain.com
- **Dozzle (logs)**: https://dozzle.yourdomain.com

### 9.2 Useful Commands

```bash
# View all services status
make ps

# View logs per service
docker compose logs -f <service-name>

# Restart service
docker compose restart <service-name>

# Update images
make pull

# Restart stack
make restart

# Stop stack
make down
```

### 9.3 Monitor LXC Resources

```bash
# On Proxmox host
pct status 100        # Container status
pct exec 100 -- df -h # Disk usage
pct exec 100 -- free -h # Memory usage
pct exec 100 -- docker stats # Docker stats
```

## Troubleshooting

### Container Won't Start

```bash
# Check Proxmox logs
journalctl -u pve-container@100

# Verify LXC features
cat /etc/pve/lxc/100.conf | grep -E "features|nesting"

# Ensure nesting=1
```

### Docker Not Working in LXC

```bash
# Verify apparmor isn't blocking Docker
aa-status

# If needed, disable apparmor for this container
# (already done in Step 1.3)
```

### Traefik Not Reachable from HAProxy

```bash
# Verify Traefik listens on 0.0.0.0:80
docker compose exec traefik netstat -tlnp | grep :80

# Verify container firewall (should be permissive)
iptables -L

# Test from OPNsense
# Diagnostics → Ping: 192.168.1.100
# Diagnostics → Port Probe: 192.168.1.100:80
```

### Secrets Not Loading

```bash
# Verify Infisical connection
infisical export --env=dev

# Verify .env variables
cat .env

# Test Infisical LXC connection
curl http://192.168.1.101/api/status
```

## Backup and Disaster Recovery

### Complete LXC Backup (Proxmox)

```bash
# Create LXC snapshot
vzdump 100 --mode snapshot --storage local

# Scheduled backup (cron on Proxmox host)
# Datacenter → Backup → Add
```

### Restore from Backup

```bash
# Restore container from backup
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst

# Restore Restic data
docker compose run --rm backup restic restore latest --target /restore
```

## Best Practices

1. **Regular snapshots**: Configure automatic LXC backups on Proxmox
2. **Monitoring**: Use Uptime Kuma or Grafana for uptime monitoring
3. **Updates**: Run `apt update && apt upgrade` monthly in LXC
4. **Logs**: Monitor Dozzle for anomalous errors
5. **Secret rotation**: Rotate critical secrets every 90 days
6. **Firewall rules**: Maintain minimal OPNsense firewall rules (least privilege)
7. **2FA**: Enable 2FA on Authelia for all users
8. **Backup testing**: Test restore from backup quarterly

## Useful Resources

- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [OPNsense HAProxy Plugin](https://docs.opnsense.org/manual/how-tos/haproxy.html)
- [Docker in LXC](https://pve.proxmox.com/wiki/Linux_Container#pct_container_storage)
- [Infisical Self-Hosted](https://infisical.com/docs/self-hosting/overview)

## Next Steps

- [Add new services](../services/index.md)
- [Configure advanced monitoring](../operations/monitoring.md)
- [Set up VPN for remote access](../infrastructure/vpn.md)
- [Performance optimization](../operations/performance.md)
