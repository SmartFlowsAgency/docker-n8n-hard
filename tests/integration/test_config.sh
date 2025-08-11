#!/bin/bash
set -e

# Integration test for configuration validation
# This test runs from within the artifact and validates docker-compose config

# Robustly determine artifact root - default to build/ directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACT_ROOT="${1:-$PROJECT_ROOT/build}"

echo "[DEBUG] SCRIPT_DIR: $SCRIPT_DIR"
echo "[DEBUG] PROJECT_ROOT: $PROJECT_ROOT"
echo "[DEBUG] ARTIFACT_ROOT: $ARTIFACT_ROOT"
echo "[DEBUG] Before cd: $(pwd)"

echo "=== Integration Test: Configuration ==="
echo "Testing artifact configuration in: $ARTIFACT_ROOT"

# Ensure we're working in the artifact directory
if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "ERROR: Artifact directory $ARTIFACT_ROOT not found"
    exit 1
fi

cd "$ARTIFACT_ROOT"
echo "[DEBUG] After cd: $(pwd)"

# Inject required env variables for non-interactive setup
export LETSENCRYPT_DOMAIN="test.local"
export N8N_HOST="test.local"
export LETSENCRYPT_EMAIL="test@example.com"
export POSTGRES_PASSWORD="testpw"
export N8N_AUTH_USER="testuser"
export N8N_AUTH_PASSWORD="testpass"
export N8N_ENCRYPTION_KEY="testkey1234567890testkey1234567890"
export N8N_EDITOR_BASE_URL="http://test.local:5678/"

# Run setup first to ensure env files exist
echo "Running setup to prepare environment..."
chmod +x scripts/setup.sh
./scripts/setup.sh .

# Copy env/.env to .env for docker-compose compatibility
if [ -f "env/.env" ]; then
    cp env/.env .env
fi

# Print working directory and check for docker-compose.yml before running config
pwd
ls -l
echo "[DEBUG] Looking for docker-compose.yml in: $(pwd)"
if [ ! -f docker-compose.yml ]; then
    echo "[ERROR] docker-compose.yml not found in $(pwd)" >&2
    exit 2
fi

# Validate docker-compose configuration
echo "Validating docker-compose configuration..."
docker-compose config
config_status=$?
if [ $config_status -ne 0 ]; then
    echo "ERROR: docker-compose config validation failed"
    echo "--- docker-compose config output ---"
    docker-compose config
    echo "--- END ---"
    exit 1
fi

echo "✓ Configuration integration test passed"
