# Performance Optimization

Guidelines for optimizing Omakase homelab performance.

## Resource Allocation

### CPU Limits

Set appropriate CPU limits for each service:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Maximum 2 CPU cores
    reservations:
      cpus: '0.5'      # Minimum 0.5 CPU cores
```

**Recommended allocations**:
- **Lightweight services** (Traefik, Authelia): 0.5-1 CPU
- **Medium services** (Nextcloud, Jellyfin): 1-2 CPUs
- **Heavy services** (Local AI, Immich): 2-4 CPUs

### Memory Limits

Prevent memory exhaustion:

```yaml
deploy:
  resources:
    limits:
      memory: 2G       # Maximum 2GB RAM
    reservations:
      memory: 512M     # Minimum 512MB RAM
```

**Recommended allocations**:
- **Lightweight services**: 256M-512M
- **Medium services**: 512M-2G
- **Heavy services**: 2G-8G
- **Databases**: 1G-4G

### Monitor Resource Usage

```bash
# Real-time monitoring
docker stats

# Identify resource hogs
docker stats --no-stream | sort -k 3 -h
```

## Network Performance

### Network Isolation

Use dedicated networks per service to reduce broadcast traffic:

```yaml
networks:
  vnet-service:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.X.0/24
```

### Traefik Optimization

**Enable HTTP/2**:
```yaml
entryPoints:
  websecure:
    http2:
      maxConcurrentStreams: 250
```

**Enable compression**:
```yaml
http:
  middlewares:
    compression:
      compress: {}
```

**Connection limits**:
```yaml
entryPoints:
  websecure:
    transport:
      respondingTimeouts:
        readTimeout: 60s
        writeTimeout: 60s
```

## Storage Performance

### Volume Configuration

Use named volumes for databases:

```yaml
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/postgres/data
```

### Database Optimization

**PostgreSQL**:
```yaml
environment:
  POSTGRES_INITDB_ARGS: "-E UTF8 --locale=C"
  # Tune for your RAM
  POSTGRES_SHARED_BUFFERS: "256MB"
  POSTGRES_EFFECTIVE_CACHE_SIZE: "1GB"
  POSTGRES_MAX_CONNECTIONS: "100"
```

**Redict (Redis alternative)**:
```yaml
command: >
  --save 60 1000
  --maxmemory 256mb
  --maxmemory-policy allkeys-lru
```

### Disk I/O

**Monitor disk performance**:
```bash
iostat -x 1
```

**Use SSD for databases** - Store database volumes on SSD for best performance.

**Mount options** - Use `noatime` to reduce write operations:
```bash
mount -o remount,noatime ${DATA_DIR}
```

## Application Optimization

### Caching

Enable application-level caching where available:

**Nextcloud**:
```yaml
environment:
  REDIS_HOST: redict
  REDIS_HOST_PORT: 6379
```

**Immich**:
```yaml
environment:
  IMMICH_MACHINE_LEARNING_ENABLED: "true"
  IMMICH_MACHINE_LEARNING_URL: http://immich-ml:3003
```

### Concurrent Connections

Tune application workers:

**Gunicorn-based apps**:
```yaml
environment:
  GUNICORN_WORKERS: 4
  GUNICORN_THREADS: 2
```

**Node.js apps**:
```yaml
environment:
  NODE_OPTIONS: "--max-old-space-size=2048"
  UV_THREADPOOL_SIZE: 4
```

## Container Optimization

### Multi-stage Builds

For custom images, use multi-stage builds to reduce image size.

### Image Selection

Prefer Alpine-based images when possible:
- Smaller size
- Faster startup
- Lower memory footprint

### Restart Policies

Use appropriate restart policies:

```yaml
restart: unless-stopped  # Recommended for most services
restart: always         # Critical services only
restart: on-failure     # Services that should stay down when intentionally stopped
```

## Monitoring Performance

### Identify Bottlenecks

**CPU bottlenecks**:
```bash
docker stats --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k 2 -h
```

**Memory bottlenecks**:
```bash
docker stats --format "table {{.Name}}\t{{.MemPerc}}" | sort -k 2 -h
```

**I/O bottlenecks**:
```bash
docker stats --format "table {{.Name}}\t{{.BlockIO}}"
```

**Network bottlenecks**:
```bash
docker stats --format "table {{.Name}}\t{{.NetIO}}"
```

### Performance Metrics

Track over time:
- Response times (Traefik dashboard)
- Database query times
- Container startup times
- Backup durations

## Scaling Strategies

### Horizontal Scaling

For services that support it, deploy multiple instances:

```yaml
deploy:
  replicas: 3
```

### Vertical Scaling

Increase resources for resource-constrained services:

```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 8G
```

### Load Balancing

Use Traefik's load balancing for scaled services:

```yaml
labels:
  - traefik.http.services.myservice.loadbalancer.sticky.cookie=true
```

## System-Level Optimization

### Kernel Parameters

Optimize for containerized workloads:

```bash
# Increase file descriptors
ulimit -n 65536

# Optimize network
sysctl -w net.core.somaxconn=1024
sysctl -w net.ipv4.tcp_max_syn_backlog=2048
```

### Swap Configuration

```bash
# Reduce swappiness for better performance
sysctl vm.swappiness=10
```

### Docker Daemon

Optimize Docker daemon in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

## Benchmarking

### Web Service Response Time

```bash
# Using curl
curl -w "@curl-format.txt" -o /dev/null -s https://service.yourdomain.com

# curl-format.txt content:
#     time_namelookup:  %{time_namelookup}\n
#        time_connect:  %{time_connect}\n
#     time_appconnect:  %{time_appconnect}\n
#    time_pretransfer:  %{time_pretransfer}\n
#       time_redirect:  %{time_redirect}\n
#  time_starttransfer:  %{time_starttransfer}\n
#                     ----------\n
#          time_total:  %{time_total}\n
```

### Database Performance

```bash
# PostgreSQL
docker exec postgres pgbench -U user -d dbname -c 10 -t 100

# Redict
docker exec redict redis-benchmark -h localhost -p 6379 -n 100000
```

## Performance Checklist

**Initial Setup**:
- [ ] Set resource limits for all services
- [ ] Use dedicated networks for isolation
- [ ] Enable caching where available
- [ ] Use SSD for databases

**Regular Optimization**:
- [ ] Monitor resource usage weekly
- [ ] Identify and address bottlenecks
- [ ] Review and adjust resource limits
- [ ] Update to optimized image versions

**Scaling**:
- [ ] Identify services that need more resources
- [ ] Consider horizontal scaling for stateless services
- [ ] Implement load balancing where needed
- [ ] Monitor performance after scaling changes

## See Also

- [Monitoring](monitoring.md) - Performance monitoring
- [Maintenance](maintenance.md) - Regular maintenance
- [Troubleshooting](troubleshooting.md) - Performance issues
