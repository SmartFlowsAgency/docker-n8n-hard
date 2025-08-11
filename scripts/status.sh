#!/bin/bash
#
# Status monitoring script for n8n hardened deployment
#

set -euo pipefail

# Change to project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

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

check_service_status() {
    local service_name="$1"
    local container_id
    
    container_id=$(docker-compose ps -q "$service_name" 2>/dev/null || echo "")
    
    if [ -z "$container_id" ]; then
        echo -e "  ${RED}✗${NC} $service_name: Not running"
        return 1
    fi
    
    local status
    status=$(docker inspect "$container_id" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
    
    local health_status
    health_status=$(docker inspect "$container_id" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no_healthcheck")
    
    case "$status" in
        "running")
            case "$health_status" in
                "healthy")
                    echo -e "  ${GREEN}✓${NC} $service_name: Running (Healthy)"
                    return 0
                    ;;
                "unhealthy")
                    echo -e "  ${RED}✗${NC} $service_name: Running (Unhealthy)"
                    return 1
                    ;;
                "starting")
                    echo -e "  ${YELLOW}⚠${NC} $service_name: Running (Starting up...)"
                    return 0
                    ;;
                "no_healthcheck")
                    echo -e "  ${GREEN}✓${NC} $service_name: Running (No health check)"
                    return 0
                    ;;
                *)
                    echo -e "  ${YELLOW}?${NC} $service_name: Running ($health_status)"
                    return 0
                    ;;
            esac
            ;;
        "exited")
            local exit_code
            exit_code=$(docker inspect "$container_id" --format '{{.State.ExitCode}}' 2>/dev/null || echo "unknown")
            if [ "$exit_code" = "0" ]; then
                echo -e "  ${GREEN}✓${NC} $service_name: Completed successfully"
                return 0
            else
                echo -e "  ${RED}✗${NC} $service_name: Exited with code $exit_code"
                return 1
            fi
            ;;
        *)
            echo -e "  ${RED}✗${NC} $service_name: $status"
            return 1
            ;;
    esac
}

show_service_logs() {
    local service_name="$1"
    local lines="${2:-10}"
    
    log_step "Recent logs for $service_name:"
    docker-compose logs --tail="$lines" "$service_name" 2>/dev/null || log_warn "No logs available for $service_name"
}

check_connectivity() {
    log_step "Checking connectivity..."
    
    if [ -n "${N8N_HOST:-}" ]; then
        # Check if the domain resolves
        if command -v dig >/dev/null 2>&1; then
            local ip
            ip=$(dig +short "$N8N_HOST" | tail -n1)
            if [ -n "$ip" ]; then
                log_info "✓ Domain $N8N_HOST resolves to $ip"
            else
                log_warn "Domain $N8N_HOST does not resolve"
            fi
        fi
        
        # Check HTTP/HTTPS connectivity
        if command -v curl >/dev/null 2>&1; then
            if curl -s -o /dev/null -w "%{http_code}" "http://$N8N_HOST" | grep -q "^[23]"; then
                log_info "✓ HTTP connection to $N8N_HOST works"
            else
                log_warn "HTTP connection to $N8N_HOST failed"
            fi
            
            if curl -s -o /dev/null -w "%{http_code}" "https://$N8N_HOST" | grep -q "^[23]"; then
                log_info "✓ HTTPS connection to $N8N_HOST works"
            else
                log_warn "HTTPS connection to $N8N_HOST failed"
            fi
        fi
    fi
}

main() {
    log_step "n8n Hardened Stack Status"
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose not found"
        exit 1
    fi
    
    # Check service statuses
    log_step "Service Status:"
    local services=("n8n-hard_permissions-init" "n8n-postgres" "n8n" "n8n-hard-nginx-prod")
    local failed=0
    
    for service in "${services[@]}"; do
        if ! check_service_status "$service"; then
            failed=$((failed + 1))
        fi
    done
    
    # Show overall status
    echo
    if [ $failed -eq 0 ]; then
        log_info "🎉 All services are running properly!"
    else
        log_warn "$failed service(s) have issues"
    fi
    
    # Check connectivity if services are running
    if [ $failed -eq 0 ]; then
        check_connectivity
    fi
    
    # Show resource usage
    log_step "Resource Usage:"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    
    # Option to show logs for failed services
    if [ $failed -gt 0 ]; then
        echo
        log_step "Recent logs for troubleshooting:"
        for service in "${services[@]}"; do
            local container_id
            container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
            if [ -n "$container_id" ]; then
                local status
                status=$(docker inspect "$container_id" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
                if [ "$status" != "running" ] || [ "$(docker inspect "$container_id" --format '{{.State.Health.Status}}' 2>/dev/null || echo "healthy")" = "unhealthy" ]; then
                    show_service_logs "$service" 20
                fi
            fi
        done
    fi
}

main "$@"
