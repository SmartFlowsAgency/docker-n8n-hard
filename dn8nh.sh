#!/usr/bin/env bash
# Main management script for the n8n-hardened stack.

# Set PROJECT_ROOT to the directory containing this script
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT" || exit

echo "[DEBUG] CWD: $(pwd)"
echo "[DEBUG] PROJECT_ROOT: $PROJECT_ROOT"

#
# Main management script for the n8n-hardened stack.
#

set -euo pipefail

# --- Script and Project Setup ---

# Load environment variables if .env file exists
if [ -f .env ]; then
    set -a # Automatically export all variables
    source .env
    set +a
fi

# --- Helper Functions ---

print_usage() {
    cat <<EOF
Usage: ./dn8nh.sh [COMMAND]

Your friendly neighborhood n8n stack manager.

Commands:
  setup         - Install/setup: render envs, ensure volumes, render nginx, obtain SSL certs.
  install       - Alias for 'setup'.
  deploy        - Up: orchestrated deployment with health checks and ordering.
  up            - Alias for 'deploy'.
  down          - Stops and removes all services.
  clean         - Clean up containers, networks, and optionally volumes.
  restart       - Restarts all services.
  logs          - Tails the logs of all running services.
  ps            - Shows the status of all services.
  status        - Shows detailed status and health information.
  backup        - Creates a compressed backup of PostgreSQL and n8n data.
  restore       - Restores Docker volumes from a backup archive set.
  cert-init     - Initialize SSL certificates with Let's Encrypt (advanced).
  cert-renew    - Manually renew SSL certificates.
  help          - Shows this help message.

Workflow:
  1. ./dn8nh.sh setup
  2. ./dn8nh.sh deploy

EOF
}

check_profiles_conflict() {
    if [[ "$1" == "deploy" || "$1" == "cert-init" || "$1" == "cert-renew" || "$1" == "up" ]]; then
        # Check if both prod and cert-init containers are running (port 80 conflict)
        local prod_running cert_running
        prod_running=$(docker ps --filter "name=nginx-rproxy" --format '{{.Names}}')
        cert_running=$(docker ps --filter "name=nginx-certbot" --format '{{.Names}}')
        if [[ -n "$prod_running" && -n "$cert_running" ]]; then
            echo "\n[ERROR] Both prod (nginx-rproxy) and cert-init (nginx-certbot) containers are running. This will cause a port 80 conflict."
            echo "Stop one profile before starting the other."
            echo "\nTo stop all containers: docker compose down\n"
            exit 1
        fi
    fi
}

check_env_and_config() {
    # Ensure env/ and nginx-conf/ exist and have files
    if [[ ! -d "env" || -z $(ls -A env 2>/dev/null) ]]; then
        echo "\n[ERROR] Required env files not found in env/. Run './dn8nh.sh setup' first."
        exit 1
    fi
    if [[ ! -d "nginx-conf" || -z $(ls -A nginx-conf 2>/dev/null) ]]; then
        echo "\n[ERROR] Required nginx configs not found in nginx-conf/. Run './dn8nh.sh setup' first."
        exit 1
    fi
}

# --- Main Command Logic ---

main() {
    check_profiles_conflict "$1"
    local cmd="${1:-help}"

    case "$cmd" in
        setup)
            bash scripts/setup.sh "${@:2}"
            ;;
        install)
            bash scripts/setup.sh "${@:2}"
            ;;
        deploy)
            check_env_and_config
            bash scripts/deploy.sh "${@:2}"
            ;;
        up)
            check_env_and_config
            bash scripts/deploy.sh "${@:2}"
            ;;
        down)
            bash scripts/clean.sh
            ;;
        clean)
            bash scripts/clean.sh "${@:2}"
            ;;
        restart)
            docker compose restart
            ;;
        logs)
            docker compose logs -f
            ;;
        ps)
            docker compose ps
            ;;
        status)
            bash scripts/status.sh "${@:2}"
            ;;
        backup)
            bash scripts/backup.sh "${@:2}"
            ;;
        restore)
            check_env_and_config
            bash scripts/restore.sh "${@:2}"
            ;;
        cert-init)
            check_env_and_config
            bash scripts/certbot/certbot_build.sh "${@:2}"
            ;;
        cert-renew)
            check_env_and_config
            bash scripts/certbot/certbot_renew.sh "${@:2}"
            ;;
        help|*)
            print_usage
            ;;
    esac
}

main "$@"
