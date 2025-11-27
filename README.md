<div align="center">
  <img src="docs/assets/images/omakase-banner.png" alt="Omakase Homelab Banner" width="100%">

  # Omakase

  [![Documentation](https://github.com/esoso/omakase/actions/workflows/docs.yml/badge.svg)](https://github.com/esoso/omakase/actions/workflows/docs.yml)
  [![Deploy](https://github.com/esoso/omakase/actions/workflows/deploy.yml/badge.svg)](https://github.com/esoso/omakase/actions/workflows/deploy.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

  **Production-ready Docker homelab infrastructure with security-first architecture**

  [📚 Documentation](https://esoso.github.io/Omakase/) · [🚀 Quick Start](#quick-start) · [💬 Discussions](https://github.com/esoso/omakase/discussions)
</div>

---

## What is Omakase?

Omakase is a comprehensive Infrastructure-as-Code solution for self-hosting 25+ services in a secure, automated, and maintainable way. Born from a production homelab setup, it has been generalized to support different deployment scenarios while maintaining core security and operational principles.

**Key Technologies**: Docker Compose, Traefik (reverse proxy), Authelia (SSO), CrowdSec (IPS), Infisical (secrets)

## Why Omakase?

### 🔒 Security-First Design
- **Multi-layer security**: SSO authentication, intrusion prevention, network isolation
- **Zero secrets in git**: External secret management with Infisical
- **Container hardening**: Mandatory security options, resource limits, non-root execution
- **Automated threat detection**: CrowdSec collaborative security

### 🤖 Fully Automated
- **Automated deployments**: CI/CD pipeline with GitHub Actions
- **Dependency updates**: Renovate bot manages Docker image updates
- **Automated backups**: Daily encrypted backups to cloud storage
- **Self-documenting**: Comprehensive documentation built and deployed automatically

### 🏗️ Production-Ready
- **Battle-tested architecture**: Running in production for years
- **Modular design**: Each service isolated with dedicated compose file
- **Flexible deployment**: Bare metal, VMs, LXC, cloud - your choice
- **Comprehensive monitoring**: Centralized logging, metrics, and dashboards

### 📦 25+ Services Included

**Infrastructure**: Traefik, Authelia, CrowdSec, Portainer, Homepage, Dozzle
**Media**: Jellyfin, Sonarr, Radarr, Bazarr, Deluge
**Productivity**: Nextcloud, Paperless-NGX, Vaultwarden, NocoDB
**Photos**: Immich
**Development**: Windmill, Local-AI
**And many more...**

## Architecture Principles

### Fixed (Non-Negotiable)
- ✅ Security-first architecture
- ✅ External secret management
- ✅ Network isolation per service
- ✅ Infrastructure-as-Code approach
- ✅ Automated encrypted backups

### Flexible (Adapt to Your Setup)
- 🔄 SSL termination (Traefik direct, HAProxy upstream, Cloudflare, etc.)
- 🔄 Platform (Proxmox LXC, bare metal, VMs, NAS, cloud)
- 🔄 Storage backend (ZFS, local filesystem, NFS, cloud)
- 🔄 Secret management deployment (self-hosted, cloud, alternatives)
- 🔄 Environment strategy (single, multi-host, profiles)

**[Learn more about architectural flexibility →](https://esoso.github.io/Omakase/deployment/)**

## Quick Start

### Prerequisites
- Docker Engine 24.0+ and Docker Compose v2.20+
- Linux host (Debian/Ubuntu recommended)
- Infisical for secret management

### Basic Installation

```bash
# 1. Clone repository
git clone https://github.com/esoso/omakase.git
cd omakase

# 2. Configure secrets in Infisical
# See documentation for complete setup guide

# 3. Deploy
make up
```

**⚠️ Important**: This is a simplified quick start. For production deployment, please follow the [complete installation guide](https://esoso.github.io/Omakase/getting-started/installation/).

## Deployment Scenarios

Omakase supports various deployment options:

| Scenario | Best For | Complexity | Cost |
|----------|----------|------------|------|
| [**Proxmox LXC**](https://esoso.github.io/Omakase/deployment/proxmox-lxc/) ⭐ | Advanced homelab | Medium | Hardware only |
| [**Bare Metal**](https://esoso.github.io/Omakase/deployment/bare-metal/) | Dedicated hardware | Low | Hardware only |
| [**Virtual Machine**](https://esoso.github.io/Omakase/deployment/vm-generic/) | Testing & dev | Low | Hardware/cloud |
| [**NAS**](https://esoso.github.io/Omakase/deployment/nas/) | Existing NAS | Low | Hardware only |
| [**Cloud VPS**](https://esoso.github.io/Omakase/deployment/cloud-vps/) | Remote access | Low | €20-50/month |

**[View all deployment options →](https://esoso.github.io/Omakase/deployment/)**

## Reference Architecture

The project is based on a production setup with:
- **OPNSense** firewall with HAProxy for SSL termination
- **Proxmox VE** hypervisor with multiple LXC containers
- Separate environments: Production, Development, Infisical, CI/CD
- **ZFS** storage with bind mounts for production data
- **Automated backups** to Backblaze B2

This architecture is **not mandatory** - adapt to your infrastructure while maintaining security principles.

## Documentation

**📚 [Complete Documentation](https://esoso.github.io/Omakase/)**

### Essential Guides
- [Prerequisites](https://esoso.github.io/Omakase/getting-started/prerequisites/) - What you need before starting
- [Installation](https://esoso.github.io/Omakase/getting-started/installation/) - Step-by-step setup guide
- [Configuration](https://esoso.github.io/Omakase/getting-started/configuration/) - Configure services and secrets
- [Deployment Scenarios](https://esoso.github.io/Omakase/deployment/) - Choose your deployment platform
- [Operations](https://esoso.github.io/Omakase/operations/backup/) - Backup, monitoring, maintenance

### Core Infrastructure
- [Traefik](https://esoso.github.io/Omakase/infrastructure/traefik/) - Reverse proxy and routing
- [Authelia](https://esoso.github.io/Omakase/infrastructure/authelia/) - SSO authentication
- [CrowdSec](https://esoso.github.io/Omakase/infrastructure/crowdsec/) - Intrusion prevention
- [Cetusguard](https://esoso.github.io/Omakase/infrastructure/cetusguard/) - Docker socket proxy

## Useful Commands

```bash
make up          # Deploy stack (dev environment)
make down        # Stop all services
make restart     # Restart services
make pull        # Update Docker images
make config      # Show configuration with secrets
make network     # Show network allocations
make clean       # Clean unused resources
make pwgen       # Generate secure passwords
```

**[See all available commands →](https://esoso.github.io/Omakase/getting-started/installation/#makefile-commands)**

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`feat/new-service`, `fix/issue-123`)
3. Follow [conventional commits](https://www.conventionalcommits.org/)
4. Submit a pull request

**[Read contribution guidelines →](https://esoso.github.io/Omakase/contributing/)**

## Community & Support

- 💬 [GitHub Discussions](https://github.com/esoso/omakase/discussions) - Ask questions, share ideas
- 🐛 [Issue Tracker](https://github.com/esoso/omakase/issues) - Report bugs, request features
- 📖 [Documentation](https://esoso.github.io/Omakase/) - Comprehensive guides and reference
- 📝 [Changelog](CHANGELOG.md) - Version history and updates

## Project Status

**Current Version**: 2.4.198+ (auto-versioned)

Omakase is actively maintained and running in production. The project follows semantic versioning and uses automated dependency updates through Renovate.

## Acknowledgments

Special thanks to the [r/selfhosted](https://reddit.com/r/selfhosted) community for inspiration and support.

## License

This project is open source and available under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  Made with ❤️ for the self-hosting community
</div>
