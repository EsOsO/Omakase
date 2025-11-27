# Maintenance

Regular maintenance tasks to keep your Omakase homelab running smoothly.

## Daily Tasks

### Monitor Services

Check service health:
```bash
docker compose ps
```

View recent logs:
```bash
docker compose logs --tail=100
```

### Check Backup Status

Verify daily backups completed:
```bash
docker compose logs backup | grep -i "backup completed"
```

## Weekly Tasks

### Update Docker Images

Pull latest images:
```bash
make pull
```

Restart services with new images:
```bash
make restart
```

### Review Security Alerts

Check CrowdSec decisions:
```bash
docker exec crowdsec cscli decisions list
```

Review blocked IPs:
```bash
docker exec crowdsec cscli alerts list
```

### Check Disk Usage

Monitor storage:
```bash
df -h ${DATA_DIR}
```

Check Docker disk usage:
```bash
docker system df
```

## Monthly Tasks

### Clean Unused Resources

Remove unused containers, images, volumes:
```bash
make clean
```

Or manually:
```bash
docker system prune -a --volumes
```

### Review Logs

Archive old logs if needed:
```bash
find ${DATA_DIR}/*/logs -name "*.log" -mtime +30 -exec gzip {} \;
```

### Test Backup Restore

Perform test restore to verify backups:
```bash
docker exec restic-backup restic restore latest --target /tmp/restore-test
```

### Update Documentation

Review and update service documentation as configurations change.

## Quarterly Tasks

### Security Audit

1. Review user access in Authelia
2. Rotate sensitive credentials
3. Review CrowdSec security collections
4. Update security policies

### Performance Review

1. Check resource usage:
   ```bash
   docker stats
   ```
2. Identify resource-heavy services
3. Optimize configurations if needed

### Dependency Updates

Review and test major version updates:
1. Check Renovate PRs
2. Read changelogs
3. Test in development environment
4. Deploy to production

## As-Needed Tasks

### Add New Service

Follow the [Adding Services](../contributing/adding-services.md) guide.

### Rotate Secrets

1. Generate new secret:
   ```bash
   make pwgen
   ```
2. Update in Infisical
3. Restart affected services:
   ```bash
   docker compose restart <service>
   ```

### Scale Resources

Adjust CPU/memory limits in compose files:
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
```

## Monitoring Checklist

Daily:
- [ ] Check service status
- [ ] Verify backup completion
- [ ] Review error logs

Weekly:
- [ ] Update images
- [ ] Review security alerts
- [ ] Check disk usage

Monthly:
- [ ] Clean unused resources
- [ ] Test backup restore
- [ ] Review logs

Quarterly:
- [ ] Security audit
- [ ] Performance review
- [ ] Dependency updates

## Maintenance Windows

For major updates that require downtime:

1. **Notify users** (if shared homelab)
2. **Backup current state**:
   ```bash
   docker exec restic-backup restic backup /data
   ```
3. **Stop services**:
   ```bash
   make down
   ```
4. **Perform maintenance**
5. **Start services**:
   ```bash
   make up
   ```
6. **Verify functionality**:
   ```bash
   docker compose ps
   docker compose logs
   ```

## Automation

Consider automating routine tasks:

### Watchtower for Auto-Updates

**Warning**: Not recommended for production. Use Renovate instead for controlled updates.

### Monitoring Alerts

Set up alerts for:
- Service failures
- Disk space warnings
- Backup failures (via Telegram)
- Security incidents (CrowdSec)

## Emergency Procedures

### Service Down

1. Check logs:
   ```bash
   docker compose logs <service>
   ```
2. Restart service:
   ```bash
   docker compose restart <service>
   ```
3. If persistent, restore from backup

### System Resources Exhausted

1. Identify resource hog:
   ```bash
   docker stats
   ```
2. Stop non-critical services:
   ```bash
   docker compose stop <service>
   ```
3. Clean up:
   ```bash
   make clean
   ```

### Security Incident

1. Check CrowdSec alerts
2. Review service logs
3. Block malicious IPs:
   ```bash
   docker exec crowdsec cscli decisions add --ip <ip> --duration 24h
   ```
4. Rotate compromised credentials

## See Also

- [Backup](backup.md) - Backup procedures
- [Troubleshooting](troubleshooting.md) - Common issues
- [Monitoring](monitoring.md) - Monitoring setup
