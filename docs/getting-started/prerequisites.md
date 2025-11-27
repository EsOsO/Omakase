# Prerequisites

Before deploying Omakase, ensure you have the required infrastructure and understand the system requirements.

## System Requirements

### Minimum Configuration (15-20 services)

| Component | Requirement |
|-----------|-------------|
| **CPU** | 4 cores |
| **RAM** | 8 GB |
| **Storage** | 200 GB |
| **Network** | 100 Mbps |
| **OS** | Linux (Debian 12 / Ubuntu 22.04+) |

### Recommended Configuration (25-30 services)

| Component | Requirement |
|-----------|-------------|
| **CPU** | 8+ cores |
| **RAM** | 16 GB |
| **Storage** | 500 GB |
| **Network** | 1 Gbps |
| **OS** | Debian 12 (Bookworm) |

### Hardware Considerations

**CPU**:
- Multi-threaded workloads (transcoding, backups, containers)
- Intel/AMD x64 architecture required
- ARM64 support experimental (some images may not be available)

**RAM**:
- Each service requires 50-500MB
- Database services (PostgreSQL) can use 1-2GB
- Media services (Jellyfin, Plex) with transcoding need 2-4GB
- Leave headroom for OS and Docker overhead

**Storage**:
- **System**: 50GB for OS + Docker images
- **Data**: 150GB+ for service persistent data
- **Media**: Additional storage if using media services (1TB+ recommended)
- **SSD recommended** for database performance

## Software Prerequisites

### Required Software

#### 1. Linux Operating System

**Supported Distributions**:

=== "Debian 12 (Recommended)"
    ```bash
    # Verify version
    cat /etc/os-release
    # Should show: VERSION="12 (bookworm)"
    ```

=== "Ubuntu 22.04/24.04 LTS"
    ```bash
    # Verify version
    lsb_release -a
    # Should show: Ubuntu 22.04 LTS or 24.04 LTS
    ```

=== "Other"
    Any modern Linux distribution with:
    - Kernel 5.10+
    - systemd
    - AppArmor or SELinux support

**Not Supported**:
- Windows (even with WSL2)
- macOS (Docker Desktop limitations)
- ARM64 (experimental, some services unavailable)

#### 2. Docker Engine

**Version**: Docker 24.0+ with Docker Compose v2.20+

**Installation**:

```bash
# Install Docker (official script)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group (optional, logout required)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version

# Expected output:
# Docker version 28.x.x
# Docker Compose version v2.39.x
```

**Alternative Installation**: See [deployment guides](../deployment/index.md) for platform-specific instructions.

#### 3. Git

```bash
# Install git
sudo apt update
sudo apt install -y git

# Verify
git --version
```

#### 4. Make (Optional but recommended)

```bash
# Install make
sudo apt install -y make

# Verify
make --version
```

### Secret Management Setup

You **must** choose ONE of these options:

#### Option A: Infisical Self-Hosted (Recommended for Homelab)

**Pros**:
- Full control over secrets
- No external dependencies
- Free and open source
- Can be deployed alongside Omakase

**Cons**:
- Requires separate setup
- Additional resources (2GB RAM, 20GB storage)

**Setup Guide**: See [Secrets Management](../security/secrets-management.md#infisical-self-hosted)

#### Option B: Infisical Cloud (Easiest)

**Pros**:
- No additional infrastructure needed
- Always available
- Automatic backups
- Free tier available

**Cons**:
- External dependency
- Secrets stored on third-party (encrypted)

**Setup**: [Sign up at Infisical Cloud](https://app.infisical.com/)

#### Option C: Environment Files (Development Only)

!!! danger "Not for Production"
    Using `.env` files is **NOT recommended** for production. Secrets will be in plain text on disk.

**Use only for**:
- Local testing
- Development environments
- Learning/evaluation

## Network Requirements

### Port Requirements

Omakase needs these ports available on your host:

| Port | Protocol | Service | Required | Publicly Exposed |
|------|----------|---------|----------|------------------|
| 80 | TCP | Traefik HTTP | Yes | Optional* |
| 443 | TCP | Traefik HTTPS | Yes | Optional* |
| 8080 | TCP | Traefik Dashboard | No | Never |

\* Expose ports 80/443 only if accessing services from outside your local network. Otherwise, use VPN or reverse proxy.

**Additional ports**: Each service may expose additional ports internally (Docker networks only).

### DNS / Domain Requirements

You need a domain name for SSL certificates and service routing. Options:

#### Production Domains

**Public Domain** (Recommended):
- Purchase from registrar (Cloudflare, Namecheap, etc.)
- Configure DNS A records pointing to your public IP
- Required for Let's Encrypt SSL certificates
- Cost: $10-15/year

**Dynamic DNS** (DDNS):
- Free subdomain (e.g., `yourname.duckdns.org`)
- Automatic IP updates
- Providers: DuckDNS, No-IP, Dynu
- Works with Let's Encrypt

#### Development/Local Only

**Local Domain** (`.local` or `.home.arpa`):
- No cost, works on LAN only
- Configure in local DNS or `/etc/hosts`
- Self-signed certificates (browser warnings)
- Not accessible from internet

**Example**:
```bash
# /etc/hosts on your workstation
192.168.1.100 traefik.home.arpa
192.168.1.100 portainer.home.arpa
192.168.1.100 authelia.home.arpa
```

### Firewall Considerations

If using a separate firewall/router (OPNsense, pfSense, etc.):

- **Internal Access Only**: No firewall rules needed
- **External Access**: Forward ports 80/443 to Omakase host
- **VPN Access**: Configure Wireguard/OpenVPN

See [deployment scenarios](../deployment/index.md) for architecture examples.

## Knowledge Prerequisites

### Required Knowledge

- **Basic Linux administration**
  - Command line navigation
  - File permissions
  - Package management (apt)

- **Docker fundamentals**
  - Container concepts
  - Docker Compose basics
  - Understanding volumes and networks

- **Git basics**
  - Clone repositories
  - Pull updates

### Recommended Knowledge

- **Networking basics**
  - IP addressing and subnets
  - Port forwarding
  - DNS concepts

- **Security awareness**
  - Password management
  - SSL/TLS certificates
  - Firewall rules

- **Backup/restore procedures**

### Optional Knowledge

- Reverse proxy configuration (Traefik/Nginx)
- YAML syntax
- Container orchestration
- Infrastructure as Code concepts

Don't worry if you don't have all the recommended knowledge - the documentation guides you through each step!

## Preparation Checklist

Before proceeding to installation, ensure:

- [ ] Linux system meets minimum requirements
- [ ] Docker Engine 24.0+ installed and running
- [ ] Docker Compose v2.20+ installed
- [ ] Git installed
- [ ] Secret management chosen (Infisical Cloud/Self-hosted)
- [ ] Domain name configured (public or local)
- [ ] Network ports 80/443 available
- [ ] Storage space allocated (200GB+ available)
- [ ] Backup storage planned (optional but recommended)

## Estimated Deployment Time

| Task | Time |
|------|------|
| **Prerequisites Setup** | 30-60 min |
| **Infisical Setup** | 30-60 min |
| **Omakase Installation** | 15-30 min |
| **Service Configuration** | 1-2 hours |
| **Testing & Verification** | 30-60 min |
| **Total** | **3-5 hours** |

*First-time deployment. Subsequent deployments: 15-30 minutes.*

## Next Steps

Once prerequisites are met:

1. [Choose your deployment scenario](../deployment/index.md)
2. [Install Omakase](installation.md)
3. [Configure services](configuration.md)

## Troubleshooting Prerequisites

### Docker won't start

```bash
# Check Docker service status
sudo systemctl status docker

# Check logs
sudo journalctl -u docker -n 50

# Restart Docker
sudo systemctl restart docker
```

### Insufficient disk space

```bash
# Check disk usage
df -h

# Clean Docker resources
docker system prune -a --volumes
```

### Port already in use

```bash
# Check what's using port 80
sudo lsof -i :80

# Kill process or reconfigure
```

For more issues, see [Troubleshooting Guide](../operations/troubleshooting.md).
