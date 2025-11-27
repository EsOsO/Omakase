# Monitoring

Omakase provides multiple monitoring tools to track service health and performance.

## Monitoring Stack

### Dozzle - Real-time Logs

Web-based real-time log viewer for all containers.

**Access**: `https://dozzle.yourdomain.com`

**Features**:
- Real-time log streaming
- Multi-container view
- Search and filter logs
- No database required

**Usage**:
```bash
# Dozzle automatically discovers all containers
# Access via web interface for real-time logs
```

### Homepage - Service Dashboard

Centralized dashboard for all services.

**Access**: `https://home.yourdomain.com`

**Features**:
- Service status indicators
- Quick access links
- Custom widgets
- Docker integration

**Configuration**: Edit `compose/homepage/config/services.yaml`

### Portainer - Container Management

Full container management interface.

**Access**: `https://portainer.yourdomain.com`

**Features**:
- Container lifecycle management
- Resource monitoring
- Stack deployment
- Volume management
- Network inspection

### Traefik Dashboard

Reverse proxy monitoring and routing visualization.

**Access**: `https://traefik.yourdomain.com`

**Features**:
- Active routes
- Service health
- Certificate status
- Middleware chains

## Monitoring Commands

### Service Status

Check all services:
```bash
docker compose ps
```

Check specific service:
```bash
docker compose ps <service-name>
```

### Resource Usage

Real-time resource monitoring:
```bash
docker stats
```

Specific container:
```bash
docker stats <container-name>
```

### Logs

View logs:
```bash
# All services
docker compose logs

# Specific service
docker compose logs <service-name>

# Follow logs
docker compose logs -f <service-name>

# Last N lines
docker compose logs --tail=100 <service-name>

# Since timestamp
docker compose logs --since 2024-01-01T10:00:00
```

### Health Checks

Check container health:
```bash
docker inspect --format='{{.State.Health.Status}}' <container-name>
```

View health check logs:
```bash
docker inspect <container-name> | jq '.[0].State.Health'
```

## Metrics to Monitor

### System Resources

**CPU Usage**:
```bash
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}"
```

**Memory Usage**:
```bash
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}"
```

**Disk Usage**:
```bash
# Docker disk usage
docker system df

# Data directory usage
du -sh ${DATA_DIR}/*

# System disk usage
df -h
```

**Network Usage**:
```bash
docker stats --no-stream --format "table {{.Container}}\t{{.NetIO}}"
```

### Service Health

**Container Status**:
```bash
# Running containers
docker ps

# All containers including stopped
docker ps -a

# Filter by status
docker ps --filter "status=exited"
```

**Network Connectivity**:
```bash
# List networks
docker network ls

# Inspect network
docker network inspect vnet-service

# Check subnet allocations
make network
```

### Security Monitoring

**CrowdSec Alerts**:
```bash
# List recent alerts
docker exec crowdsec cscli alerts list

# List active decisions (blocks)
docker exec crowdsec cscli decisions list

# View metrics
docker exec crowdsec cscli metrics
```

**Authelia Authentication**:
```bash
# View authentication logs
docker compose logs authelia | grep "authentication"
```

## Alerting

### Telegram Notifications

Configured for backup operations. See [Backup](backup.md).

### Email Alerts

Configure SMTP in Authelia for:
- Failed login attempts
- Password reset requests
- 2FA notifications

### Log Monitoring

Use Dozzle to set up:
- Log filters for errors
- Real-time monitoring
- Search saved queries

## Performance Monitoring

### Response Times

Monitor via Traefik dashboard:
- Request rates
- Response times
- Error rates

### Database Performance

**PostgreSQL**:
```bash
# Connection stats
docker exec postgres psql -U user -d dbname -c "SELECT * FROM pg_stat_activity;"

# Database size
docker exec postgres psql -U user -c "\l+"
```

### Storage Performance

**I/O Statistics**:
```bash
iostat -x 1
```

**Disk Performance**:
```bash
docker run --rm -v ${DATA_DIR}:/data alpine sh -c "dd if=/dev/zero of=/data/testfile bs=1M count=1024 && rm /data/testfile"
```

## Dashboard Setup

### Homepage Widgets

Edit `compose/homepage/config/services.yaml`:

```yaml
- Service Name:
    - Description: Service description
      icon: service-icon.png
      href: https://service.yourdomain.com
      ping: http://service:port
      container: container-name
```

### Grafana (Optional)

For advanced monitoring, consider adding:
- Prometheus for metrics collection
- Grafana for visualization
- Loki for log aggregation

## Monitoring Checklist

**Daily**:
- [ ] Check Homepage dashboard
- [ ] Review error logs in Dozzle
- [ ] Verify all services running

**Weekly**:
- [ ] Check resource usage trends
- [ ] Review CrowdSec security alerts
- [ ] Check disk space utilization

**Monthly**:
- [ ] Review performance metrics
- [ ] Analyze resource consumption
- [ ] Optimize underperforming services

## Troubleshooting Monitoring

### Dozzle Not Showing Logs

Check Cetusguard connection:
```bash
docker compose logs dozzle
```

Verify Docker socket proxy is running:
```bash
docker compose ps cetusguard
```

### Homepage Not Updating

Check service status:
```bash
docker compose ps homepage
```

Verify configuration:
```bash
docker compose logs homepage
```

### Portainer Connection Issues

Check API access through Cetusguard:
```bash
curl http://cetusguard:2375/v1.43/containers/json
```

## See Also

- [Maintenance](maintenance.md) - Regular maintenance tasks
- [Troubleshooting](troubleshooting.md) - Common issues
- [Performance](performance.md) - Performance optimization
