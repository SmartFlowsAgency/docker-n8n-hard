#!/usr/bin/env bash
#
# Clean deployment script - removes all containers, networks, and optionally volumes
#

set -euo pipefail

# Change to project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Clean up n8n hardened deployment resources.

Options:
  --volumes, -v     Also remove volumes (WARNING: This will delete all data!)
  --all, -a         Remove everything including volumes and orphaned containers
  --help, -h        Show this help message

Examples:
  $0                # Remove containers and networks only
  $0 --volumes      # Remove containers, networks, and volumes
  $0 --all          # Complete cleanup including orphaned containers

EOF
}

clean_containers_and_networks() {
    log_step "Stopping and removing containers and networks..."
    
    # Stop and remove all services
    if docker-compose ps -q | grep -q .; then
        log_info "Stopping running services..."
        docker-compose down --remove-orphans
    else
        log_info "No running services found"
    fi
    
    # Remove any leftover containers manually
    local containers=("n8n-hard_permissions-init" "n8n-hard" "n8n-postgres" "n8n-hard-nginx-prod" "n8n-nginx-certbot" "n8n-certbot")
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
            log_info "Removing leftover container: $container"
            docker rm -f "$container" 2>/dev/null || true
        fi
    done
    
    # Clean up networks
    log_info "Cleaning up networks..."
    docker network ls --format '{{.Name}}' | grep -E '^(src_|n8n)' | while read -r netname; do
        if [ -n "$netname" ] && [ "$netname" != "bridge" ] && [ "$netname" != "host" ] && [ "$netname" != "none" ]; then
            log_info "Removing network: $netname"
            docker network rm "$netname" 2>/dev/null || true
        fi
    done
}

clean_volumes() {
    log_step "Removing volumes..."
    
    # Get volume names from docker-compose
    local volumes
    volumes=$(docker-compose config --volumes 2>/dev/null || echo "")
    
    if [ -n "$volumes" ]; then
        echo "$volumes" | while read -r volume; do
            if [ -n "$volume" ]; then
                # Try to find the actual volume name (may be prefixed)
                local actual_volume
                actual_volume=$(docker volume ls --format '{{.Name}}' | grep "$volume" | head -1 || echo "")
                
                if [ -n "$actual_volume" ]; then
                    log_warn "Removing volume: $actual_volume"
                    docker volume rm "$actual_volume" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # Also remove any volumes that match our patterns
    docker volume ls --format '{{.Name}}' | grep -E '^(src_|n8n)' | while read -r volume; do
        if [ -n "$volume" ]; then
            log_warn "Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        fi
    done
}

clean_orphaned_resources() {
    log_step "Cleaning up orphaned Docker resources..."
    
    # Remove orphaned containers
    log_info "Removing orphaned containers..."
    docker container prune -f 2>/dev/null || true
    
    # Remove orphaned networks
    log_info "Removing orphaned networks..."
    docker network prune -f 2>/dev/null || true
    
    # Remove orphaned volumes
    log_info "Removing orphaned volumes..."
    docker volume prune -f 2>/dev/null || true
    
    # Remove orphaned images
    log_info "Removing orphaned images..."
    docker image prune -f 2>/dev/null || true
}

main() {
    local remove_volumes=false
    local clean_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --volumes|-v)
                remove_volumes=true
                shift
                ;;
            --all|-a)
                remove_volumes=true
                clean_all=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_step "Starting cleanup of n8n hardened deployment..."
    
    # Confirm if removing volumes
    if [ "$remove_volumes" = true ]; then
        log_warn "⚠️  WARNING: This will remove all volumes and delete your data!"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
    
    # Clean containers and networks
    clean_containers_and_networks
    
    # Clean volumes if requested
    if [ "$remove_volumes" = true ]; then
        clean_volumes
    fi
    
    # Clean orphaned resources if requested
    if [ "$clean_all" = true ]; then
        clean_orphaned_resources
    fi
    
    log_step "Cleanup completed!"
    
    if [ "$remove_volumes" = true ]; then
        log_info "🧹 Complete cleanup finished. All data has been removed."
        log_info "Run './dn8nh.sh setup' to reconfigure before deploying again."
    else
        log_info "🧹 Containers and networks cleaned up. Volumes preserved."
        log_info "Run './dn8nh.sh deploy' to start fresh deployment."
    fi
}

main "$@"
