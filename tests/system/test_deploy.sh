#!/bin/bash
set -e

# System test for full deployment - validates end-to-end deployment process
# This test runs from within the artifact and validates complete deployment

# Robustly determine artifact root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACT_ROOT="${1:-$PROJECT_ROOT}"

echo "=== System Test: Deployment ==="
echo "Testing full deployment in: $ARTIFACT_ROOT"

# Ensure we're working in the artifact directory
if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "ERROR: Artifact directory $ARTIFACT_ROOT not found"
    exit 1
fi

cd "$ARTIFACT_ROOT"

# Ensure scripts are executable
chmod +x scripts/setup.sh scripts/deploy.sh dn8nh.sh

# Additional artifact integrity and management checks (merged from top-level test_deploy.sh)

# Test 1: Deploy script exists and is executable
if [ ! -f "scripts/deploy.sh" ]; then
    echo "FAIL: scripts/deploy.sh does not exist"; exit 1; fi
if [ ! -x "scripts/deploy.sh" ]; then
    echo "FAIL: scripts/deploy.sh is not executable"; exit 1; fi

echo "PASS: deploy.sh is present and executable"

# Test 2: Deploy script can validate environment (should fail without .env)
if [ -f ".env" ]; then mv .env .env.bak; fi
if ./scripts/deploy.sh 2>/dev/null; then
    echo "FAIL: deploy.sh should fail without .env"; 
    [ -f .env.bak ] && mv .env.bak .env
    exit 1
fi
[ -f .env.bak ] && mv .env.bak .env

echo "PASS: deploy.sh properly validates environment"

# Test 3: Management script exists and is executable
if [ ! -f "dn8nh.sh" ]; then
    echo "FAIL: dn8nh.sh does not exist"; exit 1; fi
if [ ! -x "dn8nh.sh" ]; then
    echo "FAIL: dn8nh.sh is not executable"; exit 1; fi
if ! ./dn8nh.sh --help >/dev/null 2>&1; then
    echo "FAIL: dn8nh.sh --help failed"; exit 1; fi

echo "PASS: dn8nh.sh management script present and working"

# Inject required env variables for non-interactive setup
export LETSENCRYPT_DOMAIN="test.local"
export N8N_HOST="test.local"
export LETSENCRYPT_EMAIL="test@example.com"
export POSTGRES_PASSWORD="testpw"
export N8N_AUTH_USER="testuser"
export N8N_AUTH_PASSWORD="testpass"
export N8N_ENCRYPTION_KEY="testkey1234567890testkey1234567890"
export N8N_EDITOR_BASE_URL="http://test.local:5678/"

# Run setup first
echo "Running setup..."
./scripts/setup.sh --no-interactive

# Copy env/.env to .env for deploy compatibility
if [ -f "env/.env" ]; then
    cp env/.env .env
fi

# Test deployment via main entry script
echo "Testing deployment via dn8nh.sh deploy..."
./dn8nh.sh deploy

# Wait for services to be ready
echo "Waiting for n8n service to be available..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -s http://localhost:5678 > /dev/null 2>&1; then
        echo "✓ n8n web UI is reachable"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

if [ $elapsed -ge $timeout ]; then
    echo "ERROR: n8n service not reachable after ${timeout}s"
    docker-compose logs
    exit 1
fi

# Cleanup
echo "Cleaning up deployment..."
docker-compose down

echo "✓ Deployment system test passed"
