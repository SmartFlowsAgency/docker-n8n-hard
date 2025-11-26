#!/usr/bin/env bash
# backup.sh - Backup script for n8n-hardened Docker volumes
# This is a robust version that avoids complex Bash patterns while providing key features

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

# Parse command line arguments
INCLUDE_CERTS=false
PAUSE_SERVICES=false
DRY_RUN=false
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --include-certs)
            INCLUDE_CERTS=true
            shift
            ;;
        --pause)
            PAUSE_SERVICES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --dest=*)
            BACKUP_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--include-certs] [--pause] [--dry-run] [--dest=PATH]"
            echo "  --include-certs  Include SSL certificate volumes"
            echo "  --pause          Pause n8n services during backup"
            echo "  --dry-run        Show what would be backed up"
            echo "  --dest=PATH      Override backup destination"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set backup destination
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="${DN8NH_BACKUP_DIR:-$(cd "$PROJECT_ROOT/.." && pwd)/backups}"
fi

# Volumes to backup (with support for explicit overrides)
PROJECT_NAME="${DN8NH_INSTANCE_NAME:-${COMPOSE_PROJECT_NAME:-$(basename "$PROJECT_ROOT")}}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using project name: $PROJECT_NAME"

VOL_N8N_DATA="${N8N_DATA_VOLUME_NAME:-${PROJECT_NAME}_n8n_data}"
VOL_N8N_FILES="${N8N_FILES_VOLUME_NAME:-${PROJECT_NAME}_n8n_files}"
VOL_POSTGRES="${POSTGRES_DATA_VOLUME_NAME:-${PROJECT_NAME}_n8n-postgres_data}"
VOL_CERTS="${CERTBOT_ETC_VOLUME_NAME:-${PROJECT_NAME}_n8n-certbot-etc}"

VOLUMES=(
    "$VOL_N8N_DATA"
    "$VOL_N8N_FILES"
    "$VOL_POSTGRES"
)

# Add certificate volumes if requested
if [[ "$INCLUDE_CERTS" == true ]]; then
    VOLUMES+=("$VOL_CERTS")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Including certificate volumes in backup"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup to: $BACKUP_DIR"
if [[ "$DRY_RUN" == true ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DRY RUN MODE - No actual backups will be created"
fi

# Pause services if requested
if [[ "$PAUSE_SERVICES" == true ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pausing n8n services for consistent backup..."
    cd "$PROJECT_ROOT"
    if [[ -f "docker-compose.yml" ]]; then
        if docker compose stop n8n 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Services paused successfully"
            SERVICES_WERE_PAUSED=true
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Failed to stop services, continuing with hot backup"
            SERVICES_WERE_PAUSED=false
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: docker-compose.yml not found, skipping service pause"
        SERVICES_WERE_PAUSED=false
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Services will remain running during backup (hot backup)"
    SERVICES_WERE_PAUSED=false
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup each volume
for volume in "${VOLUMES[@]}"; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backing up volume: $volume"

    # Check if volume exists
    if ! docker volume inspect "$volume" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Volume $volume not found, skipping"
        continue
    fi

    # Create backup
    archive_name="${volume}-${TIMESTAMP}.tar.gz"
    archive_path="$BACKUP_DIR/$archive_name"

    if [[ "$DRY_RUN" == true ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Would create archive: $archive_name"
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating archive: $archive_name"

    docker run --rm \
        -v "$volume":/data:ro \
        -v "$BACKUP_DIR":/backup \
        alpine:3.18 \
        tar -czf "/backup/$archive_name" -C /data .

    if [ -f "$archive_path" ]; then
        size=$(du -h "$archive_path" | cut -f1)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Backup completed: $archive_name ($size)"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Backup failed: $archive_name"
    fi
done

# Resume services if they were paused
if [[ "$SERVICES_WERE_PAUSED" == true ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resuming n8n services..."
    cd "$PROJECT_ROOT"
    if docker compose start n8n 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Services resumed successfully"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Failed to resume services - you may need to start them manually"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup process completed"
if [[ "$DRY_RUN" == false ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup files are in: $BACKUP_DIR"
fi
