#!/usr/bin/env bash
set -e

echo "Building configs and obtaining SSL certificates..."
echo "This will start temporary nginx and certbot containers."
echo ""
echo "Note: Your domain must point to this server for SSL certificates to work."
echo "Domain: ${N8N_HOST:-not set}"
echo ""
# Ensure only the cert-init profile is active for this step
export COMPOSE_PROFILES=cert-init
# Proactively remove any previous cert-init containers
docker compose rm -sf n8n-nginx-certbot n8n-certbot || true
docker compose up --abort-on-container-exit n8n-hard_permissions-init n8n-nginx-certbot n8n-certbot
echo ""
echo "Build completed. Check above output for any certificate errors."
echo "If certificates were obtained successfully, you can now run './dn8nh.sh deploy'"
