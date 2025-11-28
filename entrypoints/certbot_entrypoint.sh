#!/usr/bin/env bash
set -eu

# --- Cleanup Function ---
# Ensures the temporary nginx container is stopped when this script exits.
cleanup() {
    echo "[certbot] Cleaning up..."
    # The project name is set in the calling script (certbot_build.sh)
    local project_name="${COMPOSE_PROJECT_NAME:-dn8nh-default}"
    local nginx_container="${project_name}-nginx-certbot-1"

    echo "[certbot] Stopping temporary nginx container: $nginx_container"
    docker stop "$nginx_container" >/dev/null 2>&1 || echo "[certbot] Nginx container not found or already stopped."
}
trap cleanup EXIT


# Inputs from env file
export LETSENCRYPT_EMAIL
CERTBOT_STAGING=${CERTBOT_STAGING:-false}
CERTBOT_DRY_RUN=${CERTBOT_DRY_RUN:-false}

# Back-compat: prefer N8N_HOST, but fall back to LETSENCRYPT_DOMAIN from env file
if [ "${N8N_HOST:-}" = "" ] && [ "${LETSENCRYPT_DOMAIN:-}" != "" ]; then
  N8N_HOST="$LETSENCRYPT_DOMAIN"
  export N8N_HOST
fi

echo "[certbot] Host: $N8N_HOST"
echo "[certbot] Email: $LETSENCRYPT_EMAIL"
echo "[certbot] Staging: $CERTBOT_STAGING | Dry run: $CERTBOT_DRY_RUN"

CERT_PATH="/etc/letsencrypt/live/$N8N_HOST/fullchain.pem"
if [ -f "$CERT_PATH" ]; then
  echo "[certbot] Certificate already exists at $CERT_PATH, skipping certbot."
  CERT_OBTAINED=true
else
  echo "[certbot] Requesting certificate for $N8N_HOST ..."
  flags=""
  if [ "$CERTBOT_STAGING" = "true" ]; then
    flags="$flags --staging"
  fi
  if [ "$CERTBOT_DRY_RUN" = "true" ]; then
    flags="$flags --dry-run"
  fi

  set +e
  sh -c "certbot certonly --webroot --webroot-path=/var/www/certbot \
    --email \"$LETSENCRYPT_EMAIL\" --agree-tos --no-eff-email \
    -d \"$N8N_HOST\" $flags"
  rc=$?
  set -e
  if [ $rc -eq 0 ]; then
    CERT_OBTAINED=true
    echo "[certbot] Certificate obtain step reported success."
  else
    CERT_OBTAINED=false
    echo "[certbot] ERROR: certbot exited with code $rc"
  fi
fi

if [ "${CERT_OBTAINED:-false}" = "true" ]; then
  echo "[certbot] Certificate obtained successfully. Exiting to trigger cleanup."
  exit 0
else
  echo "[certbot] Certificate not obtained. Exiting with error."
  exit 1
fi