# Deployment Scenarios

Omakase can be deployed in various environments, from your home network to cloud infrastructure. This section guides you through the most common deployment patterns.

## Architectural Flexibility

Omakase was born from a production homelab setup and has been generalized to support different architectural choices while maintaining core security and operational principles.

### Fixed Principles (Non-Negotiable)

These principles are fundamental to Omakase and cannot be compromised:

- **Security-First Architecture**: No secrets in git, mandatory network isolation, `no-new-privileges` on all containers
- **External Secret Management**: Secrets must be stored in an external vault (Infisical recommended)
- **Network Isolation**: Each service requires its own isolated network (`vnet-<service>`)
- **Infrastructure-as-Code**: All configuration declarative, versioned, and reproducible
- **Backup Strategy**: Data protection with automated, encrypted backups

### Flexible Architectural Aspects

While core principles remain fixed, Omakase adapts to different infrastructure patterns:

#### SSL Termination Options
- **External Proxy** (reference setup): HAProxy/nginx upstream handles SSL, Traefik receives HTTP
- **Direct Traefik**: Traefik manages Let's Encrypt certificates directly
- **Cloudflare Tunnel**: Zero-trust access without exposed ports
- **Custom**: Caddy, Nginx Proxy Manager, or other reverse proxies

#### Platform Choices
- **Proxmox LXC** (reference setup): Lightweight containerization with minimal overhead
- **Bare Metal**: Direct installation on physical hardware
- **Virtual Machines**: VMware, VirtualBox, KVM, or cloud VMs
- **NAS Devices**: Synology, QNAP with Docker support
- **Cloud VPS**: DigitalOcean, Hetzner, AWS, GCP, Azure

#### Storage Backends
- **ZFS with bind mounts** (reference setup): Enterprise-grade with snapshots and compression
- **Local filesystem**: Direct storage on ext4/xfs
- **Network storage**: NFS, CIFS, iSCSI shares
- **Cloud storage**: Block storage from cloud providers

#### Secret Management Deployment
- **Dedicated host** (reference setup): Infisical on separate LXC/VM
- **Infisical Cloud**: SaaS offering (free tier available)
- **Co-located**: Infisical containerized within the same stack
- **Alternatives**: HashiCorp Vault, Doppler, 1Password
- **Development only**: `.env` files (not for production)

#### Multi-Environment Patterns
- **Separated environments** (reference setup): Dedicated PROD and DEV stacks on separate hosts/domains
- **Single environment**: Production-only deployment
- **Docker Compose profiles**: Environment switching via profiles
- **Branch-based**: Different branches for different environments

### Documentation Scope

This documentation provides:
- ✅ **Reference architecture** based on the production setup (Proxmox + HAProxy + multi-LXC)
- ✅ **Alternative deployment guides** for common scenarios
- ✅ **Configuration patterns** that adapt to different architectures
- ❌ **Detailed implementation** for every possible combination (out of scope)

The compose file structure (`compose.yaml`, `compose.prod.yaml`, `compose.dev.yaml`) already supports flexible deployment patterns through Docker Compose's multi-file composition.

## Choose Your Deployment Scenario

### 🏠 Homelab Deployments

<table>
<tr>
<td width="50%">

**[Proxmox with LXC Containers](proxmox-lxc.md)** ⭐ Recommended

Production-tested setup with Debian LXC containers on Proxmox VE.

**Advantages:**
- Minimal overhead vs full VMs
- Integrated snapshots and backups
- Dynamic resource allocation
- Secure isolation

**Requirements:**
- Proxmox VE 8.0+
- 8+ CPU cores, 16GB+ RAM
- 500GB+ storage

</td>
<td width="50%">

**[Bare Metal Server](bare-metal.md)**

Direct installation on dedicated physical hardware.

**Advantages:**
- Maximum performance
- Total hardware control
- No virtualization layer

**Requirements:**
- Dedicated physical server
- Linux (Debian/Ubuntu)
- 8+ CPU cores, 16GB+ RAM

</td>
</tr>
<tr>
<td>

**[Generic Virtual Machine](vm-generic.md)**

Deployment on VM platforms (VMware, VirtualBox, KVM).

**Advantages:**
- Portability between hypervisors
- Easy snapshots and cloning
- Complete isolation

**Requirements:**
- Any hypervisor
- Linux VM
- 8GB+ RAM, 200GB+ storage

</td>
<td>

**[NAS Devices (Synology/QNAP)](nas.md)**

Run on NAS hardware with Docker support.

**Advantages:**
- Use existing hardware
- Integrated storage
- Built-in NAS backups

**Requirements:**
- Synology DSM 7.0+ or QNAP
- Container Station/Docker
- 8GB+ RAM

</td>
</tr>
</table>

### ☁️ Cloud Deployments

<table>
<tr>
<td width="50%">

**[Cloud VPS](cloud-vps.md)**

Deploy on cloud providers (DigitalOcean, Hetzner, Vultr).

**Advantages:**
- Accessible from anywhere
- Dedicated public IP
- On-demand scalability

**Requirements:**
- Linux VPS (Debian/Ubuntu)
- 4+ CPU, 8GB+ RAM
- 200GB+ storage

**Recommended Providers:**
- Hetzner Cloud (CPX41: €20/month)
- DigitalOcean (8GB: $48/month)
- Vultr (High Frequency: $48/month)

</td>
<td width="50%">

**[AWS/GCP/Azure](cloud-enterprise.md)**

Enterprise cloud setup with managed services.

**Advantages:**
- Guaranteed SLAs
- Integrated managed services
- Auto-scaling capabilities

**Requirements:**
- Cloud provider account
- IaC knowledge (Terraform)
- Enterprise budget

**Estimated Costs:**
- AWS: $80-150/month
- GCP: $70-130/month
- Azure: $75-140/month

</td>
</tr>
</table>

## Architecture Comparison

| Scenario | Setup Cost | Monthly Cost | Complexity | Performance | Uptime | Best For |
|----------|------------|--------------|------------|-------------|--------|----------|
| **Proxmox LXC** | €500-1500 | €10-30 (power) | Medium | Excellent | 99%+ | Advanced homelab |
| **Bare Metal** | €300-1000 | €10-30 (power) | Low | Excellent | 99%+ | Basic homelab |
| **Generic VM** | €0* | €0-30 | Low | Good | 95%+ | Testing & development |
| **NAS** | €300-800 | €5-15 (power) | Low | Good | 99%+ | Homelab with existing NAS |
| **Cloud VPS** | €0 | €20-50 | Low | Good | 99.9%+ | Remote access priority |
| **Cloud Enterprise** | €0 | €80-150+ | High | Excellent | 99.99%+ | Business production |

\* If hardware already available

## Common Components Across All Scenarios

Regardless of your chosen scenario, you'll need:

### 1. Operating System

- **Recommended**: Debian 12 (Bookworm)
- **Supported alternatives**: Ubuntu 22.04/24.04 LTS

### 2. Container Runtime

- Docker Engine 24.0+
- Docker Compose v2.20+

### 3. Secret Management

Options (in order of recommendation):
- ✅ **Infisical Self-Hosted** (recommended for homelab)
- ✅ **Infisical Cloud** (free for personal use)
- ⚠️ **Alternative vaults**: HashiCorp Vault, Doppler, 1Password
- ⚠️ **`.env` files** (development only, not for production)

### 4. Reverse Proxy & SSL

Options:
- ✅ **Traefik** (included in Omakase)
- ✅ **Traefik + External HAProxy/nginx** (reference Proxmox setup)
- ✅ **Nginx Proxy Manager** (user-friendly alternative)
- ⚠️ **Cloudflare Tunnel** (may limit some services)

### 5. Backup Storage

- **Local**: NAS, external hard drives
- **Cloud**: Backblaze B2 (recommended), AWS S3, Wasabi
- **Hybrid**: Local backup + cloud replication

## Quick Start by Scenario

### Homelab (Proxmox/Bare Metal)

```bash
# 1. Set up self-hosted Infisical (see specific guide)
# 2. Clone Omakase
git clone https://github.com/esoso/omakase.git
cd omakase

# 3. Configure secrets in Infisical
# 4. Deploy
make up
```

**Estimated time**: 2-4 hours

### Cloud VPS

```bash
# 1. Provision VPS
# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Clone and deploy
git clone https://github.com/esoso/omakase.git
cd omakase
# Configure Infisical Cloud
make up
```

**Estimated time**: 1-2 hours

## Decision Guide

### Choose Proxmox LXC if:
- ✅ You have a homelab server with Proxmox
- ✅ You want to manage multiple isolated projects/services
- ✅ You need integrated backups and snapshots
- ✅ You're familiar with Proxmox

### Choose Bare Metal if:
- ✅ You have dedicated hardware for Omakase only
- ✅ You want maximum performance
- ✅ You don't need virtualization
- ✅ You prefer simple, direct setup

### Choose Cloud VPS if:
- ✅ You don't have homelab hardware
- ✅ You want access from anywhere without VPN
- ✅ You prefer to outsource hardware management
- ✅ Budget: €20-50/month

### Choose NAS if:
- ✅ You already have a Synology/QNAP NAS with Docker
- ✅ You want to consolidate on existing hardware
- ✅ Storage is your primary concern

## Resource Requirements

### Minimum Configuration (15-20 services)

- **CPU**: 4 cores
- **RAM**: 8 GB
- **Storage**: 200 GB
- **Network**: 100 Mbps

**Services to exclude** for reduced resources:
- Media stack (Jellyfin, *arr apps)
- Development tools
- Game servers

### Recommended Configuration (25-30 services)

- **CPU**: 8+ cores
- **RAM**: 16 GB
- **Storage**: 500 GB
- **Network**: 1 Gbps

Includes complete stack as per `compose.prod.yaml`.

### Enterprise Configuration (30+ services + HA)

- **CPU**: 16+ cores
- **RAM**: 32 GB+
- **Storage**: 1 TB+ (SSD)
- **Network**: 10 Gbps

For HA setups, Proxmox clusters, Kubernetes, etc.

## Reference Architecture (Production Setup)

The reference architecture this project is based on:

```
Internet
   ↓
[OPNSense Firewall]
   ├─ HAProxy (SSL termination, Let's Encrypt)
   └─ SNI-based routing
   ↓
[Proxmox Hypervisor]
   ├─ Internal network (192.168.x.0/24)
   │
   ├─ [LXC: Production] *.example.com
   │  ├─ Traefik (HTTP routing)
   │  ├─ Full Omakase stack (compose.yaml + compose.prod.yaml)
   │  ├─ Storage: ZFS bind mounts
   │  └─ Restic backups → Backblaze B2
   │
   ├─ [LXC: Development] *.dev.example.com
   │  ├─ Traefik (HTTP routing)
   │  ├─ Dev stack (compose.yaml + compose.dev.yaml)
   │  └─ Storage: virtual disk
   │
   ├─ [LXC: Infisical]
   │  └─ Secret management (internal network access)
   │
   └─ [LXC: CI/CD]
      ├─ Renovate (dependency updates)
      └─ GitHub Actions runner (self-hosted)
```

**Key characteristics**:
- **SSL termination**: Centralized in OPNSense HAProxy
- **Multi-environment**: Separate PROD and DEV stacks
- **Network isolation**: Each LXC isolated, internal network for Proxmox
- **Storage strategy**: ZFS for prod (snapshots, compression), virtual disk for dev
- **Backup strategy**: Automated Restic to cloud (prod only)

This architecture is battle-tested but **not mandatory**. Adapt to your infrastructure while maintaining security principles.

## Next Steps

1. **Choose your scenario** from the guides above
2. **Read prerequisites** in the [Getting Started](../getting-started/prerequisites.md) section
3. **Follow installation guide** specific to your environment
4. **Configure services** you need

## Support

Questions about choosing a deployment scenario? Open a [GitHub Discussion](https://github.com/esoso/omakase/discussions) describing:
- Your current hardware/setup
- Services you want to run
- Available budget
- Your priorities (performance, cost, simplicity)

The community will help you choose the best solution!
