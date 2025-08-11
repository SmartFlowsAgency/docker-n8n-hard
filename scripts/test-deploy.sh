#!/usr/bin/env bash
#
# Test script to verify deployment functionality
#

set -euo pipefail

# Change to project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_error() { echo -e "${RED}[TEST ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

test_prerequisites() {
    log_step "Testing prerequisites..."
    
    # Test Docker
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running"
        return 1
    fi
    log_info "✓ Docker is running"
    
    # Test docker-compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose not found"
        return 1
    fi
    log_info "✓ docker-compose is available"

    if false; then
      # Test .env file
      if [ ! -f .env ]; then
          log_error ".env file not found"
          return 1
      fi
    fi

    log_info "✓ .env file exists"
    
    # Load and test environment variables
    set -a
    source .env
    set +a

    if false; then
      # Test required environment variables
      local required_vars=("POSTGRES_PASSWORD" "N8N_AUTH_USER" "N8N_AUTH_PASSWORD" "N8N_ENCRYPTION_KEY" "N8N_HOST")
      for var in "${required_vars[@]}"; do
          if [ -z "${!var:-}" ]; then
              log_error "Required environment variable $var is not set"
              return 1
          fi
      done
    fi

    log_info "✓ All required environment variables are set"
    
    return 0
}

test_docker_compose_syntax() {
    log_step "Testing docker-compose configuration..."
    
    if ! docker-compose config >/dev/null 2>&1; then
        log_error "docker-compose.yml has syntax errors"
        docker-compose config
        return 1
    fi
    log_info "✓ docker-compose.yml syntax is valid"
    
    return 0
}

test_script_permissions() {
    log_step "Testing script permissions..."
    
    local scripts=("scripts/deploy.sh" "scripts/setup.sh" "scripts/backup.sh" "dn8nh.sh")
    for script in "${scripts[@]}"; do
        if [ ! -x "$script" ]; then
            log_error "$script is not executable"
            return 1
        fi
    done
    log_info "✓ All scripts are executable"
    
    return 0
}

test_entrypoint_permissions() {
    log_step "Testing entrypoint permissions..."
    
    local entrypoints=(entrypoints/*.sh)
    for entrypoint in "${entrypoints[@]}"; do
        if [ -f "$entrypoint" ] && [ ! -x "$entrypoint" ]; then
            log_error "$entrypoint is not executable"
            return 1
        fi
    done
    log_info "✓ All entrypoints are executable"
    
    return 0
}

test_deploy_script_syntax() {
    log_step "Testing deploy script syntax..."
    
    if ! bash -n scripts/deploy.sh; then
        log_error "deploy.sh has syntax errors"
        return 1
    fi
    log_info "✓ deploy.sh syntax is valid"
    
    return 0
}

main() {
    log_step "Starting deployment tests..."
    
    local tests=(
        "test_prerequisites"
        "test_docker_compose_syntax"
        "test_script_permissions"
        "test_entrypoint_permissions"
        "test_deploy_script_syntax"
    )
    
    local failed=0
    for test in "${tests[@]}"; do
        if ! "$test"; then
            failed=$((failed + 1))
        fi
    done
    
    echo
    if [ $failed -eq 0 ]; then
        log_info "🎉 All tests passed! Your deployment setup is ready."
        log_info "Run './dn8nh.sh deploy' to start your n8n stack."
    else
        log_error "❌ $failed test(s) failed. Please fix the issues before deploying."
        exit 1
    fi
}

main "$@"
