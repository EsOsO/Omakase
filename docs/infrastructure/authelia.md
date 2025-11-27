# Authelia

Authelia provides single sign-on (SSO) and two-factor authentication for all Omakase services.

## Overview

Authelia features:
- **Single Sign-On** - Login once, access all services
- **Two-Factor Authentication** - TOTP, WebAuthn, Duo
- **Access Control** - Fine-grained authorization rules
- **Session Management** - Secure session handling
- **Password Reset** - Self-service password recovery

## Configuration

### Main Configuration

Located in `compose/authelia/config/configuration.yml`:

```yaml
server:
  host: 0.0.0.0
  port: 9091

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id

access_control:
  default_policy: deny
  rules:
    - domain: "*.yourdomain.com"
      policy: two_factor

session:
  name: authelia_session
  domain: yourdomain.com
  expiration: 1h
  inactivity: 5m
```

### Users Database

Located in `compose/authelia/config/users_database.yml`:

```yaml
users:
  john:
    displayname: "John Doe"
    password: "$argon2id$..."  # Generated hash
    email: john@example.com
    groups:
      - admins
      - users

  jane:
    displayname: "Jane Smith"
    password: "$argon2id$..."
    email: jane@example.com
    groups:
      - users
```

### Access Control Rules

Fine-grained access policies:

```yaml
access_control:
  default_policy: deny

  rules:
    # Bypass authentication for public services
    - domain: "public.yourdomain.com"
      policy: bypass

    # Single-factor for monitoring
    - domain: "monitoring.yourdomain.com"
      policy: one_factor
      subject:
        - "group:admins"

    # Two-factor for sensitive services
    - domain:
        - "vaultwarden.yourdomain.com"
        - "admin.yourdomain.com"
      policy: two_factor
      subject:
        - "group:admins"

    # One-factor for regular services
    - domain: "*.yourdomain.com"
      policy: one_factor
```

## User Management

### Add New User

1. Generate password hash:
   ```bash
   docker exec authelia authelia crypto hash generate argon2 --password 'your-password'
   ```

2. Add to `users_database.yml`:
   ```yaml
   users:
     newuser:
       displayname: "New User"
       password: "$argon2id$..."
       email: newuser@example.com
       groups:
         - users
   ```

3. Restart Authelia:
   ```bash
   docker compose restart authelia
   ```

### Change User Password

Generate new hash and update `users_database.yml`:

```bash
docker exec authelia authelia crypto hash generate argon2 --password 'new-password'
```

### Remove User

Remove user entry from `users_database.yml` and restart Authelia.

## Two-Factor Authentication

### TOTP (Time-based One-Time Password)

Users can enroll TOTP via Authelia portal:

1. Access: `https://auth.yourdomain.com`
2. Login with username/password
3. Navigate to **Two-Factor**
4. Scan QR code with authenticator app (Google Authenticator, Authy, etc.)

### WebAuthn

Hardware security keys (YubiKey, etc.):

1. Access Authelia portal
2. Navigate to **WebAuthn**
3. Click **Add Device**
4. Follow browser prompts

### Duo Push

Configure Duo integration in `configuration.yml`:

```yaml
duo_api:
  hostname: api-xxxxx.duosecurity.com
  integration_key: ${DUO_INTEGRATION_KEY}
  secret_key: ${DUO_SECRET_KEY}
```

## Integration with Services

### Traefik Middleware

Services protected by Authelia use Traefik middleware:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myservice.rule=Host(`myservice.${DOMAINNAME}`)
  - traefik.http.routers.myservice.middlewares=chain-authelia@file
```

### Bypass Authentication

For services with own authentication:

```yaml
labels:
  - traefik.http.routers.myservice.middlewares=chain-no-auth@file
```

Or configure in Authelia access rules:

```yaml
access_control:
  rules:
    - domain: "myservice.yourdomain.com"
      policy: bypass
```

### API Access

For programmatic access:

```yaml
access_control:
  rules:
    - domain: "api.yourdomain.com"
      resources:
        - "^/api/.*$"
      policy: bypass
```

## Session Management

### Session Storage

Authelia uses Redis (Redict) for session storage:

```yaml
session:
  redis:
    host: redict
    port: 6379
    database_index: 0
```

### Session Timeout

Configure in `configuration.yml`:

```yaml
session:
  expiration: 1h        # Total session duration
  inactivity: 5m        # Idle timeout
  remember_me_duration: 30d  # "Remember me" duration
```

### Logout

Users can logout from: `https://auth.yourdomain.com/logout`

Or configure logout buttons in services to redirect to logout URL.

## Password Reset

### SMTP Configuration

Enable password reset via email:

```yaml
notifier:
  smtp:
    host: smtp.gmail.com
    port: 587
    username: ${SMTP_USERNAME}
    password: ${SMTP_PASSWORD}
    sender: authelia@yourdomain.com
    subject: "[Authelia] {title}"
```

Store credentials in Infisical.

### Reset Flow

1. User clicks "Forgot password" on login page
2. Enters email address
3. Receives reset link via email
4. Sets new password
5. Password updated in `users_database.yml`

## Monitoring

### Access Logs

View authentication attempts:

```bash
docker compose logs authelia | grep "authentication"
```

### Failed Logins

Monitor failed login attempts:

```bash
docker compose logs authelia | grep "failed"
```

### Active Sessions

Check Redis for active sessions:

```bash
docker exec redict redis-cli keys "authelia-session*"
```

## Troubleshooting

### Can't Login

**Check credentials**:
```bash
# Verify user exists
docker exec authelia cat /config/users_database.yml | grep username
```

**Verify password hash**:
```bash
# Generate test hash
docker exec authelia authelia crypto hash generate argon2 --password 'test-password'
```

**Check logs**:
```bash
docker compose logs authelia | tail -50
```

### Redirect Loop

**Check Traefik configuration**:
- Ensure middleware chain is correctly configured
- Verify service is on `ingress` network

**Check Authelia URL**:
- Must be accessible at `https://auth.yourdomain.com`

### 2FA Not Working

**Check time sync**:
```bash
# TOTP requires accurate time
docker exec authelia date
```

Time must be synchronized (use NTP).

**Reset 2FA**:

Remove 2FA config from user's session in Redis:
```bash
docker exec redict redis-cli del "authelia-session:username"
```

### Email Not Sending

**Test SMTP**:
```bash
docker exec authelia authelia crypto hash generate argon2 --password 'test'
```

Check SMTP logs in Authelia.

## Security Best Practices

1. **Use strong passwords** - Enforce password complexity
2. **Enable 2FA** - Require for admin accounts
3. **Limit access** - Use access control rules
4. **Monitor logs** - Review authentication logs regularly
5. **Rotate secrets** - Change passwords periodically
6. **Backup users database** - Include in backup strategy
7. **Use HTTPS only** - Never access over HTTP

## Access Control Patterns

### Public Service

```yaml
- domain: "public.yourdomain.com"
  policy: bypass
```

### Admin-Only Service

```yaml
- domain: "admin.yourdomain.com"
  policy: two_factor
  subject:
    - "group:admins"
```

### Group-Based Access

```yaml
- domain: "developers.yourdomain.com"
  policy: one_factor
  subject:
    - "group:developers"
    - "group:admins"
```

### Network-Based Access

```yaml
- domain: "internal.yourdomain.com"
  policy: bypass
  networks:
    - 192.168.1.0/24
```

### Path-Based Access

```yaml
- domain: "app.yourdomain.com"
  policy: bypass
  resources:
    - "^/public/.*$"

- domain: "app.yourdomain.com"
  policy: two_factor
  resources:
    - "^/admin/.*$"
```

## Advanced Configuration

### LDAP Backend

For integration with Active Directory:

```yaml
authentication_backend:
  ldap:
    url: ldap://ldap.yourdomain.com
    base_dn: dc=yourdomain,dc=com
    username_attribute: uid
    additional_users_dn: ou=users
    users_filter: (&({username_attribute}={input})(objectClass=person))
```

### OpenID Connect

Expose OIDC for service integration:

```yaml
identity_providers:
  oidc:
    clients:
      - id: my-app
        description: My Application
        secret: ${OIDC_CLIENT_SECRET}
        redirect_uris:
          - https://my-app.yourdomain.com/callback
```

### Rate Limiting

Prevent brute-force attacks:

```yaml
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m
```

## See Also

- [Traefik](traefik.md) - Reverse proxy integration
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [User Management](../operations/maintenance.md) - User maintenance
