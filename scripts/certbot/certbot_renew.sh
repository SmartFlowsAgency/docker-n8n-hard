#!/usr/bin/env bash
set -euo pipefail

echo "Renewing SSL certificates (Let's Encrypt)..."

# Use the cert-init profile to provide webroot and shared volumes
export COMPOSE_PROFILES=cert-init
# Use dn8nh-{instance} as Compose project name for consistent container prefixes
export COMPOSE_PROJECT_NAME="dn8nh-${DN8NH_INSTANCE_NAME:-default}"

# Run certbot renew inside the certbot container context
# Using webroot to satisfy http-01 challenges via the shared tmpfs
docker compose run --rm \
  -e N8N_HOST \
  -e LETSENCRYPT_EMAIL \
  -e CERTBOT_STAGING \
  -e CERTBOT_DRY_RUN \
  certbot sh -lc 'certbot renew --webroot --webroot-path=/var/www/certbot || true'

# Attempt to reload production nginx if it is running
if container_id=$(docker compose ps -q nginx-rproxy 2>/dev/null) && [ -n "$container_id" ]; then
  echo "Reloading nginx to pick up renewed certificates..."
  docker compose exec -T nginx-rproxy nginx -s reload || {
    echo "Reload failed, attempting restart...";
    docker compose restart nginx-rproxy || true;
  }
fi

echo "Certificate renewal process completed."

