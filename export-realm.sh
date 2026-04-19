#!/bin/bash

cd /home/usuario/Desktop/AGM-Dev/agm-keycloak

# Create realm-config directory
mkdir -p realm-config

# Get admin token
TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=admin&grant_type=password&client_id=admin-cli" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: $TOKEN"

# Export realm config
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/admin/realms/AGM \
  | python3 -m json.tool > realm-config/agm-realm.json

# Verify
echo "Export complete. First 50 lines:"
cat realm-config/agm-realm.json | head -50
