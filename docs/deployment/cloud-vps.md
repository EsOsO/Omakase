# Cloud VPS Deployment

Deploy Omakase on cloud Virtual Private Servers for remote access and scalability.

## Overview

**VPS deployment** provides cloud-hosted infrastructure with public accessibility.

**Advantages**:
- No home internet requirements
- Professional uptime/connectivity
- Easy to scale
- Global access
- No hardware maintenance

**Disadvantages**:
- Monthly costs
- Data transfer limits
- Privacy concerns
- Compliance considerations

## Provider Selection

### Recommended Providers

**Hetzner Cloud**:
- Excellent price/performance
- European data centers
- Fast networking
- Snapshot support
- From €4.51/month

**DigitalOcean**:
- Easy to use
- Good documentation
- Global locations
- From $6/month

**Linode (Akamai)**:
- Reliable performance
- Excellent support
- Good networking
- From $5/month

**Vultr**:
- Many locations
- Competitive pricing
- Good performance
- From $6/month

### Selection Criteria

Consider:
- **Price**: Fits budget
- **Performance**: Adequate CPU/RAM
- **Location**: Close to users
- **Network**: Bandwidth/transfer limits
- **Backup**: Snapshot support
- **Support**: Quality of support

## Sizing

### Small Deployment (5-10 services)

**Specifications**:
- 4 vCPU cores
- 8GB RAM
- 160GB SSD
- 4TB transfer

**Cost**: ~$24-36/month

**Providers**:
- Hetzner CPX31
- DigitalOcean Basic Droplet
- Linode 8GB

### Medium Deployment (10-20 services)

**Specifications**:
- 8 vCPU cores
- 16GB RAM
- 320GB SSD
- 8TB transfer

**Cost**: ~$48-72/month

**Providers**:
- Hetzner CPX41
- DigitalOcean CPU-Optimized
- Linode 16GB

### Large Deployment (20+ services)

**Specifications**:
- 16 vCPU cores
- 32GB RAM
- 640GB SSD
- 16TB transfer

**Cost**: ~$96-144/month

**Providers**:
- Hetzner CPX51
- DigitalOcean CPU-Optimized
- Linode 32GB

## Initial Setup

### 1. Create VPS

**Hetzner example**:
1. Sign up at https://hetzner.cloud
2. Create project
3. Add server:
   - Location: Nuremberg
   - Image: Ubuntu 24.04
   - Type: CPX31
   - Volume: Optional additional storage
4. Add SSH key
5. Create server

### 2. Initial Access

```bash
ssh root@server-ip
```

### 3. Basic Security

```bash
# Update system
apt update && apt upgrade -y

# Create user
adduser omakase
usermod -aG sudo omakase

# Configure SSH
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Set up firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Install fail2ban
apt install fail2ban -y
```

### 4. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker omakase

# Install Docker Compose
apt install docker-compose-plugin -y

# Install Infisical
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
apt-get update && apt-get install -y infisical
```

### 5. Configure Storage

```bash
# Optional: Attach block storage volume
# Format and mount
mkfs.ext4 /dev/sdb
mkdir -p /mnt/storage
echo "/dev/sdb /mnt/storage ext4 defaults,noatime 0 2" >> /etc/fstab
mount -a

# Set ownership
chown -R omakase:omakase /mnt/storage
```

## Deploy Omakase

```bash
# Switch to user
su - omakase

# Clone repository
git clone https://github.com/yourusername/omakase.git
cd omakase

# Configure environment
export DATA_DIR=/mnt/storage/omakase  # Or /home/omakase/omakase-data
export DOMAINNAME=yourdomain.com
export PUID=$(id -u)
export PGID=$(id -g)

# Configure Infisical
infisical login

# Deploy
make up
```

## DNS Configuration

### Domain Setup

Point domain to VPS:

```
A     @              server-ip
A     *              server-ip
AAAA  @              server-ipv6  # If available
AAAA  *              server-ipv6
```

Propagation takes 1-24 hours.

### Cloudflare (Recommended)

Benefits:
- DDoS protection
- CDN
- Free SSL
- Analytics

Setup:
1. Add domain to Cloudflare
2. Update nameservers at registrar
3. Add DNS records
4. Enable proxy (orange cloud)

**Caution**: Cloudflare proxy incompatible with HTTP challenge for Let's Encrypt. Use DNS challenge instead.

## SSL Certificates

### Let's Encrypt HTTP Challenge

Default configuration works if ports 80/443 accessible.

### DNS Challenge (for Cloudflare proxy)

Update Traefik configuration:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"

environment:
  CF_API_EMAIL: ${CLOUDFLARE_EMAIL}
  CF_API_KEY: ${CLOUDFLARE_API_KEY}
```

## Security Hardening

### Rate Limiting

Add Traefik middleware:

```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
```

### IP Whitelist (Optional)

Restrict admin services to your IP:

```yaml
http:
  middlewares:
    ip-whitelist:
      ipWhiteList:
        sourceRange:
          - "your-home-ip/32"
```

### CrowdSec

Ensure CrowdSec is active and enrolled in CAPI for threat intelligence.

### Backup Firewall

Use provider's cloud firewall if available:
- Only allow ports 22, 80, 443
- Restrict SSH to your IP if possible

## Monitoring

### Resource Usage

Monitor VPS resources:
```bash
htop
docker stats
df -h
```

### Network Transfer

Track bandwidth usage via provider dashboard.

### Costs

Monitor spending:
- Check provider billing
- Watch for unexpected charges
- Set billing alerts

## Backups

### VPS Snapshots

Use provider snapshots:
- **Hetzner**: Enable backup (20% additional cost)
- **DigitalOcean**: Enable automatic backups
- **Linode**: Enable backups

### Omakase Backups

Use built-in Restic backup to Backblaze B2 or similar.

### Configuration Backup

Backup Omakase configuration:
```bash
cd ~/omakase
tar czf omakase-config-$(date +%Y%m%d).tar.gz compose* .env
```

Store off-server.

## Disaster Recovery

### VPS Failure

1. Create new VPS from snapshot
2. Update DNS A records
3. Verify services

### Data Corruption

1. Restore from Restic backup
2. Restore from VPS snapshot
3. Deploy services

## Cost Optimization

### Right-Sizing

Monitor resource usage:
- Downsize if underutilized
- Upgrade if constrained

### Storage

Use object storage for backups instead of expensive block storage:
- Backblaze B2
- Wasabi
- Provider object storage

### Network Transfer

Optimize to stay within limits:
- Compress responses
- Cache content
- Limit media streaming

## Scaling

### Vertical Scaling

Upgrade VPS:
1. Shutdown services
2. Resize VPS (via provider dashboard)
3. Restart services

Usually zero downtime.

### Horizontal Scaling

Add additional VPS for specific services:
- Media server on separate VPS
- Database on dedicated instance

### Load Balancing

Use provider load balancer or Cloudflare for distribution.

## Provider-Specific Notes

### Hetzner Cloud

**Volumes**: Attach additional storage via Cloud Volumes
**Snapshots**: Manual snapshots, no automatic backups
**IPv6**: Free IPv6 address included
**Network**: Very fast (up to 20 Gbps)

### DigitalOcean

**Spaces**: Object storage for backups
**Monitoring**: Built-in metrics
**Firewall**: Cloud Firewalls available
**1-Click Apps**: Can use Docker droplet

### Linode

**Volumes**: Block storage available
**NodeBalancer**: Load balancer option
**Backups**: Automatic backup service
**Longview**: Free monitoring

## Compliance

### Data Privacy

Consider:
- GDPR (EU users)
- Data residency requirements
- Provider's privacy policy

### Data Location

Choose server location based on:
- User location
- Legal requirements
- Performance needs

## Troubleshooting

### High Network Usage

Check logs:
```bash
docker compose logs | grep -i "status": "5"
```

Identify bandwidth-heavy service.

### VPS Performance

Check:
- CPU steal time (hypervisor overhead)
- Disk I/O performance
- Network latency

Consider upgrading or changing provider.

### SSH Connection Issues

```bash
# Check from another terminal
ssh -v root@server-ip

# Check fail2ban
fail2ban-client status sshd
```

## Migration

### Between Providers

1. Deploy new VPS
2. Set up Omakase
3. Restore data from backup
4. Update DNS
5. Test thoroughly
6. Destroy old VPS

### From Home to Cloud

1. Backup home installation
2. Deploy to VPS
3. Restore backup
4. Update DNS
5. Test access

## Best Practices

1. **Enable automatic backups** - Worth the cost
2. **Use cloud firewall** - Additional security layer
3. **Monitor costs** - Set billing alerts
4. **Regular snapshots** - Before major changes
5. **Keep DNS TTL low** - Easier migration
6. **Document IP addresses** - For firewall rules
7. **Use object storage** - For large backups
8. **Monitor bandwidth** - Avoid overage charges

## See Also

- [Installation Guide](../getting-started/installation.md)
- [Security Best Practices](../security/best-practices.md)
- [Backup Configuration](../operations/backup.md)
