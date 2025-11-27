# Backup

Omakase uses Restic for automated, encrypted backups to Backblaze B2 cloud storage.

## Overview

The backup system provides:
- **Automated daily backups** at 3:30 AM
- **Integrity checks** at 5:15 AM
- **Automated pruning** at 4:00 AM to manage storage
- **Encrypted backups** to Backblaze B2
- **Telegram notifications** for backup status

## Configuration

Backup configuration is located in `compose/backup/compose.yaml`.

### Required Secrets

Configure these in Infisical:

| Variable | Description |
|----------|-------------|
| `B2_ACCOUNT_ID` | Backblaze B2 account ID |
| `B2_ACCOUNT_KEY` | Backblaze B2 application key |
| `RESTIC_REPOSITORY` | Restic repository URL |
| `RESTIC_PASSWORD` | Encryption password for backups |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token for notifications |
| `TELEGRAM_CHAT_ID` | Telegram chat ID for notifications |

### Backup Schedule

Default cron schedules:
```yaml
- "30 3 * * *"  # Backup at 3:30 AM
- "15 5 * * *"  # Check at 5:15 AM
- "0 4 * * *"   # Prune at 4:00 AM
```

## Manual Operations

### Manual Backup

```bash
docker exec restic-backup restic backup /data
```

### List Snapshots

```bash
docker exec restic-backup restic snapshots
```

### Restore Data

Restore latest snapshot:
```bash
docker exec restic-backup restic restore latest --target /restore
```

Restore specific snapshot:
```bash
docker exec restic-backup restic restore <snapshot-id> --target /restore
```

### Check Repository Integrity

```bash
docker exec restic-backup restic check
```

### View Backup Statistics

```bash
docker exec restic-backup restic stats
```

## Backup Retention Policy

Configured in the prune script:
- Keep daily backups for 7 days
- Keep weekly backups for 4 weeks
- Keep monthly backups for 12 months
- Keep yearly backups for 10 years

## What Gets Backed Up

Backup includes all data in `${DATA_DIR}`:
- Service configurations
- Application data
- Databases
- User files

**Excluded:**
- Temporary files
- Cache directories
- Container images (can be rebuilt)

## Monitoring Backups

### Telegram Notifications

Receive notifications for:
- Successful backups
- Failed backups
- Check results
- Prune operations

### Manual Monitoring

Check recent backup logs:
```bash
docker compose logs backup
```

View last backup status:
```bash
docker exec restic-backup restic snapshots --last
```

## Disaster Recovery

### Full System Recovery

1. Install fresh Omakase instance
2. Configure Restic with same credentials
3. List available snapshots:
   ```bash
   docker exec restic-backup restic snapshots
   ```
4. Restore latest snapshot:
   ```bash
   docker exec restic-backup restic restore latest --target ${DATA_DIR}
   ```
5. Fix permissions:
   ```bash
   chown -R ${PUID}:${PGID} ${DATA_DIR}
   ```
6. Start services:
   ```bash
   make up
   ```

### Selective Restore

Restore specific service:
```bash
docker exec restic-backup restic restore latest \
  --target /restore \
  --include ${DATA_DIR}/service-name
```

## Troubleshooting

### Backup Fails

Check Backblaze credentials:
```bash
make config | grep B2_
```

Test connectivity:
```bash
docker exec restic-backup restic snapshots
```

### Repository Locked

If backup fails with "repository is already locked":
```bash
docker exec restic-backup restic unlock
```

### Storage Full

Check repository size:
```bash
docker exec restic-backup restic stats
```

Run manual prune:
```bash
docker exec restic-backup restic prune
```

## Best Practices

1. **Test restores regularly** - Verify backups are working
2. **Monitor notifications** - Set up Telegram for alerts
3. **Verify encryption** - Keep `RESTIC_PASSWORD` secure
4. **Monitor storage costs** - Check Backblaze usage
5. **Document recovery procedures** - Keep this guide accessible

## See Also

- [Maintenance](maintenance.md) - Regular maintenance tasks
- [Troubleshooting](troubleshooting.md) - Common issues
- [Secrets Management](../security/secrets-management.md) - Managing backup credentials
