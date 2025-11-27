# NAS Deployment

Deploy Omakase on Network Attached Storage (NAS) devices.

## Overview

Many NAS devices support Docker, making them suitable for Omakase deployment.

**Advantages**:
- Utilize existing hardware
- Integrated storage management
- Lower power consumption
- Often includes backup features

**Disadvantages**:
- Limited CPU/RAM
- Proprietary OS customizations
- May require workarounds
- Limited community support for some platforms

## Supported NAS Platforms

### Synology DSM

**Models**: DS920+, DS1821+, DS923+, etc.

**Requirements**:
- DSM 7.0+
- Intel CPU (avoid ARM models)
- 4GB+ RAM (8GB+ recommended)
- Docker package from Package Center

### QNAP QTS

**Models**: TS-464, TVS-h674, TS-873A, etc.

**Requirements**:
- QTS 5.0+
- Intel/AMD CPU
- 4GB+ RAM
- Container Station

### TrueNAS Scale

**Best option** - Full Linux with native Docker support.

**Requirements**:
- TrueNAS Scale 22.12+
- Any compatible hardware
- 8GB+ RAM

### Unraid

**Advantages**: Excellent Docker support, flexible storage.

**Requirements**:
- Unraid 6.10+
- 8GB+ RAM
- Compatible hardware

## Synology Deployment

### Prerequisites

1. **Install Docker**:
   - Open Package Center
   - Search for "Docker"
   - Click Install

2. **Enable SSH**:
   - Control Panel → Terminal & SNMP
   - Enable SSH service

3. **Create shared folder**:
   - Control Panel → Shared Folder
   - Create "omakase" folder

### Installation

SSH into Synology:
```bash
ssh admin@nas-ip
sudo -i
```

Install Docker Compose:
```bash
# Download docker-compose
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

# Make executable
chmod +x /usr/local/bin/docker-compose

# Verify
docker-compose --version
```

Clone and deploy:
```bash
cd /volume1/omakase
git clone https://github.com/yourusername/omakase.git
cd omakase

# Configure environment
export DATA_DIR=/volume1/omakase/data
export DOMAINNAME=yourdomain.com

# Deploy
make up
```

### Synology-Specific Configuration

**Port conflicts**: Synology uses ports 80/443:

```yaml
# compose.yaml
services:
  traefik:
    ports:
      - "8080:80"
      - "8443:443"
```

Access services at `https://nas-ip:8443`

**Permissions**:
```bash
chown -R admin:users /volume1/omakase
```

## QNAP Deployment

### Prerequisites

1. **Install Container Station**:
   - App Center → Container Station
   - Install

2. **Enable SSH**:
   - Control Panel → Telnet/SSH
   - Enable SSH

### Installation

SSH into QNAP:
```bash
ssh admin@qnap-ip

# Navigate to share
cd /share/Container/omakase

# Clone repository
git clone https://github.com/yourusername/omakase.git
cd omakase

# Deploy
DATA_DIR=/share/Container/omakase/data make up
```

### QNAP Considerations

- Use `/share/Container/` for Docker data
- Container Station provides GUI management
- May need to adjust resource limits

## TrueNAS Scale Deployment

### Prerequisites

TrueNAS Scale has native Docker support via K3s.

### Installation

**Option 1: TrueNAS Apps** (Recommended):
- Use TrueCharts catalog
- Deploy services via GUI

**Option 2: Custom Docker Compose**:

```bash
# SSH into TrueNAS
ssh admin@truenas-ip

# Install docker-compose
sudo apt install docker-compose

# Deploy Omakase
cd /mnt/pool/omakase
git clone https://github.com/yourusername/omakase.git
cd omakase
make up
```

### TrueNAS Benefits

- Native ZFS support
- Built-in snapshots
- Excellent backup options
- Full Linux environment

## Unraid Deployment

### Prerequisites

1. **Enable Docker**:
   - Settings → Docker
   - Enable Docker
   - Set Docker directory

2. **Install Community Applications**:
   - Plugins → Install "Community Applications"

### Installation

**Option 1: Docker Compose Manager**:
1. Install "Docker Compose Manager" plugin
2. Create new stack
3. Paste compose.yaml
4. Deploy

**Option 2: SSH**:
```bash
ssh root@unraid-ip

cd /mnt/user/appdata/omakase
git clone https://github.com/yourusername/omakase.git
cd omakase
docker-compose up -d
```

### Unraid Benefits

- Excellent Docker integration
- Community Applications
- Flexible storage
- Active community

## Common NAS Challenges

### Limited Resources

**Optimize for NAS**:

```yaml
# Reduce resource limits
deploy:
  resources:
    limits:
      memory: 512M  # Instead of 2G
```

Disable resource-heavy services.

### Port Conflicts

NAS often uses standard ports. Options:

1. **Change NAS ports**
2. **Change Omakase ports**:
   ```yaml
   ports:
     - "8080:80"
     - "8443:443"
   ```
3. **Use reverse proxy** on different ports

### Storage Paths

Each NAS has different paths:
- Synology: `/volume1/`
- QNAP: `/share/Container/`
- TrueNAS: `/mnt/pool/`
- Unraid: `/mnt/user/appdata/`

Set `DATA_DIR` accordingly.

### Persistence After Reboot

Ensure services start automatically:

**Synology**:
Create scheduled task in Task Scheduler:
```bash
cd /volume1/omakase/omakase && /usr/local/bin/docker-compose up -d
```

**QNAP**:
Use Container Station autostart feature.

**TrueNAS/Unraid**:
Create system startup script.

## Performance Considerations

### CPU Limitations

NAS CPUs often less powerful:
- Disable CPU-intensive services (transcoding, ML)
- Use hardware transcoding if supported
- Limit concurrent services

### Memory Constraints

Monitor memory usage:
```bash
docker stats --no-stream
```

Adjust limits as needed.

### Network Performance

- Use wired connection
- Enable jumbo frames if supported
- Monitor network saturation

## NAS-Specific Features

### Leverage NAS Capabilities

**Synology**:
- Hyper Backup for VM/container backup
- Snapshot Replication
- Active Backup for Business

**QNAP**:
- QNAP NetBak Replicator
- Hybrid Backup Sync
- Snapshot feature

**TrueNAS**:
- ZFS snapshots
- Replication tasks
- Cloud sync

**Unraid**:
- CA Backup
- Appdata Backup plugin
- Parity protection

## Backup Strategy

### NAS Snapshots

Use NAS snapshot feature for quick rollback:

**Synology**:
- Snapshot Replication → Create snapshot schedule

**TrueNAS**:
- Periodic Snapshot Tasks

### Omakase Backups

Use built-in Restic backup in addition to NAS snapshots.

## Monitoring

Use NAS native monitoring:
- Resource Monitor (Synology/QNAP)
- Reporting (TrueNAS)
- Dashboard (Unraid)

Plus Omakase's monitoring stack.

## Troubleshooting

### Docker Won't Start

**Check Docker service**:
```bash
# Synology
synoservicectl --status pkgctl-Docker

# Others
systemctl status docker
```

### Permission Denied

**Fix permissions**:
```bash
# Set PUID/PGID to NAS user
export PUID=$(id -u)
export PGID=$(id -g)
```

### Out of Memory

Reduce services or add RAM to NAS.

## Upgrading NAS

### Before NAS OS Update

1. Backup Omakase data
2. Export docker-compose config
3. Note all customizations
4. Stop services

### After Update

1. Verify Docker still installed
2. Reinstall docker-compose if needed
3. Restore services
4. Test functionality

## Best Practices

1. **Use NAS strengths** - Snapshots, redundancy
2. **Monitor resources** - NAS often constrained
3. **Regular backups** - To external location
4. **Update carefully** - Test NAS updates
5. **Document customizations** - NAS-specific changes
6. **Use persistent storage** - Map to NAS shares
7. **Enable autostart** - Services survive reboots

## See Also

- [Installation Guide](../getting-started/installation.md)
- [Performance Tuning](../operations/performance.md)
- [Backup Configuration](../operations/backup.md)
