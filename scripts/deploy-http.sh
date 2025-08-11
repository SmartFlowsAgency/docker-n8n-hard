#!/usr/bin/env bash
#
# HTTP-only deployment script for testing without SSL certificates
#

set -euo pipefail

# Change to the project root directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "ERROR: .env file not found. Please run './dn8nh.sh setup' first."
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

log_step "Starting HTTP-only n8n deployment (for testing without SSL)..."

# Step 1: Run permissions init
log_step "(1/4) Setting up volume permissions..."
docker-compose up --no-deps n8n-hard_permissions-init
log_info "✓ Permissions set"

# Step 2: Start PostgreSQL
log_step "(2/4) Starting PostgreSQL database..."
docker-compose up -d n8n-postgres
log_info "✓ PostgreSQL started"

# Wait for PostgreSQL to be healthy
log_info "Waiting for PostgreSQL to be ready..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker-compose ps n8n-postgres | grep -q "(healthy)"; then
        log_info "✓ PostgreSQL is healthy"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    echo "ERROR: PostgreSQL failed to become healthy"
    exit 1
fi

# Step 3: Start n8n application
log_step "(3/4) Starting n8n application..."
docker-compose up -d n8n
log_info "✓ n8n started"

# Wait for n8n to be healthy
log_info "Waiting for n8n to be ready..."
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker-compose ps n8n | grep -q "(healthy)"; then
        log_info "✓ n8n is healthy"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    echo "ERROR: n8n failed to become healthy"
    docker-compose logs --tail=10 n8n
    exit 1
fi

# Step 4: Start HTTP-only nginx
log_step "(4/4) Starting HTTP-only nginx..."
docker run -d --name n8n-nginx-http \
    --network src_n8n-network \
    -p 8080:80 \
    -v "$(pwd)/nginx-conf/nginx-http.conf:/etc/nginx/nginx.conf:ro" \
    nginx:alpine

log_info "✓ HTTP nginx started on port 8080"

echo
log_info "🎉 HTTP-only deployment completed successfully!"
log_info "🌐 Access n8n at: http://localhost:8080 (or http://$(hostname -I | awk '{print $1}'):8080)"
log_info "👤 Username: ${N8N_AUTH_USER}"
log_info "🔑 Password: (check .env file)"
echo
log_info "Note: This is HTTP-only for testing. Use './dn8nh.sh build' then './dn8nh.sh deploy' for production SSL setup."
