#!/bin/bash
# Script to add a new OIDC client to Authelia
# Usage: ./add-oidc-client.sh <service-name> <display-name> <redirect-uri>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 3 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Usage: $0 <service-name> <display-name> <redirect-uri>"
    echo ""
    echo "Example:"
    echo "  $0 nextcloud 'Nextcloud' 'https://cloud.example.com/apps/user_oidc/code'"
    exit 1
fi

SERVICE_NAME="$1"
DISPLAY_NAME="$2"
REDIRECT_URI="$3"

# Convert service name to uppercase for env vars
SERVICE_UPPER=$(echo "$SERVICE_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

CONFIG_DIR="$(dirname "$0")/../config"
OIDC_DIR="$CONFIG_DIR/oidc.d"
CLIENT_FILE="$OIDC_DIR/$SERVICE_NAME"

echo -e "${BLUE}=== Adding OIDC Client for $DISPLAY_NAME ===${NC}"
echo ""

# Check if client already exists
if [ -f "$CLIENT_FILE" ]; then
    echo -e "${RED}Error: Client file already exists at $CLIENT_FILE${NC}"
    exit 1
fi

# Generate a secure random secret
echo -e "${YELLOW}Generating secure client secret...${NC}"
CLIENT_SECRET=$(openssl rand -base64 32)
echo -e "${GREEN}Generated client secret: ${NC}$CLIENT_SECRET"
echo ""

# Generate hashed secret using Authelia's hasher
echo -e "${YELLOW}Hashing client secret with Authelia's argon2id...${NC}"
echo "This may take a moment..."
HASHED_SECRET=$(docker run --rm authelia/authelia:latest \
    authelia crypto hash generate argon2 --password "$CLIENT_SECRET" 2>/dev/null | grep '^\$argon2id')

if [ -z "$HASHED_SECRET" ]; then
    echo -e "${RED}Error: Failed to generate hashed secret${NC}"
    exit 1
fi

echo -e "${GREEN}Generated hashed secret${NC}"
echo ""

# Create client file
echo -e "${YELLOW}Creating OIDC client configuration...${NC}"
cat > "$CLIENT_FILE" << EOF
- authorization_policy: 'two_factor'
  client_id: '\${OIDC_${SERVICE_UPPER}_CLIENT_ID}'
  client_name: '$DISPLAY_NAME'
  client_secret: '\${OIDC_${SERVICE_UPPER}_CLIENT_SECRET_DIGEST}'
  public: false
  redirect_uris:
    - '$REDIRECT_URI'
  scopes:
    - email
    - openid
    - profile
  token_endpoint_auth_method: 'client_secret_post'
  userinfo_signed_response_alg: 'none'
EOF

echo -e "${GREEN}Created client file at: ${NC}$CLIENT_FILE"
echo ""

# Display next steps
echo -e "${BLUE}=== Next Steps ===${NC}"
echo ""
echo -e "${YELLOW}1. Add these secrets to Infisical:${NC}"
echo ""
echo "   Secret Name: OIDC_${SERVICE_UPPER}_CLIENT_ID"
echo "   Secret Value: $SERVICE_NAME"
echo ""
echo "   Secret Name: OIDC_${SERVICE_UPPER}_CLIENT_SECRET_DIGEST"
echo "   Secret Value: $HASHED_SECRET"
echo ""
echo -e "${YELLOW}2. Add this line to config/oidc-clients.yml:${NC}"
echo ""
echo "   # $DISPLAY_NAME"
echo "   {{- fileContent \"/config/oidc.d/$SERVICE_NAME\" | expandenv | nindent 0 }}"
echo ""
echo -e "${YELLOW}3. Restart Authelia:${NC}"
echo ""
echo "   docker compose restart authelia"
echo ""
echo -e "${YELLOW}4. Configure the service with these OIDC settings:${NC}"
echo ""
echo "   Client ID: $SERVICE_NAME"
echo "   Client Secret: $CLIENT_SECRET"
echo "   Authorization URL: https://auth.yourdomain.com/api/oidc/authorization"
echo "   Token URL: https://auth.yourdomain.com/api/oidc/token"
echo "   Userinfo URL: https://auth.yourdomain.com/api/oidc/userinfo"
echo "   JWKS URL: https://auth.yourdomain.com/jwks.json"
echo "   Discovery URL: https://auth.yourdomain.com/.well-known/openid-configuration"
echo ""
echo -e "${GREEN}Done!${NC}"
