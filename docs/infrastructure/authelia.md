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

### Service Architecture

Located in `compose/core/authelia/compose.yaml`:

```yaml
services:
  authelia:
    image: ghcr.io/authelia/authelia:4.39.14
    container_name: authelia
    command: '--config /config/configuration.yml'
    environment:
      X_AUTHELIA_CONFIG_FILTERS: template  # Enable Go templating
      AUTHELIA_SESSION_SECRET: ${AUTHELIA_SESSION_SECRET}
      AUTHELIA_STORAGE_ENCRYPTION_KEY: ${AUTHELIA_STORAGE_ENCRYPTION_KEY}
      AUTHELIA_STORAGE_POSTGRES_PASSWORD: ${AUTHELIA_DB_PASS}
      AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET: ${...}
      IDENTITY_PROVIDERS_OIDC_HMAC_SECRET: ${...}
      IDENTITY_PROVIDERS_OIDC_JWKS: ${...}
      # SMTP Configuration
      AUTHELIA_NOTIFIER_SMTP_ADDRESS: submissions://${SMTP_SERVER}:${SMTP_PORT}
      AUTHELIA_NOTIFIER_SMTP_USERNAME: ${SMTP_USERNAME}
      AUTHELIA_NOTIFIER_SMTP_PASSWORD: ${SMTP_PASSWORD}
      AUTHELIA_NOTIFIER_SMTP_SENDER: Authelia <noreply@${TLD}>
    networks:
      - vnet-ingress    # For Traefik access
      - vnet-authelia   # Isolated network for DB and Redis
    depends_on:
      authelia-db:
        condition: service_healthy
      authelia-redict:
        condition: service_healthy

  authelia-db:
    extends:
      file: ../common/compose.yaml
      service: postgres
    environment:
      POSTGRES_DB: ${AUTHELIA_DB_NAME:-authelia_db}
      POSTGRES_USER: ${AUTHELIA_DB_USER:-authelia}
      POSTGRES_PASSWORD: ${AUTHELIA_DB_PASS}
    networks:
      - vnet-authelia

  authelia-redict:
    extends:
      file: ../common/compose.yaml
      service: redict
    networks:
      - vnet-authelia
```

!!! info "Backend Architecture"
    Authelia uses **PostgreSQL** for persistent storage (users, OIDC sessions, TOTP secrets) and **Redis (Redict)** for session caching. This is more robust than file-based storage.

### Main Configuration

Located in `compose/core/authelia/config/configuration.yml`:

```yaml
server:
  address: tcp://:9091
  endpoints:
    authz:
      forward-auth:
        implementation: ForwardAuth  # Traefik integration

authentication_backend:
  file:
    path: /config/users.yml  # Note: users.yml not users_database.yml

storage:
  postgres:
    address: tcp://authelia-db:5432
    database: {{ env "POSTGRES_DB" }}
    username: {{ env "POSTGRES_USER" }}

session:
  redis:
    host: authelia-redict
    port: 6379
  cookies:
    - authelia_url: https://auth.{{ env "DOMAINNAME" }}
      default_redirection_url: https://{{ env "DOMAINNAME" }}
      domain: {{ env "DOMAINNAME" }}

notifier:
  smtp:
    address: submissions://${SMTP_SERVER}:${SMTP_PORT}
    # SMTP configured via environment variables

regulation:
  ban_time: 5m
  find_time: 2m
  max_retries: 3

log:
  format: json
  level: debug
```

!!! info "Template System"
    Configuration uses **Go templates** (`{{ env "VARIABLE" }}`) for environment variable expansion. This is enabled by `X_AUTHELIA_CONFIG_FILTERS: template`.

### Users Database

Located in `compose/core/authelia/config/users.yml`:

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

**Note**: File is named `users.yml`, not `users_database.yml`.

### Access Control Rules

Fine-grained access policies with **network-based rules**:

```yaml
access_control:
  default_policy: deny

  # Define named networks
  networks:
    - name: internal
      networks:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
    - name: work
      networks:
        - 203.0.113.0/24  # Your public IP range

  rules:
    # Bypass auth portal itself
    - domain: auth.{{ env "DOMAINNAME" }}
      policy: bypass

    # Bypass API endpoints (for programmatic access)
    - domain: '*.{{ env "DOMAINNAME" }}'
      policy: bypass
      resources:
        - '^/api$'
        - '^/api/'

    # Two-factor for Vaultwarden admin
    - domain: vault.{{ env "DOMAINNAME" }}
      policy: two_factor
      resources:
        - '^/admin$'
      subject:
        - group:admins

    # Bypass for public services
    - domain:
        - docs.{{ env "DOMAINNAME" }}
        - stream.{{ env "DOMAINNAME" }}
        - immich.{{ env "DOMAINNAME" }}
        - vault.{{ env "DOMAINNAME" }}
      policy: bypass

    # Bypass from internal networks
    - domain: '*.{{ env "DOMAINNAME" }}'
      networks:
        - internal
      policy: bypass

    # One-factor from work networks
    - domain: '*.{{ env "DOMAINNAME" }}'
      networks:
        - work
      policy: one_factor

    # Two-factor for everything else
    - domain: '*.{{ env "DOMAINNAME" }}'
      policy: two_factor
```

!!! info "Network-Based Access Control"
    Rules are evaluated **top to bottom**. The first matching rule is applied. This configuration:

    1. **Bypasses** specific public services (docs, stream, immich, vault)
    2. **Bypasses** all services from internal networks (RFC 1918)
    3. Requires **one-factor** from known work networks
    4. Requires **two-factor** from all other locations (default)

!!! warning "API Endpoint Bypass"
    API endpoints (`/api` and `/api/*`) are bypassed for programmatic access. Ensure services implement their own API authentication.

## User Management

### Add New User

1. Generate password hash:
   ```bash
   docker exec authelia authelia crypto hash generate argon2 --password 'your-password'
   ```

2. Add to `compose/core/authelia/config/users.yml`:
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

!!! info "File-Based Authentication"
    Authelia uses **file-based** authentication backend. User changes require restarting the container. For production with frequent user changes, consider LDAP or other backends.

### Change User Password

1. Generate new hash:
   ```bash
   docker exec authelia authelia crypto hash generate argon2 --password 'new-password'
   ```

2. Update `users.yml` with new hash

3. Restart Authelia:
   ```bash
   docker compose restart authelia
   ```

### Remove User

Remove user entry from `users.yml` and restart Authelia.

!!! warning "User Data Persistence"
    User accounts are stored in `users.yml`. User sessions, TOTP secrets, and WebAuthn devices are stored in **PostgreSQL**. Removing a user from `users.yml` doesn't automatically clean up their database entries.

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

Authelia uses **Redis (Redict)** for session storage. The Redis instance is dedicated to Authelia and runs on the `vnet-authelia` network:

```yaml
session:
  redis:
    host: authelia-redict  # Service name
    port: 6379
```

The `authelia-redict` service extends the common `redict` base service with security hardening and resource limits.

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
5. Password hash updated in PostgreSQL database (user data persists across restarts)

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
docker exec authelia-redict redis-cli keys "authelia-session*"
```

## Troubleshooting

### Can't Login

**Check credentials**:
```bash
# Verify user exists
docker exec authelia cat /config/users.yml | grep username
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
# Connect to Authelia's Redis instance
docker exec authelia-redict redis-cli del "authelia-session:username"
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

### OpenID Connect (OIDC)

Authelia provides **centralized OIDC/SSO** for applications, eliminating the need for separate authentication in each service.

#### Centralized Client Management

OIDC clients are managed using a **modular, file-based system** for maintainability:

**Architecture**:
```
compose/core/authelia/config/
├── configuration.yml          # Main config (references oidc-clients.yml)
├── oidc-clients.yml          # Centralized client list
├── oidc.d/                   # Individual client definitions
│   ├── pgadmin               # pgAdmin OIDC client
│   ├── vikunja               # Vikunja OIDC client
│   └── <service>             # Additional clients
└── users.yml                 # User database
```

**How it works**:

1. Each service has its own file in `oidc.d/<service-name>`
2. `oidc-clients.yml` includes all client files
3. `configuration.yml` references `oidc-clients.yml`

In `configuration.yml`:
```yaml
identity_providers:
  oidc:
    clients:
      {{- fileContent "/config/oidc-clients.yml" | nindent 6 }}
    cors:
      allowed_origins:
        - https://{{ env "DOMAINNAME"}}
    hmac_secret: '{{ env "IDENTITY_PROVIDERS_OIDC_HMAC_SECRET" }}'
    jwks:
      - key: |
          {{- env "IDENTITY_PROVIDERS_OIDC_JWKS" | nindent 9 }}
    lifespans:
      access_token: 1h
      authorize_code: 1m
      id_token: 1h
      refresh_token: 90m
```

In `oidc-clients.yml`:
```yaml
# Infrastructure Services
{{- fileContent "/config/oidc.d/pgadmin" | expandenv | nindent 0 }}

# Productivity Services
{{- fileContent "/config/oidc.d/vikunja" | expandenv | nindent 0 }}

# Add new clients here
```

#### Adding a New OIDC Client

Use the helper script for automated setup:

```bash
# Navigate to scripts directory
cd compose/core/authelia/scripts

# Run the helper script
./add-oidc-client.sh <service-name> '<Display Name>' '<redirect-uri>'

# Example:
./add-oidc-client.sh nextcloud 'Nextcloud' 'https://cloud.yourdomain.com/apps/user_oidc/code'
```

The script will:
1. Generate a secure random client secret
2. Hash it with Authelia's argon2id hasher
3. Create the client file in `oidc.d/<service>`
4. Provide secrets to add to Infisical
5. Show the line to add to `oidc-clients.yml`

**Manual Process** (if script not available):

1. **Generate and hash client secret**:
   ```bash
   # Generate secret
   CLIENT_SECRET=$(openssl rand -base64 32)

   # Hash with Authelia's tool
   docker run --rm authelia/authelia:latest \
     authelia crypto hash generate argon2 --password "$CLIENT_SECRET"
   ```

2. **Add secrets to Infisical**:
   ```bash
   OIDC_<SERVICE>_CLIENT_ID=<service-name>
   OIDC_<SERVICE>_CLIENT_SECRET_DIGEST='$argon2id$v=19$...'
   ```

3. **Create client file** `compose/core/authelia/config/oidc.d/<service>`:
   ```yaml
   - authorization_policy: 'two_factor'
     client_id: '${OIDC_<SERVICE>_CLIENT_ID}'
     client_name: '<Service Display Name>'
     client_secret: '${OIDC_<SERVICE>_CLIENT_SECRET_DIGEST}'
     public: false
     redirect_uris:
       - 'https://<service>.${DOMAINNAME}/<callback-path>'
     scopes:
       - email
       - openid
       - profile
     token_endpoint_auth_method: 'client_secret_post'
     userinfo_signed_response_alg: 'none'
   ```

4. **Add to** `oidc-clients.yml`:
   ```yaml
   # Service Name - Description
   {{- fileContent "/config/oidc.d/<service>" | expandenv | nindent 0 }}
   ```

5. **Restart Authelia**:
   ```bash
   docker compose restart authelia
   ```

#### OIDC Client Configuration Options

**Authorization Policies**:
- `two_factor`: Requires 2FA (recommended for sensitive services)
- `one_factor`: Username/password only

**Client Types**:
- `public: false`: Confidential client with secret (most services)
- `public: true`: Public client without secret (SPAs, mobile apps)

**Token Endpoint Auth Methods**:
- `client_secret_post`: Secret in POST body (recommended)
- `client_secret_basic`: Secret in HTTP Basic Auth header

**Common Scopes**:
- `openid`: Required for OIDC
- `email`: User's email address
- `profile`: User's display name
- `groups`: User's group memberships

#### OIDC Discovery Endpoints

Configure services with these endpoints:

- **Discovery**: `https://auth.yourdomain.com/.well-known/openid-configuration`
- **Authorization**: `https://auth.yourdomain.com/api/oidc/authorization`
- **Token**: `https://auth.yourdomain.com/api/oidc/token`
- **Userinfo**: `https://auth.yourdomain.com/api/oidc/userinfo`
- **JWKS**: `https://auth.yourdomain.com/jwks.json`

#### Troubleshooting OIDC

**Client not appearing**:
```bash
# Verify configuration syntax
docker compose config | grep -A 20 "identity_providers"

# Check secrets loaded
docker compose exec authelia env | grep OIDC_

# Check logs for errors
docker compose logs authelia | grep -i oidc
```

**Authentication failures**:
- Verify redirect URI matches exactly (including trailing slash)
- Check authorization policy requirements (one_factor vs two_factor)
- Verify client secret was hashed correctly (never use plain text)
- Check CORS settings match service domain

**Test OIDC discovery**:
```bash
curl https://auth.yourdomain.com/.well-known/openid-configuration | jq
```

### Rate Limiting

Prevent brute-force attacks:

```yaml
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m
```

## Required Secrets in Infisical

Authelia requires the following secrets to be configured in Infisical vault:

### Core Secrets

```bash
# Session encryption
AUTHELIA_SESSION_SECRET           # Random string (64+ chars)

# Database encryption key
AUTHELIA_STORAGE_ENCRYPTION_KEY   # Random string (64+ chars)

# Database credentials
AUTHELIA_DB_NAME                  # Database name (default: authelia_db)
AUTHELIA_DB_USER                  # Database user (default: authelia)
AUTHELIA_DB_PASS                  # Database password

# Password reset JWT secret
AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET  # Random string (64+ chars)
```

### OIDC Secrets

```bash
# OIDC provider secrets
IDENTITY_PROVIDERS_OIDC_HMAC_SECRET  # Random string (64+ chars)
IDENTITY_PROVIDERS_OIDC_JWKS         # RSA private key in PEM format
```

**Generate OIDC JWKS**:
```bash
# Generate RSA private key
docker run --rm authelia/authelia:latest \
  authelia crypto certificate rsa generate --bits 4096
```

### SMTP Secrets (Optional)

For password reset and notifications:

```bash
SMTP_SERVER        # SMTP server address
SMTP_PORT          # SMTP port (587 for TLS, 465 for SSL)
SMTP_USERNAME      # SMTP authentication username
SMTP_PASSWORD      # SMTP authentication password
```

### OIDC Client Secrets

For each OIDC client, add:

```bash
# Pattern: OIDC_<SERVICE>_CLIENT_ID and OIDC_<SERVICE>_CLIENT_SECRET_DIGEST
OIDC_PGADMIN_CLIENT_ID='pgadmin'
OIDC_PGADMIN_CLIENT_SECRET_DIGEST='$argon2id$v=19$...'

OIDC_VIKUNJA_CLIENT_ID='vikunja'
OIDC_VIKUNJA_CLIENT_SECRET_DIGEST='$argon2id$v=19$...'
```

!!! tip "Generating Secrets"
    Use Authelia's built-in tools for generating and hashing secrets:

    ```bash
    # Generate random secret
    docker run --rm authelia/authelia:latest \
      authelia crypto rand --length 64 --charset alphanumeric

    # Hash password/secret with argon2id
    docker run --rm authelia/authelia:latest \
      authelia crypto hash generate argon2 --password 'your-secret-here'
    ```

## See Also

- [Traefik](traefik.md) - Reverse proxy integration
- [CrowdSec](crowdsec.md) - Intrusion prevention system
- [OIDC Management Guide](https://github.com/esoso/omakase/blob/main/.github/AUTHELIA_OIDC_MANAGEMENT.md) - Detailed OIDC setup
- [Security Best Practices](../security/best-practices.md) - Security guidelines
- [User Management](../operations/maintenance.md) - User maintenance
