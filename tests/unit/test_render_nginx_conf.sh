#!/usr/bin/env bash
set -euo pipefail

# === Unit Test: Nginx Config Rendering ===

# --- Test Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repo root robustly
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Prefer scripts/build path; fallback to src/scripts
RENDER_SCRIPT="$PROJECT_ROOT/scripts/build/render_nginx_conf.sh"
if [ ! -f "$RENDER_SCRIPT" ]; then
  RENDER_SCRIPT="$PROJECT_ROOT/src/scripts/render_nginx_conf.sh"
fi

if [ ! -f "$RENDER_SCRIPT" ]; then
  echo "[FAIL] Could not locate render_nginx_conf.sh under scripts/build or src/scripts. Checked at: $PROJECT_ROOT"
  exit 1
fi

# Create a temporary directory for the test
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Test Execution ---
echo "=== Unit Test: render_nginx_conf.sh ==="

# 1. Prepare test files
# Create a dummy .env file
cat > "$TMP_DIR/.env.test" <<EOF
N8N_HOST=test.n8n.local
LETSENCRYPT_EMAIL=test@example.com
EOF

# Create a dummy nginx template (must match nginx-*.conf.tpl pattern)
mkdir -p "$TMP_DIR/nginx-conf"
cat > "$TMP_DIR/nginx-conf/nginx-n8n.conf.tpl" <<EOF
server {
    listen 80;
    server_name \${N8N_HOST};

    location / {
        proxy_pass http://n8n:5678;
    }
}
EOF

# 2. Run the script
echo "Running render script..."
bash "$RENDER_SCRIPT" "$TMP_DIR/nginx-conf" "$TMP_DIR/.env.test"

# 3. Validate the results
echo "Validating results..."

# Check that the output file was created
OUT_FILE="$TMP_DIR/nginx-conf/nginx-n8n.conf"
if [ ! -f "$OUT_FILE" ]; then
    echo "[FAIL] Output file $OUT_FILE was not created."
    exit 1
fi
echo "[PASS] Output file was created."

# Note: renderer does not remove template files; ensure it remains for re-runs
TPL_FILE="$TMP_DIR/nginx-conf/nginx-n8n.conf.tpl"
if [ -f "$TPL_FILE" ]; then
    echo "[PASS] Template file remains as expected."
else
    echo "[FAIL] Template file $TPL_FILE should remain but was removed."
    exit 1
fi

# Check the content of the rendered file
if ! grep -q "server_name test.n8n.local;" "$OUT_FILE"; then
    echo "[FAIL] N8N_HOST was not correctly substituted in the output file."
    exit 1
fi
echo "[PASS] Nginx config was rendered with correct values."

echo "-------------------------------------"
echo "SUCCESS: Nginx render unit test passed."
