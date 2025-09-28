#!/usr/bin/env bash
# ensure_volumes.sh - Create Docker volumes with a prefix if they don't exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment variables
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "[ERROR] .env file not found in project root: $PROJECT_ROOT" >&2
    exit 1
fi

if [[ -z "${DN8NH_INSTANCE_NAME:-}" ]]; then
    echo "[ERROR] DN8NH_INSTANCE_NAME is not set. Please define it in your .env file." >&2
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ensure_volumes] $*"
}

# Define the base names for the volumes
VOLUME_BASES=(
    "n8n_data"
    "n8n_files"
    "n8n-postgres_data"
    "n8n-certbot-etc"
)

log "Ensuring Docker volumes exist with prefix: '${DN8NH_INSTANCE_NAME}'..."

for base_name in "${VOLUME_BASES[@]}"; do
    volume_name="${DN8NH_INSTANCE_NAME}_${base_name}"

    if docker volume inspect "$volume_name" >/dev/null 2>&1; then
        log "Volume '$volume_name' already exists."
    else
        log "Volume '$volume_name' not found. Creating it..."
        docker volume create \
            --label "n8n.hardened.managed-by=script" \
            --label "n8n.hardened.instance=${DN8NH_INSTANCE_NAME}" \
            "$volume_name"
        log "✓ Volume '$volume_name' created successfully."
    fi
done

log "Volume check complete."
