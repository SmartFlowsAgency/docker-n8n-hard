#!/usr/bin/env bash
set -euxo pipefail

# === Integration Test: Setup ===
# This test validates the end-to-end artifact setup process.

# --- Test Setup ---
echo "[DEBUG] SCRIPT START"
echo "[DEBUG] PWD: $(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[DEBUG] SCRIPT_DIR: $SCRIPT_DIR"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$SCRIPT_DIR/../../build}"
echo "[DEBUG] ARTIFACT_ROOT: $ARTIFACT_ROOT"
: "${LOG_LEVEL:=2}"
echo "[DEBUG] LOG_LEVEL: $LOG_LEVEL"
TMP_ARTIFACT_DIR="$(mktemp -d)"
echo "[DEBUG] TMP_ARTIFACT_DIR: $TMP_ARTIFACT_DIR"

log() {
  local level=$1; shift
  local msg=$*
  case $level in
    ERROR) [ "$LOG_LEVEL" -ge 0 ] && echo "[ERROR] $msg" ;;
    WARN)  [ "$LOG_LEVEL" -ge 1 ] && echo "[WARN] $msg" ;;
    INFO)  [ "$LOG_LEVEL" -ge 2 ] && echo "[INFO] $msg" ;;
    DEBUG) [ "$LOG_LEVEL" -ge 3 ] && echo "[DEBUG] $msg" ;;
  esac
}

echo "[DEBUG] Setting trap for cleanup"
cleanup() {
    echo "[DEBUG] Cleaning up temporary artifact directory..."
    rm -rf "$TMP_ARTIFACT_DIR"
}
trap cleanup EXIT

echo "[DEBUG] === Integration Test: Setup ==="
echo "[DEBUG] Testing artifact setup process in: $TMP_ARTIFACT_DIR"


# 1. Prepare the test artifact by copying from the current artifact
echo "[DEBUG] Checking source artifact directories before copy..."
if [ -d "$ARTIFACT_ROOT/env/" ]; then
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/env/ exists. Listing contents:"
  ls -la "$ARTIFACT_ROOT/env/"
else
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/env/ does not exist."
fi
if [ -d "$ARTIFACT_ROOT/scripts" ]; then
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/scripts exists. Listing contents:"
  ls -la "$ARTIFACT_ROOT/scripts"
else
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/scripts does not exist."
fi
if [ -d "$ARTIFACT_ROOT/nginx-conf" ]; then
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/nginx-conf exists. Listing contents:"
  ls -la "$ARTIFACT_ROOT/nginx-conf"
else
  echo "[DEBUG] Source artifact $ARTIFACT_ROOT/nginx-conf does not exist."
fi

echo "[DEBUG] Copying scripts..."
cp -vr "$ARTIFACT_ROOT/scripts" "$TMP_ARTIFACT_DIR/" || { echo "[ERROR] Failed to copy scripts"; exit 1; }
echo "[DEBUG] Copying env..."
cp -av "$ARTIFACT_ROOT/env/." "$TMP_ARTIFACT_DIR/env/" || { echo "[ERROR] Failed to copy env"; exit 1; }
echo "[DEBUG] Copying nginx-conf..."
cp -vr "$ARTIFACT_ROOT/nginx-conf" "$TMP_ARTIFACT_DIR/" || { echo "[ERROR] Failed to copy nginx-conf"; exit 1; }

echo "[DEBUG] Listing TMP_ARTIFACT_DIR after copy:"
ls -la "$TMP_ARTIFACT_DIR"
ls -la "$TMP_ARTIFACT_DIR/env/"
ls -la "$TMP_ARTIFACT_DIR/scripts/"
ls -la "$TMP_ARTIFACT_DIR/nginx-conf/"

set +x

echo "[DEBUG] Beginning overlay phase"
echo "[DEBUG] About to inject overlay 1"
cat <<EOF >> "$TMP_ARTIFACT_DIR/env/.env"
N8N_EDITOR_BASE_URL=http://localhost:5678
N8N_HOST=localhost
POSTGRES_PASSWORD=test_pw
POSTGRES_USER=test_user
POSTGRES_DB=test_db
EOF
echo "[DEBUG] After overlay 1 injection"
ls -la "$TMP_ARTIFACT_DIR/env/"

echo "[DEBUG] About to inject overlay 2 (user-provided .env)"
cat >> "$TMP_ARTIFACT_DIR/env/.env" <<EOF
EOF
echo "[DEBUG] After overlay 2 injection"
ls -la "$TMP_ARTIFACT_DIR/env/"

echo "[DEBUG] About to inject overlay 3 (test overlay .env)"
cat > "$TMP_ARTIFACT_DIR/env/.env" << 'EOF'
LETSENCRYPT_DOMAIN=test.local
N8N_HOST=test.local
LETSENCRYPT_EMAIL=test@example.com
POSTGRES_PASSWORD=testpw
N8N_AUTH_USER=testuser
N8N_AUTH_PASSWORD=testpass
N8N_ENCRYPTION_KEY=testkey1234567890testkey1234567890
N8N_EDITOR_BASE_URL=http://test.local:5678/
EOF
echo "[DEBUG] After overlay 3 injection"
ls -la "$TMP_ARTIFACT_DIR/env/"

echo "[DEBUG] About to cd into TMP_ARTIFACT_DIR"
cd "$TMP_ARTIFACT_DIR" || { echo "[ERROR] Failed to cd into TMP_ARTIFACT_DIR"; exit 1; }
echo "[DEBUG] After cd, about to chmod scripts/setup.sh"
chmod +x scripts/setup.sh || { echo "[ERROR] Failed to chmod setup.sh"; exit 1; }
echo "[DEBUG] After chmod, about to run setup.sh"
if ! ./scripts/setup.sh --no-interactive --preserve-templates; then
    echo "[ERROR] setup.sh failed with exit code $?"
    exit 1
fi
echo "[DEBUG] After running setup.sh"
ls -l "$TMP_ARTIFACT_DIR/env/"
ls -l "$TMP_ARTIFACT_DIR/scripts/"
ls -l "$TMP_ARTIFACT_DIR/nginx-conf/"
echo "[DEBUG] About to validate setup results"

# 3. Validate the results
echo "Validating setup results..."
ls -l "$TMP_ARTIFACT_DIR/env/"
ls -l "$TMP_ARTIFACT_DIR/scripts/"
ls -l "$TMP_ARTIFACT_DIR/nginx-conf/"
echo "[DEBUG] Checking that rendered .env files exist"
for f in "$TMP_ARTIFACT_DIR/env/.env.n8n" "$TMP_ARTIFACT_DIR/env/.env.postgres"; do
    if [ ! -f "$f" ]; then
        echo "[ERROR] Rendered env file $f was not created. Directory listing:"
        ls -la "$TMP_ARTIFACT_DIR/env/"
        exit 1
    fi
    echo "[DEBUG] $f was created. Contents:" && cat "$f"
done

echo "[DEBUG] Checking that Nginx config was rendered"
ls -l "$TMP_ARTIFACT_DIR/nginx-conf/"
found_nginx_conf=0
for f in "$TMP_ARTIFACT_DIR/nginx-conf"/nginx-*.conf; do
  if [ -f "$f" ]; then
    echo "[DEBUG] Found nginx conf: $f"
    found_nginx_conf=1
  fi
done
if [ "$found_nginx_conf" -eq 0 ]; then
  echo "[ERROR] Nginx config was not rendered. Directory listing:"
  ls -la "$TMP_ARTIFACT_DIR/nginx-conf/"
  exit 1
fi

echo "[DEBUG] Checking content of rendered .env.n8n file"
ENV_N8N_FILE="$TMP_ARTIFACT_DIR/env/.env.n8n"
echo "[DEBUG] .env.n8n content:" && cat "$ENV_N8N_FILE"
if ! grep -q "N8N_HOST=test.local" "$ENV_N8N_FILE"; then
    echo "[ERROR] N8N_HOST was not correctly set from the overlay. Actual content:" && cat "$ENV_N8N_FILE"
    exit 1
fi
if ! grep -q "POSTGRES_PASSWORD=.*" "$ENV_N8N_FILE"; then
    echo "[ERROR] POSTGRES_PASSWORD was not generated. Actual content:" && cat "$ENV_N8N_FILE"
    exit 1
fi
echo "[DEBUG] .env.n8n contains correct values."
echo "[DEBUG] End of script, cleanup follows."
echo "-----------------------------"
echo "SUCCESS: Setup integration test passed."
