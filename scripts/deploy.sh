#!/usr/bin/env bash
#
# Deployment script for the n8n-hardened stack.
# This script orchestrates the startup sequence based on docker-compose.yml logic.
#

set -euo pipefail

# --- Configuration & Colors ---

# Change to the project root directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Ensure the correct Compose profile is active for services that declare profiles: ["prod"]
# Allow override via environment, but default to 'prod' for predictable behavior.
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-prod}"

# Load all env files from env/ directory
ENV_DIR="env"
if [ -d "$ENV_DIR" ]; then
    for envfile in "$ENV_DIR"/.env*; do
        [ -f "$envfile" ] || continue
        set -a
        source "$envfile"
        set +a
    done
else
    echo "ERROR: $ENV_DIR directory not found. Please run './dn8nh.sh setup' first."
    exit 1
fi

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
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

# --- Cleanup Functions ---

# Remove networks using conflicting subnets
remove_conflicting_subnet_networks() {
    local subnets=("172.20.0.0/24" "192.168.100.0/24")
    
    log_step "Checking for conflicting Docker networks..."
    
    for subnet in "${subnets[@]}"; do
        # Get networks using this subnet
        local conflicting_networks
        conflicting_networks=$(docker network ls --format "{{.ID}}" | xargs -I {} sh -c 'docker network inspect {} --format "{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>/dev/null || true' | grep "$subnet" | cut -d' ' -f1 || true)
        
        if [ -n "$conflicting_networks" ]; then
            log_warn "Found networks using conflicting subnet $subnet"
            echo "$conflicting_networks" | while read -r netname; do
                if [ -n "$netname" ]; then
                    log_info "Attempting to remove conflicting network: $netname"
                    if ! docker network rm "$netname" 2>/dev/null; then
                        log_error "Network $netname could not be removed. Attempting to force-remove attached containers."
                        # List and force-remove all containers attached to this network
                        attached_containers=$(docker network inspect "$netname" --format '{{range $k,$v := .Containers}}{{$v.Name}} {{end}}' 2>/dev/null)
                        for cname in $attached_containers; do
                            if [ -n "$cname" ]; then
                                log_info "Force-removing container $cname from network $netname"
                                docker rm -f "$cname" 2>/dev/null || true
                            fi
                        done
                        # Retry network removal
                        if docker network rm "$netname" 2>/dev/null; then
                            log_info "Successfully removed network $netname after force-removing containers."
                        else
                            log_error "Still failed to remove network $netname after removing containers. Manual intervention may be required."
                        fi
                    else
                        log_info "Successfully removed network: $netname"
                    fi
                fi
            done
        else
            log_info "No conflicting networks found for subnet $subnet"
        fi
    done
}

# Remove containers that would conflict with deployment
cleanup_conflicting_containers() {
    log_step "Cleaning up conflicting containers..."
    
    # Get actual container names from docker-compose
    local containers=("n8n-hard_permissions-init" "n8n-hard" "n8n-postgres" "n8n-hard-nginx-prod" "n8n-nginx-certbot" "n8n-certbot")
    
    for cname in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$cname$"; then
            log_info "Removing old container: $cname"
            docker rm -f "$cname" 2>/dev/null || true
        fi
    done
}

# Cleanup leftover Docker networks from previous runs
cleanup_n8n_networks() {
    log_step "Cleaning up leftover n8n networks..."
    
    # Remove networks that start with the project name or contain 'n8n'
    local networks_to_remove
    networks_to_remove=$(docker network ls --format '{{.Name}}' | grep -E '^(src_|n8n)' || true)
    
    if [ -n "$networks_to_remove" ]; then
        echo "$networks_to_remove" | while read -r netname; do
            if [ -n "$netname" ] && [ "$netname" != "bridge" ] && [ "$netname" != "host" ] && [ "$netname" != "none" ]; then
                log_info "Removing network: $netname"
                docker network rm "$netname" 2>/dev/null || true
            fi
        done
    else
        log_info "No n8n networks to clean up"
    fi
}

# --- Health Check Functions ---

wait_for_container_status() {
    local container_name="$1"
    local expected_status="$2"
    local timeout="${3:-300}"  # 5 minutes default
    local interval=5
    local elapsed=0
    
    log_info "Waiting for $container_name to reach status: $expected_status"
    
    while [ $elapsed -lt $timeout ]; do
        local status
        status=$(docker inspect "$container_name" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")
        
        if [ "$status" = "$expected_status" ]; then
            log_info "✓ $container_name is $expected_status"
            return 0
        elif [ "$status" = "not_found" ]; then
            log_error "Container $container_name not found"
            return 1
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "Timeout waiting for $container_name to reach $expected_status"
    return 1
}

wait_for_service_healthy() {
    local service_name="$1"
    local timeout="${2:-300}"  # 5 minutes default
    local interval=10
    local elapsed=0
    
    log_info "Waiting for $service_name to become healthy..."
    
    while [ $elapsed -lt $timeout ]; do
        local health_status
        health_status=$(docker-compose ps -q "$service_name" | xargs -I {} docker inspect {} --format '{{.State.Health.Status}}' 2>/dev/null || echo "no_healthcheck")
        
        case "$health_status" in
            "healthy")
                log_info "✓ $service_name is healthy"
                return 0
                ;;
            "unhealthy")
                log_error "$service_name is unhealthy"
                docker-compose logs --tail=20 "$service_name"
                return 1
                ;;
            "starting"|"no_healthcheck")
                echo -n "."
                ;;
            *)
                log_warn "$service_name health status: $health_status"
                ;;
        esac
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "Timeout waiting for $service_name to become healthy"
    docker-compose logs --tail=20 "$service_name"
    return 1
}

# --- Pre-deployment Checks ---

check_prerequisites() {
    # Temporarily disabled: always return success
    return 0
}

# --- Main Deployment Logic ---

deploy_stack() {
    log_step "Starting hardened n8n deployment..."
    
    # Step 1: Pull latest images
    log_step "(1/5) Pulling latest Docker images..."
    if ! docker-compose pull; then
        log_error "Failed to pull Docker images"
        exit 1
    fi
    
    # Step 2: Run the permissions init container
    log_step "(2/5) Setting up volume permissions..."
    if ! docker-compose up --no-deps n8n-hard_permissions-init; then
        log_error "Failed to run permissions init container"
        exit 1
    fi
    
    # Wait for init container to complete
    if ! wait_for_container_status "n8n-hard_permissions-init" "exited" 60; then
        log_error "Permissions init container failed"
        exit 1
    fi
    
    # Step 3: Start PostgreSQL
    log_step "(3/5) Starting PostgreSQL database..."
    if ! docker-compose up -d n8n-postgres; then
        log_error "Failed to start PostgreSQL"
        exit 1
    fi
    
    # Wait for PostgreSQL to be healthy
    if ! wait_for_service_healthy "n8n-postgres" 120; then
        log_error "PostgreSQL failed to become healthy"
        exit 1
    fi
    
    # Step 4: Start n8n application
    log_step "(4/5) Starting n8n application..."
    if ! docker-compose up -d n8n-hard; then
        log_error "Failed to start n8n"
        exit 1
    fi
    
    # Wait for n8n to be healthy
    if ! wait_for_service_healthy "n8n-hard" 180; then
        log_error "n8n failed to become healthy"
        exit 1
    fi
    
    # Step 5: Start nginx reverse proxy
    log_step "(5/5) Starting nginx reverse proxy..."
    if ! docker-compose up -d n8n-hard-nginx-prod; then
        log_error "Failed to start nginx"
        exit 1
    fi
    
    # Wait for nginx to be healthy
    if ! wait_for_service_healthy "n8n-hard-nginx-prod" 60; then
        log_error "nginx failed to become healthy"
        exit 1
    fi
    
    # Final status check
    log_step "Deployment completed successfully!"
    echo
    log_info "🎉 Your hardened n8n instance is now running!"
    log_info "🌐 Access URL: https://${N8N_HOST}"
    log_info "👤 Username: ${N8N_AUTH_USER}"
    log_info "🔑 Password: (check .env file)"
    echo
    log_info "Service status:"
    docker-compose ps
}

# --- Error Handling ---

cleanup_on_error() {
    log_error "Deployment failed. Cleaning up..."
    docker-compose down --remove-orphans 2>/dev/null || true
    exit 1
}

# Set up error handling
trap cleanup_on_error ERR

# --- Main Execution ---

main() {
    log_step "Starting n8n hardened deployment process..."
    
    # Run cleanup
    remove_conflicting_subnet_networks
    cleanup_conflicting_containers
    cleanup_n8n_networks
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy the stack
    deploy_stack
}

# Execute main function
main "$@"
