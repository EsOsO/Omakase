# Virtual Machine Deployment

Deploy Omakase in a virtual machine for flexibility and easy management.

## Overview

**VM deployment** provides isolation and flexibility while sharing hardware resources.

**Advantages**:
- Easy snapshots and backups
- Hardware abstraction
- Easy migration
- Can run alongside other VMs
- Test environment on same hardware

**Disadvantages**:
- Virtualization overhead (~5-10%)
- Requires hypervisor
- More complex setup

## Supported Hypervisors

- VMware ESXi / Workstation
- Proxmox VE (see [Proxmox LXC](proxmox-lxc.md) for container option)
- KVM/QEMU (libvirt)
- VirtualBox
- Hyper-V

## VM Specifications

### Minimum

- **vCPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 250GB (thin provisioned)
- **Network**: Bridged or NAT with port forwarding

### Recommended

- **vCPU**: 8 cores
- **RAM**: 16GB
- **Disk**: 500GB NVMe/SSD
- **Network**: Bridged for direct LAN access

## VM Creation

### VMware Example

1. **Create New VM**:
   - Guest OS: Linux → Ubuntu 64-bit
   - Processors: 8 cores
   - Memory: 16GB
   - Disk: 500GB (thin provision)
   - Network: Bridged

2. **VM Settings**:
   - Enable hardware virtualization (VT-x/AMD-V)
   - Paravirtualized SCSI controller
   - VMXNET3 network adapter

3. **Install OS**: Mount Ubuntu Server 24.04 ISO

### Proxmox Example

```bash
# Create VM via CLI
qm create 100 \
  --name omakase \
  --memory 16384 \
  --cores 8 \
  --sockets 1 \
  --net0 virtio,bridge=vmbr0 \
  --scsi0 local-lvm:500 \
  --ide2 local:iso/ubuntu-24.04-server-amd64.iso,media=cdrom \
  --boot order=ide2 \
  --ostype l26

# Start VM
qm start 100
```

### KVM/QEMU Example

```bash
# Create disk
qemu-img create -f qcow2 omakase.qcow2 500G

# Create VM
virt-install \
  --name omakase \
  --ram 16384 \
  --vcpus 8 \
  --disk path=omakase.qcow2,format=qcow2 \
  --network bridge=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --location /path/to/ubuntu-24.04-server-amd64.iso \
  --os-variant ubuntu24.04 \
  --extra-args 'console=ttyS0,115200n8'
```

## Operating System Installation

Follow [Bare Metal Deployment](bare-metal.md#operating-system) guide for OS installation.

## VM-Specific Configuration

### Disk Configuration

**Two-disk setup** (recommended):
- **Disk 1** (100GB): OS and Docker
- **Disk 2** (500GB+): Data storage

```bash
# Format data disk
sudo mkfs.ext4 /dev/sdb

# Mount
sudo mkdir -p /mnt/storage
echo "/dev/sdb /mnt/storage ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
sudo mount -a
```

### Network Configuration

**Bridged mode** (recommended):
- VM gets own IP on LAN
- Direct access from network
- Easy DNS setup

**NAT mode**:
```bash
# Port forwarding required
# Host: 8080 → Guest: 80
# Host: 8443 → Guest: 443
```

### Guest Tools

**VMware Tools**:
```bash
sudo apt install open-vm-tools
```

**QEMU Guest Agent**:
```bash
sudo apt install qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

**VirtualBox Guest Additions**:
```bash
sudo apt install virtualbox-guest-utils virtualbox-guest-dkms
```

## Performance Optimization

### Paravirtualized Drivers

Use virtio drivers for better performance:
- **Disk**: VirtIO SCSI
- **Network**: VirtIO Net
- **Balloon**: VirtIO Balloon (memory management)

### CPU Configuration

```yaml
# Enable CPU passthrough features
cpu: host
```

Allocate dedicated cores if possible.

### Memory

- Enable ballooning for dynamic allocation
- Set minimum memory reservation
- Disable memory overcommit in production

### Storage

- Use SSD/NVMe backed storage
- Enable TRIM/UNMAP for thin provisioning
- Use virtio-scsi over IDE

## Snapshots and Backups

### VM Snapshots

**Before major changes**:
```bash
# Proxmox
qm snapshot 100 pre-update

# VMware
vim-cmd vmsvc/snapshot.create VM_ID snapshot_name

# KVM
virsh snapshot-create-as omakase pre-update
```

**Restore if needed**:
```bash
# Proxmox
qm rollback 100 pre-update

# KVM
virsh snapshot-revert omakase pre-update
```

### VM Backup

**Full VM backup**:
- Proxmox: Built-in backup (vzdump)
- VMware: VM clone or export to OVA
- KVM: virsh dombackup

**Data-only backup**:
Use Omakase's built-in Restic backup for application data.

## High Availability

### VM-Level HA

**Proxmox HA**:
```bash
# Enable HA for VM
ha-manager add vm:100
```

**VMware HA**:
Configure in vSphere cluster settings.

### Replication

**Proxmox**:
```bash
# Set up replication
pvecm add <node-ip>
```

## Migration

### Live Migration

**Proxmox**:
```bash
qm migrate 100 target-node
```

**VMware vMotion**:
Right-click VM → Migrate → Change host

### Cold Migration

1. Shut down VM
2. Export VM (OVA/OVF)
3. Import on target hypervisor
4. Update network configuration
5. Start VM

## Resource Management

### CPU Allocation

```yaml
# Proxmox
cores: 8
cpu: host
cpu-units: 1024  # Default priority
```

### Memory Allocation

```yaml
memory: 16384
balloon: 8192  # Minimum guaranteed
```

### Disk QoS

```yaml
# Limit disk I/O if needed
mbps_rd: 100  # MB/s read limit
mbps_wr: 100  # MB/s write limit
```

## Monitoring

### Hypervisor Monitoring

Monitor VM resources from hypervisor:
- CPU usage
- Memory usage
- Disk I/O
- Network throughput

### Guest Monitoring

Use Omakase's built-in monitoring stack.

## Troubleshooting

### VM Performance Issues

**Check resource allocation**:
- Enough vCPUs assigned?
- Memory ballooning aggressive?
- Disk on SSD?

**Check host load**:
- Other VMs consuming resources?
- Host swap usage?

### Network Issues

**Bridged mode not working**:
- Check bridge configuration
- Verify promiscuous mode enabled

**Can't reach VM**:
- Check firewall on guest
- Verify network adapter connected
- Check DHCP/static IP configuration

### Disk Full

```bash
# Inside VM
df -h

# Thin provisioned disk full?
# Expand disk in hypervisor
# Then expand filesystem
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
```

## Best Practices

1. **Use paravirtualized drivers** - Better performance
2. **Regular snapshots** - Before updates/changes
3. **Monitor resource usage** - Adjust allocation as needed
4. **Use SSD storage** - Significant performance boost
5. **Bridged networking** - Simpler than NAT
6. **Install guest tools** - Better integration
7. **Allocate adequate resources** - Don't overcommit
8. **Regular VM backups** - Complement data backups

## See Also

- [Bare Metal Deployment](bare-metal.md) - OS installation details
- [Proxmox LXC](proxmox-lxc.md) - Container alternative
- [Performance Tuning](../operations/performance.md)
