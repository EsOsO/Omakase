# VPN Access

Guide for setting up remote VPN access to your Omakase homelab.

## Overview

VPN provides:
- **Secure remote access** - Access services from anywhere
- **Encrypted tunnel** - Protect traffic over public networks
- **Network-level access** - Access all services as if on local network
- **Alternative to public exposure** - Keep services private

## VPN Options

### WireGuard (Recommended)

Modern, lightweight VPN protocol:

**Advantages**:
- Fast performance
- Simple configuration
- Built into Linux kernel
- Low overhead
- Strong cryptography

**Use cases**:
- Personal devices (phone, laptop)
- Always-on access
- Road warrior setup

### OpenVPN

Traditional VPN solution:

**Advantages**:
- Widely supported
- Works through most firewalls
- TCP/UDP modes
- Extensive features

**Use cases**:
- Legacy device support
- Complex network scenarios
- Site-to-site VPN

### Tailscale (Easiest)

Mesh VPN built on WireGuard:

**Advantages**:
- Zero configuration
- Automatic key management
- Works behind NAT
- Cross-platform apps
- Free tier available

**Use cases**:
- Quick setup
- Multiple devices
- Non-technical users

## WireGuard Setup

### Server Installation

1. **Add WireGuard to compose** (not included by default):

Create `compose/wireguard/compose.yaml`:

```yaml
services:
  wireguard:
    image: linuxserver/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
      SERVERURL: ${WIREGUARD_SERVER_URL}
      SERVERPORT: 51820
      PEERS: 5  # Number of clients
      PEERDNS: auto
      INTERNAL_SUBNET: 10.13.13.0/24
    volumes:
      - ${DATA_DIR}/wireguard/config:/config
      - /lib/modules:/lib/modules:ro
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
```

2. **Configure environment**:

Add to Infisical:
```bash
WIREGUARD_SERVER_URL=vpn.yourdomain.com
```

3. **Deploy WireGuard**:
```bash
make up
```

4. **Generate client configs**:
```bash
docker compose logs wireguard
```

QR codes and config files in `${DATA_DIR}/wireguard/config/peer*/`

### Client Configuration

**Mobile (iOS/Android)**:
1. Install WireGuard app
2. Scan QR code from logs
3. Connect

**Desktop (Linux/macOS/Windows)**:
1. Install WireGuard client
2. Import config file: `peer1/peer1.conf`
3. Activate connection

**Config file format**:
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.13.13.2/32
DNS = 10.13.13.1

[Peer]
PublicKey = <server-public-key>
Endpoint = vpn.yourdomain.com:51820
AllowedIPs = 192.168.0.0/16  # Access homelab network
PersistentKeepalive = 25
```

### Firewall Configuration

Open UDP port 51820:

```bash
# UFW
sudo ufw allow 51820/udp

# iptables
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

## Tailscale Setup (Easiest Option)

### Installation

1. **Sign up**: https://tailscale.com

2. **Install on server**:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

3. **Install on clients**: Download apps from https://tailscale.com/download

4. **Access services**: Use Tailscale IPs or MagicDNS names

### Docker Integration

Run Tailscale as sidecar:

```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    hostname: omakase
    environment:
      TS_AUTHKEY: ${TAILSCALE_AUTH_KEY}
      TS_STATE_DIR: /var/lib/tailscale
    volumes:
      - ${DATA_DIR}/tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    restart: unless-stopped
```

### Advantages

- **Zero port forwarding** - Works behind NAT
- **Automatic encryption** - No manual key management
- **MagicDNS** - Access services by name
- **Access controls** - Manage in web UI
- **Exit nodes** - Route traffic through homelab

## Network Configuration

### Split Tunnel

Only route homelab traffic through VPN:

**WireGuard**:
```ini
AllowedIPs = 192.168.0.0/16  # Only homelab
```

**Advantages**:
- Faster internet speed
- Lower latency
- Less server load

### Full Tunnel

Route all traffic through VPN:

**WireGuard**:
```ini
AllowedIPs = 0.0.0.0/0, ::/0  # All traffic
```

**Use cases**:
- Public WiFi security
- Hide browsing from ISP
- Access geo-restricted content

## DNS Configuration

### Local DNS Resolution

Access services by name:

**Option 1: Hosts file on client**:
```
10.13.13.1 home.yourdomain.com
10.13.13.1 portainer.yourdomain.com
```

**Option 2: Internal DNS server** (Pi-hole, AdGuard):
Configure VPN DNS to point to internal DNS server.

### MagicDNS (Tailscale)

Enable in Tailscale admin:
- Access services: `http://omakase:8080`
- No manual DNS configuration needed

## Security Best Practices

1. **Strong keys** - Use generated WireGuard keys, never create manually
2. **Limited peer count** - Only create necessary clients
3. **Regular rotation** - Rotate keys periodically
4. **Revoke unused peers** - Remove old devices
5. **Monitor connections** - Check who's connected
6. **Firewall rules** - Limit VPN network access if needed
7. **2FA where possible** - Use Tailscale's SSO with 2FA

## Monitoring

### WireGuard Status

```bash
# Check peers
docker exec wireguard wg show

# View logs
docker compose logs wireguard

# Connection status
docker exec wireguard wg show wg0
```

### Tailscale Status

```bash
# Connection status
sudo tailscale status

# Network map
sudo tailscale netcheck

# Peer list
sudo tailscale status --json
```

## Troubleshooting

### Can't Connect

**Check server running**:
```bash
docker compose ps wireguard
```

**Check firewall**:
```bash
sudo ufw status | grep 51820
```

**Check port forwarding** on router (if behind NAT).

**Verify endpoint**:
```bash
# Test UDP port open
nc -u -z vpn.yourdomain.com 51820
```

### Connected But Can't Access Services

**Check routing**:
```bash
# On client
ip route | grep wg
ping 192.168.1.1
```

**Check AllowedIPs**:
Ensure client config includes homelab subnet:
```ini
AllowedIPs = 192.168.0.0/16
```

**Check server IP forwarding**:
```bash
# On server
sysctl net.ipv4.ip_forward
# Should be: net.ipv4.ip_forward = 1
```

Enable if needed:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Slow Performance

**Check MTU**:
```ini
[Interface]
MTU = 1420  # Try lower values: 1380, 1280
```

**Reduce keepalive**:
```ini
[Peer]
PersistentKeepalive = 25  # Increase to 60 for less overhead
```

**Use split tunnel** instead of full tunnel.

## Access Patterns

### Mobile Access

Setup for accessing homelab from phone:

1. Install WireGuard mobile app
2. Scan QR code or import config
3. Toggle connection when needed
4. Access services at `https://service.yourdomain.com`

### Laptop Road Warrior

Always-on VPN for remote work:

1. Install WireGuard desktop client
2. Import config
3. Set to auto-connect
4. Work as if on local network

### Site-to-Site

Connect two locations:

1. Setup WireGuard on both sites
2. Configure as peers
3. Route networks between sites
4. Access resources on both networks

## Alternative: SSH Tunnel

For quick, one-off access without VPN:

```bash
# Forward port through SSH
ssh -L 8080:localhost:8080 user@homelab-server

# Access at http://localhost:8080
```

**SOCKS proxy**:
```bash
# Create SOCKS proxy
ssh -D 9999 user@homelab-server

# Configure browser to use localhost:9999 as SOCKS proxy
```

## Public Access Considerations

### When to Use VPN

- ✅ Want to keep services private
- ✅ Don't want to expose ports publicly
- ✅ Need access from trusted devices only
- ✅ Want encrypted access over public WiFi

### When to Use Public Access

- ✅ Need to share with others
- ✅ Access from many devices
- ✅ Don't want VPN complexity
- ✅ Use Authelia + CrowdSec protection

**Hybrid approach**: VPN for admin services, public for user-facing.

## See Also

- [Network Architecture](network-architecture.md) - Network design
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [Traefik](traefik.md) - Reverse proxy setup
