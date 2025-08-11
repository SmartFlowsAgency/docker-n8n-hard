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
  setup         - Run the first-time interactive setup to create .env and prepare scripts.
  test          - Run deployment readiness tests to verify configuration.
  build         - Generate configs and obtain SSL certificates.
  deploy        - Runs the orchestrated deployment to bring services up safely.
  down          - Stops and removes all services.
  clean         - Clean up containers, networks, and optionally volumes.
  restart       - Restarts all services.
  logs          - Tails the logs of all running services.
  ps            - Shows the status of all services.
  status        - Shows detailed status and health information.
  backup        - Creates a compressed backup of PostgreSQL and n8n data.
  cert-init     - Initialize SSL certificates with Let's Encrypt.
  cert-renew    - Manually renews SSL certificates.
  help          - Shows this help message.

Workflow:
  1. ./dn8nh.sh setup
  2. ./dn8nh.sh test
  3. ./dn8nh.sh build (generates configs and gets SSL certificates)
  4. ./dn8nh.sh deploy

EOF
}

check_profiles_conflict() {
    if [[ "$1" == "deploy" || "$1" == "build" || "$1" == "cert-init" || "$1" == "cert-renew" ]]; then
        # Check if both prod and cert-init containers are running (port 80 conflict)
        local prod_running cert_running
        prod_running=$(docker ps --filter "name=n8n-hard-nginx-prod" --format '{{.Names}}')
        cert_running=$(docker ps --filter "name=n8n-nginx-certbot" --format '{{.Names}}')
        if [[ -n "$prod_running" && -n "$cert_running" ]]; then
            echo "\n[ERROR] Both prod (n8n-hard-nginx-prod) and cert-init (n8n-nginx-certbot) containers are running. This will cause a port 80 conflict."
            echo "Stop one profile before starting the other."
            echo "\nTo stop all containers: docker-compose down\n"
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
            bash scripts/setup.sh "$PROJECT_ROOT"
            ;;
        test)
            bash scripts/test.sh "$PROJECT_ROOT"
            ;;
        build)
            check_env_and_config
            bash scripts/certbot_build.sh "$PROJECT_ROOT"
            ;;
        deploy)
            check_env_and_config
            bash scripts/deploy.sh "$PROJECT_ROOT"
            ;;
        down)
            docker-compose down
            ;;
        clean)
            bash scripts/clean.sh "$PROJECT_ROOT" "${@:2}"
            ;;
        restart)
            docker-compose restart
            ;;
        logs)
            docker-compose logs -f
            ;;
        ps)
            docker-compose ps
            ;;
        status)
            bash scripts/status.sh "$PROJECT_ROOT"
            ;;
        backup)
            bash scripts/backup.sh "$PROJECT_ROOT"
            ;;
        cert-init)
            check_env_and_config
            bash scripts/certbot_init.sh "$PROJECT_ROOT"
            ;;
        cert-renew)
            check_env_and_config
            bash scripts/certbot_renew.sh "$PROJECT_ROOT"
            ;;
        help|*)
            print_usage
            ;;
    esac
}

main "$@"
