#!/usr/bin/env bash
set -euo pipefail

# --- setup.sh ---
# This script prepares the artifact for deployment.
# It renders .env templates, generates secrets, and validates configuration.

# --- Configuration & Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$ARTIFACT_DIR/env"
VARS_YAML="$ENV_DIR/vars.yaml"
SCRIPTS_DIR="$ARTIFACT_DIR/scripts"
RENDER_ENV_SH="$SCRIPTS_DIR/render_env.sh"
NGINX_CONF_TPL="$ARTIFACT_DIR/nginx.conf.tpl"

# Optionally allow override via environment variables
ENV_DIR="${ENV_DIR:-$ARTIFACT_DIR/env}"
VARS_YAML="${VARS_YAML:-$ENV_DIR/vars.yaml}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$ARTIFACT_DIR/scripts}"
RENDER_ENV_SH="${RENDER_ENV_SH:-$SCRIPTS_DIR/render_env.sh}"
NGINX_CONF_TPL="${NGINX_CONF_TPL:-$ARTIFACT_DIR/nginx.conf.tpl}"

echo "[DEBUG] Running setup.sh from: $0"
echo "[DEBUG] Initial ENV_DIR: $ENV_DIR"
echo "[DEBUG] (setup.sh) PWD at script start: $(pwd)"

check_path(){
  # Check if env/ exists and contains vars.yaml
  if [ ! -d "$ENV_DIR" ] || [ ! -f "$VARS_YAML" ]; then
    echo "[ERROR] This script must be run from the artifact directory, which must contain an 'env/' directory with 'vars.yaml'." >&2
    echo "Current ENV_DIR: $ENV_DIR" >&2
    echo "Current VARS_YAML: $VARS_YAML" >&2
    exit 2
  fi
}

render_env(){
  # --- Dependency Check ---
  if [ ! -f "$VARS_YAML" ]; then
    echo "[ERROR] vars.yaml not found in $ENV_DIR. This artifact is incomplete. Run the build process first to generate vars.yaml." >&2
    exit 2
  fi
  echo "[INFO] Checking for dependencies (yq)..."
  YQ_BIN="$ARTIFACT_DIR/bin/yq"
  if [ ! -x "$YQ_BIN" ] || [ ! -s "$YQ_BIN" ]; then
    echo "[INFO] Downloading yq to $YQ_BIN..."
    mkdir -p "$(dirname "$YQ_BIN")"
    wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O "$YQ_BIN"
    chmod +x "$YQ_BIN"
    if [ ! -x "$YQ_BIN" ] || [ ! -s "$YQ_BIN" ]; then
      echo "[ERROR] Failed to install yq"
      exit 2
    else
      echo "[INFO] yq installed at $YQ_BIN"
    fi
  else
    echo "[INFO] yq already present at $YQ_BIN"
  fi
  bash "$ARTIFACT_DIR/scripts/setup/render_env.sh" "$VARS_YAML"
}

render_nginx_conf(){
  echo "[INFO] Rendering Nginx configuration..."
  NGINX_CONF_DIR="$ARTIFACT_DIR/nginx-conf"
  # Use certbot env so N8N_HOST matches the certificate domain
  ENV_FILE="$ENV_DIR/.env.certbot"
  bash "$SCRIPTS_DIR/setup/render_nginx_conf.sh" "$NGINX_CONF_DIR" "$ENV_FILE"
}

obtain_initial_certs(){
  echo "[INFO] Obtaining initial SSL certificates (cert-init profile)..."
  # Ensure prod nginx is not running to avoid port 80 conflict
  if docker ps --filter "name=n8n-hard-nginx-prod" --format '{{.Names}}' | grep -q .; then
    echo "[ERROR] n8n-hard-nginx-prod is running. Stop it before obtaining certificates (port 80 is required)." >&2
    echo "Hint: run 'docker compose down' or './dn8nh.sh down' and re-run setup." >&2
    exit 1
  fi
  bash "$SCRIPTS_DIR/certbot/certbot_build.sh"
}

# --- Argument Parsing ---
NO_INTERACTIVE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-interactive)
      NO_INTERACTIVE="--no-interactive"
      shift
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      echo "Usage: $0 [--no-interactive]" >&2
      exit 1
      ;;
  esac
done

echo "[INFO] Starting artifact setup in: $ARTIFACT_DIR"

export PATH="$ARTIFACT_DIR/bin:$PATH"

# --- Render .env files directly from vars.yaml ---
render_env

# --- Ensure Docker Volumes Exist ---
echo "[INFO] Ensuring Docker volumes are created..."
bash "$SCRIPTS_DIR/setup/ensure_volumes.sh"

# --- Nginx Configuration Rendering ---
render_nginx_conf

# --- Obtain initial SSL certificates ---
obtain_initial_certs

echo "[SUCCESS] Artifact setup complete."