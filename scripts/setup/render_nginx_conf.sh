#!/usr/bin/env bash
set -euo pipefail

# --- render_nginx_conf.sh ---
# This script renders the Nginx configuration template using variables
# from a specified .env file.

# --- Argument Validation ---
if [ "$#" -ne 2 ]; then
    echo "[FATAL] Usage: $0 <path_to_nginx_conf_dir> <path_to_env_file>" >&2
    exit 1
fi

NGINX_CONF_DIR="$1"
ENV_FILE="$2"

# --- Path Validation ---
if [ ! -d "$NGINX_CONF_DIR" ]; then
    echo "[FATAL] Nginx config directory not found: $NGINX_CONF_DIR" >&2
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "[FATAL] Environment file not found: $ENV_FILE" >&2
    exit 1
fi

# --- Rendering Logic ---
for NGINX_CONF_TPL in "$NGINX_CONF_DIR"/nginx-*.conf.tpl; do
    [ -e "$NGINX_CONF_TPL" ] || { echo "[WARN] No nginx config templates found in $NGINX_CONF_DIR, skipping rendering."; exit 0; }
    NGINX_CONF_OUT="${NGINX_CONF_TPL%.tpl}"
    echo "[INFO] Rendering Nginx configuration from $NGINX_CONF_TPL to $NGINX_CONF_OUT..."
    # Source the .env file to make variables available for envsubst
    set -a
    source "$ENV_FILE"
    set +a
    # Only substitute allowed variables to avoid clobbering Nginx runtime vars like $uri, $host, etc.
    ALLOWED_VARS='${N8N_HOST}${LETSENCRYPT_DOMAIN}'
    envsubst "$ALLOWED_VARS" < "$NGINX_CONF_TPL" > "$NGINX_CONF_OUT"
    echo "[SUCCESS] Rendered $NGINX_CONF_OUT"
done
