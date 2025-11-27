# Authelia OIDC Client Management

This document provides analysis and recommendations for managing OIDC clients in Authelia.

## Current Implementation

### Structure

```
compose/core/authelia/config/
├── configuration.yml          # Main Authelia config
├── oidc.d/                   # OIDC client definitions directory
│   ├── pgadmin               # pgAdmin OIDC client
│   └── vikunja               # Vikunja OIDC client
└── users.yml                 # User database
```

### How It Works Now

In `configuration.yml` (lines 55-57):

```yaml
identity_providers:
  oidc:
    clients:
      {{- fileContent "/config/oidc.d/pgadmin" | expandenv | nindent 6 }}
      {{- fileContent "/config/oidc.d/vikunja" | expandenv | nindent 6 }}
```

**Current Approach**:
- ✅ **Good**: Each client in separate file (modular)
- ✅ **Good**: Uses `expandenv` for environment variable substitution
- ❌ **Problem**: Must manually add each new client to `configuration.yml`
- ❌ **Problem**: Not scalable for many clients

### Client File Structure

Each client file (e.g., `oidc.d/pgadmin`):

```yaml
- authorization_policy: 'two_factor'
  client_id: '${OIDC_PGADMIN_CLIENT_ID}'
  client_name: 'pgAdmin'
  client_secret: '${OIDC_PGADMIN_CLIENT_SECRET_DIGEST}'
  public: false
  redirect_uris:
    - 'https://pgadmin.${DOMAINNAME}/oauth2/authorize'
  scopes:
    - email
    - openid
    - profile
  token_endpoint_auth_method: 'client_secret_basic'
  userinfo_signed_response_alg: 'none'
```

**Secrets Pattern**: `OIDC_<SERVICE>_CLIENT_ID` and `OIDC_<SERVICE>_CLIENT_SECRET_DIGEST`

---

## Recommended Solutions

### 🏆 Solution 1: Auto-Discovery Pattern (RECOMMENDED)

**Automatically load all client files from `oidc.d/` directory**

#### Implementation

**Step 1**: Create a directory listing script

Create `compose/core/authelia/scripts/generate-oidc-includes.sh`:

```bash
#!/bin/bash
# Generate OIDC client includes for Authelia configuration

OIDC_DIR="/config/oidc.d"
OUTPUT=""

# Loop through all files in oidc.d directory (excluding hidden files and examples)
for file in "$OIDC_DIR"/*; do
    # Skip if no files found
    [ -e "$file" ] || continue

    # Get filename without path
    filename=$(basename "$file")

    # Skip hidden files and .example files
    if [[ "$filename" == .* ]] || [[ "$filename" == *.example ]]; then
        continue
    fi

    # Generate the fileContent line with proper indentation
    echo "      {{- fileContent \"/config/oidc.d/$filename\" | expandenv | nindent 6 }}"
done
```

**Step 2**: Modify Docker Compose to run script before Authelia starts

In `compose/core/authelia/compose.yaml`, add an init container or entrypoint wrapper.

**Step 3**: Update `configuration.yml` to use generated include

```yaml
identity_providers:
  oidc:
    clients:
      {{- fileContent "/config/oidc-clients-generated.yml" | nindent 6 }}
```

#### Pros & Cons

✅ **Pros**:
- Fully automatic - just drop files in `oidc.d/`
- No manual edits to `configuration.yml`
- Scales to dozens of clients
- Easy to enable/disable clients (remove file or add `.disabled` suffix)

❌ **Cons**:
- Requires shell script and init container
- Slightly more complex setup
- Adds small startup overhead

---

### 🔧 Solution 2: Include All Pattern (SIMPLER)

**Use a single include file that references all clients**

#### Implementation

**Step 1**: Create `config/oidc-clients.yml`:

```yaml
{{- fileContent "/config/oidc.d/pgadmin" | expandenv | nindent 0 }}
{{- fileContent "/config/oidc.d/vikunja" | expandenv | nindent 0 }}
{{- fileContent "/config/oidc.d/nextcloud" | expandenv | nindent 0 }}
{{- fileContent "/config/oidc.d/immich" | expandenv | nindent 0 }}
# Add more as needed
```

**Step 2**: Update `configuration.yml`:

```yaml
identity_providers:
  oidc:
    clients:
      {{- fileContent "/config/oidc-clients.yml" | nindent 6 }}
```

#### Pros & Cons

✅ **Pros**:
- Simple implementation
- Clear single place to manage client list
- No shell scripts needed
- Easy to comment out clients for testing

❌ **Cons**:
- Still requires manual addition to `oidc-clients.yml`
- One extra layer of indirection

---

### 📁 Solution 3: Organized by Category (SCALABLE)

**Group clients by service category for better organization**

#### Implementation

**Directory Structure**:

```
config/oidc.d/
├── infrastructure/
│   ├── pgadmin
│   └── portainer
├── productivity/
│   ├── nextcloud
│   └── vikunja
├── media/
│   ├── jellyfin
│   └── immich
└── development/
    └── windmill
```

**Configuration**:

```yaml
identity_providers:
  oidc:
    clients:
      # Infrastructure
      {{- fileContent "/config/oidc.d/infrastructure/pgadmin" | expandenv | nindent 6 }}
      {{- fileContent "/config/oidc.d/infrastructure/portainer" | expandenv | nindent 6 }}

      # Productivity
      {{- fileContent "/config/oidc.d/productivity/nextcloud" | expandenv | nindent 6 }}
      {{- fileContent "/config/oidc.d/productivity/vikunja" | expandenv | nindent 6 }}

      # Media
      {{- fileContent "/config/oidc.d/media/jellyfin" | expandenv | nindent 6 }}
      {{- fileContent "/config/oidc.d/media/immich" | expandenv | nindent 6 }}
```

#### Pros & Cons

✅ **Pros**:
- Excellent organization for many clients
- Easy to find and manage related services
- Can disable entire categories by commenting out sections
- Self-documenting structure

❌ **Cons**:
- Still manual additions
- More complex directory structure

---

## 🎯 Recommended Implementation

For **Omakase**, I recommend **Solution 2** (Include All Pattern) as the best balance of simplicity and maintainability:

### Why Solution 2?

1. **Simple**: No shell scripts or init containers
2. **Clear**: Single file lists all clients
3. **Maintainable**: Easy to add/remove/disable clients
4. **Documented**: Comments can explain each client
5. **Testable**: Easy to comment out clients for debugging

### Implementation Steps

1. **Create the include file**:

```bash
cat > compose/core/authelia/config/oidc-clients.yml << 'EOF'
# Authelia OIDC Clients
# This file includes all OIDC client definitions from the oidc.d/ directory
# To add a new client:
# 1. Create file in oidc.d/<service-name>
# 2. Add fileContent line below
# 3. Add secrets to Infisical: OIDC_<SERVICE>_CLIENT_ID and OIDC_<SERVICE>_CLIENT_SECRET_DIGEST

# Infrastructure Services
{{- fileContent "/config/oidc.d/pgadmin" | expandenv | nindent 0 }}

# Productivity Services
{{- fileContent "/config/oidc.d/vikunja" | expandenv | nindent 0 }}

# Add new clients here following the same pattern
# {{- fileContent "/config/oidc.d/nextcloud" | expandenv | nindent 0 }}
# {{- fileContent "/config/oidc.d/immich" | expandenv | nindent 0 }}
EOF
```

2. **Update `configuration.yml`**:

```yaml
identity_providers:
  oidc:
    clients:
      {{- fileContent "/config/oidc-clients.yml" | nindent 6 }}
```

3. **Document the pattern** in service docs

---

## Client Template

When adding a new OIDC client, use this template in `oidc.d/<service>`:

```yaml
- authorization_policy: 'two_factor'  # or 'one_factor'
  client_id: '${OIDC_<SERVICE>_CLIENT_ID}'
  client_name: '<Service Display Name>'
  client_secret: '${OIDC_<SERVICE>_CLIENT_SECRET_DIGEST}'
  public: false  # true for public clients (no secret)
  redirect_uris:
    - 'https://<service>.${DOMAINNAME}/<callback-path>'
  scopes:
    - email
    - openid
    - profile
    - groups  # If service needs group information
  token_endpoint_auth_method: 'client_secret_post'  # or 'client_secret_basic'
  userinfo_signed_response_alg: 'none'  # or 'RS256' if service requires
  consent_mode: 'implicit'  # Skip consent screen for trusted apps
```

### Required Secrets in Infisical

For each client, add:

```bash
# Client ID (can be any unique string, usually lowercase service name)
OIDC_<SERVICE>_CLIENT_ID=service-name

# Client secret (hashed with argon2id)
# Generate with: docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR_SECRET'
OIDC_<SERVICE>_CLIENT_SECRET_DIGEST='$argon2id$v=19$...'
```

---

## Adding a New Client - Step by Step

### 1. Generate Client Secret

```bash
# Generate a secure random secret
openssl rand -base64 32

# Hash it with Authelia's tool
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YOUR_SECRET_HERE'
```

### 2. Add to Infisical

```bash
# Add both secrets to Infisical
OIDC_MYSERVICE_CLIENT_ID=myservice
OIDC_MYSERVICE_CLIENT_SECRET_DIGEST='$argon2id$v=19$m=65536,t=3,p=4$...'
```

### 3. Create Client File

```bash
cat > compose/core/authelia/config/oidc.d/myservice << 'EOF'
- authorization_policy: 'two_factor'
  client_id: '${OIDC_MYSERVICE_CLIENT_ID}'
  client_name: 'My Service'
  client_secret: '${OIDC_MYSERVICE_CLIENT_SECRET_DIGEST}'
  public: false
  redirect_uris:
    - 'https://myservice.${DOMAINNAME}/oauth2/callback'
  scopes:
    - email
    - openid
    - profile
  token_endpoint_auth_method: 'client_secret_post'
  userinfo_signed_response_alg: 'none'
EOF
```

### 4. Add to Include File

Edit `config/oidc-clients.yml`:

```yaml
# ... existing clients ...

# My Service
{{- fileContent "/config/oidc.d/myservice" | expandenv | nindent 0 }}
```

### 5. Restart Authelia

```bash
docker compose restart authelia
```

### 6. Verify

```bash
# Check Authelia logs for successful client registration
docker compose logs authelia | grep -i "oidc"

# Test OIDC discovery endpoint
curl https://auth.yourdomain.com/.well-known/openid-configuration | jq
```

---

## Troubleshooting

### Client Not Appearing

1. **Check syntax**: Ensure YAML is valid
   ```bash
   docker compose config | grep -A 20 "identity_providers"
   ```

2. **Verify secrets loaded**:
   ```bash
   docker compose exec authelia env | grep OIDC_
   ```

3. **Check Authelia logs**:
   ```bash
   docker compose logs authelia | grep -i error
   ```

### Authentication Failures

1. **Verify redirect URI** matches exactly (including trailing slash)
2. **Check authorization policy** (one_factor vs two_factor)
3. **Verify client secret** was hashed correctly
4. **Check CORS settings** if client is web-based

### Secret Hashing Issues

```bash
# Always use Authelia's own hasher
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YOUR_SECRET'

# Don't use plain passwords - always hash them!
```

---

## Security Best Practices

1. **Always use two_factor** for sensitive services (admin panels, databases)
2. **Use one_factor** only for low-risk services on trusted networks
3. **Rotate secrets** periodically (recommended: every 90 days)
4. **Use consent_mode: auto** for fully trusted first-party apps
5. **Keep client_secret** in Infisical, never in git
6. **Use specific redirect_uris** - avoid wildcards
7. **Limit scopes** to only what the service needs

---

## Migration from Current Setup

If you want to implement Solution 2:

```bash
# 1. Create oidc-clients.yml
cd compose/core/authelia/config
cat > oidc-clients.yml << 'EOF'
# Include existing clients
{{- fileContent "/config/oidc.d/pgadmin" | expandenv | nindent 0 }}
{{- fileContent "/config/oidc.d/vikunja" | expandenv | nindent 0 }}
EOF

# 2. Update configuration.yml
# Replace lines 56-57 with:
#   {{- fileContent "/config/oidc-clients.yml" | nindent 6 }}

# 3. Test configuration
docker compose config

# 4. Restart Authelia
docker compose restart authelia
```

---

## Future Enhancements

### Automated Client Discovery

For truly automatic client loading, consider implementing Solution 1 with a script that:

```bash
#!/bin/bash
# Generate oidc-clients.yml from all files in oidc.d/
cd /config/oidc.d
for client in *; do
  [ -f "$client" ] && [ ! "$client" =~ \. ] && \
    echo "{{- fileContent \"/config/oidc.d/$client\" | expandenv | nindent 0 }}"
done > /config/oidc-clients.yml
```

Run this as an init container or in Authelia's entrypoint.

### Client Management UI

Consider building a simple web UI to:
- List all registered clients
- Enable/disable clients
- Generate secrets
- Test OIDC flows

This could be a separate service that modifies the `oidc.d/` files.

---

**Last Updated**: 2025-11-27
**Authelia Version**: Latest
**Maintained By**: Omakase Team
