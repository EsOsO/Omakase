# Bare Metal Deployment

Deploy Omakase directly on physical hardware for maximum performance and control.

## Overview

**Bare metal deployment** involves installing Omakase directly on physical hardware without virtualization.

**Advantages**:
- Maximum performance (no hypervisor overhead)
- Direct hardware access
- Simpler architecture
- Lower resource requirements

**Disadvantages**:
- Less flexible
- Harder to backup/restore
- Single point of failure
- Resource dedicated to homelab

## Hardware Requirements

### Minimum

- **CPU**: 4 cores (x86_64)
- **RAM**: 8GB
- **Storage**: 250GB SSD
- **Network**: Gigabit Ethernet

### Recommended

- **CPU**: 8+ cores with AES-NI
- **RAM**: 16GB+
- **Storage**: 500GB+ NVMe SSD
- **Network**: Gigabit or 10GbE
- **UPS**: Battery backup for power protection

### Storage Layout

Separate OS and data storage:

```
/dev/sda (256GB SSD): OS and Docker
  /dev/sda1: /boot (1GB)
  /dev/sda2: / (50GB)
  /dev/sda3: swap (16GB)
  /dev/sda4: /var/lib/docker (remaining)

/dev/sdb (1TB+ HDD/SSD): Data
  /dev/sdb1: /mnt/storage (entire disk)
    → ${DATA_DIR}
```

## Operating System

### Recommended: Ubuntu Server 24.04 LTS

**Why**:
- Long-term support (5 years)
- Well-documented
- Strong Docker support
- Large community

### Installation

1. **Download**: Ubuntu Server 24.04 LTS
2. **Create bootable USB**: Using Rufus, balenaEtcher, or `dd`
3. **Boot from USB**
4. **Install**:
   - Minimal server installation
   - Enable SSH server
   - Configure static IP
   - Set up user account

### Alternative OS Options

- **Debian 12**: More stable, older packages
- **Rocky Linux 9**: RHEL-based, enterprise focus
- **Arch Linux**: Rolling release, latest packages

## Initial Setup

### 1. Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 2. Install Prerequisites

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Docker Compose
sudo apt install docker-compose-plugin

# Infisical CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install -y infisical

# Useful tools
sudo apt install -y htop iotop git make pwgen
```

Log out and back in for docker group to take effect.

### 3. Configure Storage

Mount data partition:

```bash
# Create mount point
sudo mkdir -p /mnt/storage

# Get UUID
sudo blkid /dev/sdb1

# Add to /etc/fstab
echo "UUID=<uuid> /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Mount
sudo mount -a

# Set permissions
sudo chown -R $USER:$USER /mnt/storage
```

### 4. Configure Network

Static IP configuration (`/etc/netplan/00-installer-config.yaml`):

```yaml
network:
  version: 2
  ethernets:
    ens18:  # Your interface name
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

Apply:
```bash
sudo netplan apply
```

### 5. Configure Firewall

```bash
# Install UFW
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable
sudo ufw enable
```

## Deploy Omakase

### 1. Clone Repository

```bash
cd ~
git clone https://github.com/yourusername/omakase.git
cd omakase
```

### 2. Configure Environment

```bash
# Set up Infisical
export INFISICAL_DOMAIN="your-infisical-domain"
export INFISICAL_PROJECT_ID="your-project-id"
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"

# Or login interactively
infisical login
```

### 3. Configure Data Directory

Create `.env` or add to Infisical:
```bash
DATA_DIR=/mnt/storage/omakase
DOMAINNAME=yourdomain.com
PUID=1000
PGID=1000
TZ=Europe/Rome
```

### 4. Initialize Data Directories

```bash
make config  # Verify configuration
make up      # Deploy services
```

### 5. Verify Deployment

```bash
docker compose ps
docker compose logs
```

## Performance Optimization

### Docker Storage Driver

Use overlay2 with `/etc/docker/daemon.json`:

```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

### System Tuning

Optimize kernel parameters (`/etc/sysctl.conf`):

```ini
# Network optimization
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 10000 65535

# Container optimization
vm.swappiness = 10
vm.overcommit_memory = 1

# File handles
fs.file-max = 100000
fs.inotify.max_user_watches = 524288
```

Apply:
```bash
sudo sysctl -p
```

### Disk Optimization

Mount options for SSD:
```
UUID=xxx /mnt/storage ext4 defaults,noatime,discard 0 2
```

Enable TRIM:
```bash
sudo systemctl enable fstrim.timer
sudo systemctl start fstrim.timer
```

## High Availability

### RAID Configuration

For data redundancy:

**RAID 1** (mirroring):
```bash
# Create RAID 1 array
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Format
sudo mkfs.ext4 /dev/md0

# Mount
sudo mount /dev/md0 /mnt/storage
```

**RAID 10** (high performance + redundancy):
Requires 4+ disks.

### UPS Configuration

Install NUT (Network UPS Tools):

```bash
sudo apt install nut

# Configure UPS in /etc/nut/ups.conf
# Configure shutdown in /etc/nut/upsd.conf
```

### Monitoring

Install node exporter for monitoring:

```yaml
# Add to compose.yaml
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
```

## Backup Strategy

### System Backup

**OS configuration**:
```bash
# Backup critical configs
tar czf system-backup.tar.gz \
  /etc/fstab \
  /etc/netplan/ \
  /etc/docker/ \
  ~/.ssh/
```

**Omakase configuration**:
```bash
cd ~/omakase
tar czf omakase-config.tar.gz compose*
```

### Data Backup

Omakase's built-in Restic backup handles data automatically.

### Full System Image

Create disk image:
```bash
# Using Clonezilla or dd
sudo dd if=/dev/sda of=/mnt/backup/system.img bs=4M status=progress
```

## Disaster Recovery

### System Failure

1. Boot from installation USB
2. Restore OS from image or reinstall
3. Restore configuration from backup
4. Mount data disk
5. Restore Omakase stack
6. Restore data from Restic backup if needed

### Disk Failure

With RAID:
```bash
# Replace failed disk
sudo mdadm --manage /dev/md0 --add /dev/sdX

# Monitor rebuild
watch cat /proc/mdstat
```

Without RAID:
1. Replace disk
2. Format and mount
3. Restore from Restic backup

## Maintenance

### Regular Tasks

**Daily**:
```bash
# Check service status
docker compose ps

# Monitor resources
htop
```

**Weekly**:
```bash
# Update images
make pull
make restart

# Check disk health
sudo smartctl -a /dev/sda
```

**Monthly**:
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clean Docker
make clean

# Check RAID (if applicable)
cat /proc/mdstat
```

## Security Hardening

### SSH Security

Edit `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers yourusername
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

### Automatic Updates

```bash
# Install unattended-upgrades
sudo apt install unattended-upgrades

# Configure
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Fail2ban

```bash
sudo apt install fail2ban

# Configure for SSH
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Troubleshooting

### Service Won't Start

Check Docker status:
```bash
sudo systemctl status docker
sudo journalctl -u docker -n 50
```

### Disk Full

Find large files:
```bash
sudo du -sh /* | sort -h
docker system df
```

Clean up:
```bash
make clean
docker system prune -a
```

### Network Issues

Check configuration:
```bash
ip addr show
ip route show
ping 8.8.8.8
```

### Performance Issues

Check resources:
```bash
htop
iotop
docker stats
```

## Scaling

### Adding More Services

Omakase's modular design allows easy service addition. See [Adding Services](../contributing/adding-services.md).

### Hardware Upgrades

**Easy upgrades**:
- Add RAM (shut down, install, boot)
- Add storage (mount, update DATA_DIR)
- Network upgrade (replace card)

**Complex upgrades**:
- CPU/Motherboard (requires OS reinstall or careful migration)

## See Also

- [Installation Guide](../getting-started/installation.md)
- [VM Deployment](vm-generic.md)
- [Proxmox LXC](proxmox-lxc.md)
- [Performance Tuning](../operations/performance.md)
