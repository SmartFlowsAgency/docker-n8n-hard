#!/bin/bash
echo "[DEBUG] Starting test_integration.sh"
# Artifact/Integration Test: Docker services and connectivity
set -e

ARTIFACT_ROOT="${1:-dist}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_PATH="$PROJECT_ROOT/$ARTIFACT_ROOT"

TEST_DIR="/tmp/n8n_integration_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Copy entire artifact for integration testing
cp -r "$ARTIFACT_PATH"/* .

# Always run setup to ensure env files and configs are present
chmod +x dn8nh.sh scripts/*.sh
./dn8nh.sh setup --non-interactive

# Create minimal .env for testing
cat > .env <<EOF
N8N_HOST=localhost
POSTGRES_PASSWORD=testpass123
LETSENCRYPT_EMAIL=test@example.com
N8N_ENCRYPTION_KEY=testkey123456789012345678901234
N8N_AUTH_USER=admin
N8N_AUTH_PASSWORD=testpass123
EOF

cleanup() {
    echo "Cleaning up containers..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    cd /
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test: Services can start without errors
test_services_start() {
    echo "Testing: Services start successfully..."
    
    # Start only core services (skip cert-init for testing)
    docker-compose up -d n8n-postgres n8n-hard 2>/dev/null || {
        echo "FAIL: Services failed to start"
        docker-compose logs
        exit 1
    }
    
    # Wait for services to be healthy
    local count=0
    local timeout=60
    while [ $count -lt $timeout ]; do
        if docker-compose ps | grep -q "Up.*healthy"; then
            echo "PASS: Services started successfully"
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    
    echo "FAIL: Services did not become healthy within $timeout seconds"
    docker-compose logs
    exit 1
}

# Test: Database connectivity
test_database_connectivity() {
    echo "Testing: Database connectivity..."
    
    # Check if postgres is accepting connections
    docker-compose exec -T n8n-postgres pg_isready -U n8n 2>/dev/null || {
        echo "FAIL: PostgreSQL is not ready"
        exit 1
    }
    
    echo "PASS: Database connectivity verified"
}

# Skip Docker tests if Docker is not available
if ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: Docker not available, skipping integration tests"
    exit 0
fi

if ! docker info >/dev/null 2>&1; then
    echo "SKIP: Docker daemon not running, skipping integration tests"
    exit 0
fi

test_services_start
test_database_connectivity

echo "[PASS] integration test from $ARTIFACT_ROOT"
