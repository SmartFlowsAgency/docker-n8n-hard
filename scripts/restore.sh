#!/usr/bin/env bash
# restore.sh - Restore Docker volumes from backups created by backup.sh

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}▶${NC} $1"; }

# Defaults
DRY_RUN=false
WIPE_BEFORE=false
RESTART=false
SRC_DIR=""
USE_LATEST=false
PRINT_CONFIG=false
INTERACTIVE=false
PRESERVE_CERTS=false
POS_ARGS=()

# Per-volume archive paths (optional)
ARCH_N8N_DATA=""
ARCH_N8N_FILES=""
ARCH_POSTGRES=""
ARCH_CERTS=""

usage(){
  cat <<EOF
Usage: ./dn8nh.sh restore [OPTIONS] [ARCHIVE ...]

Restore Docker volumes from backup archives created by scripts/backup.sh.

Options:
  --from=DIR        Directory containing backups (default: ../backups relative to project)
  --latest          Auto-select the latest archive for each resolved volume
  --wipe-before     Wipe volume contents before restoring (DANGEROUS)
  --restart         Start core services after restore (postgres, n8n, nginx-rproxy)
  --dry-run         Show actions without executing
  --print-config    Print resolved volume names and expected archive patterns, then exit

  # Per-volume explicit archive selection (overrides --latest):
  --n8n-data-archive=FILE
  --n8n-files-archive=FILE
  --postgres-archive=FILE
  --certs-archive=FILE
  --preserve-certs  Do not restore certificate volume; leave existing certs untouched
  -h, --help        Show this help

Providing one or more ARCHIVE paths overrides --from/--latest selection.
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --from=*)
      SRC_DIR="${1#*=}"
      shift
      ;;
    --latest)
      USE_LATEST=true
      shift
      ;;
    --wipe-before)
      WIPE_BEFORE=true
      shift
      ;;
    --restart)
      RESTART=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --print-config)
      PRINT_CONFIG=true
      shift
      ;;
        --interactive)
      INTERACTIVE=true
      shift
      ;;
    --preserve-certs)
      PRESERVE_CERTS=true
      shift
      ;;
    --n8n-data-archive=*)
      ARCH_N8N_DATA="${1#*=}"
      shift
      ;;
    --n8n-files-archive=*)
      ARCH_N8N_FILES="${1#*=}"
      shift
      ;;
    --postgres-archive=*)
      ARCH_POSTGRES="${1#*=}"
      shift
      ;;
    --certs-archive=*)
      ARCH_CERTS="${1#*=}"
      shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    --*)
      log_error "Unknown option: $1"; usage; exit 1
      ;;
    *)
      POS_ARGS+=("$1")
      shift
      ;;
  esac
done

# Determine backup source directory if not provided
if [[ -z "${SRC_DIR}" ]]; then
  SRC_DIR="$(cd "$PROJECT_ROOT/.." && pwd)/backups"
fi

# Compute project name similar to backup.sh
PROJECT_NAME="${DN8NH_INSTANCE_NAME:-${COMPOSE_PROJECT_NAME:-$(basename "$PROJECT_ROOT")}}"

# Resolve actual volume names, allowing env overrides
VOL_N8N_DATA="${N8N_DATA_VOLUME_NAME:-${PROJECT_NAME}_n8n_data}"
VOL_N8N_FILES="${N8N_FILES_VOLUME_NAME:-${PROJECT_NAME}_n8n_files}"
VOL_POSTGRES="${POSTGRES_DATA_VOLUME_NAME:-${PROJECT_NAME}_n8n-postgres_data}"
VOL_CERTS="${CERTBOT_ETC_VOLUME_NAME:-${PROJECT_NAME}_n8n-certbot-etc}"

if [[ "$PRESERVE_CERTS" = true ]]; then
  log_info "--preserve-certs is active. The certificate volume will not be restored."
  ARCH_CERTS=""
fi

if [[ "$PRINT_CONFIG" = true ]]; then
  echo "Resolved volume names:"
  echo "  n8n data:      $VOL_N8N_DATA"
  echo "  n8n files:     $VOL_N8N_FILES"
  echo "  postgres data: $VOL_POSTGRES"
  echo "  certbot etc:   $VOL_CERTS"
  echo
  echo "Expected archive patterns in: $SRC_DIR"
  echo "  $VOL_N8N_DATA-YYYYMMDD-HHMMSS.tar.gz"
  echo "  $VOL_N8N_FILES-YYYYMMDD-HHMMSS.tar.gz"
  echo "  $VOL_POSTGRES-YYYYMMDD-HHMMSS.tar.gz"
  echo "  $VOL_CERTS-YYYYMMDD-HHMMSS.tar.gz"
  exit 0
fi

# Build archive selections
ARCHIVES=()
USE_EXPLICIT=false

# If per-volume archives provided, validate and mark explicit mode
if [[ -n "$ARCH_N8N_DATA" || -n "$ARCH_N8N_FILES" || -n "$ARCH_POSTGRES" || -n "$ARCH_CERTS" ]]; then
  USE_EXPLICIT=true
  for a in "$ARCH_N8N_DATA" "$ARCH_N8N_FILES" "$ARCH_POSTGRES" "$ARCH_CERTS"; do
    [[ -z "$a" ]] && continue
    if [[ ! -f "$a" ]]; then log_error "Archive not found: $a"; exit 1; fi
  done
fi

if [[ "$USE_EXPLICIT" = false && ${#POS_ARGS[@]} -gt 0 ]]; then
  for a in "${POS_ARGS[@]}"; do
    if [[ -f "$a" ]]; then ARCHIVES+=("$a"); else log_error "Archive not found: $a"; exit 1; fi
  done
fi

if [[ "$USE_EXPLICIT" = false && ${#ARCHIVES[@]} -eq 0 ]]; then
  if [[ "$USE_LATEST" = true ]]; then
    # Use resolved volume names for latest selection (supports overrides)
        volume_pairs=("n8n_data:$VOL_N8N_DATA" "n8n_files:$VOL_N8N_FILES" "n8n-postgres_data:$VOL_POSTGRES")
    if [[ "$PRESERVE_CERTS" = false ]]; then
      volume_pairs+=("n8n-certbot-etc:$VOL_CERTS")
    fi

    for pair in "${volume_pairs[@]}"; do
      vol_name="${pair#*:}"
      latest=$(ls -1t "$SRC_DIR"/${vol_name}-*.tar.gz 2>/dev/null | head -n1 || true)
      if [[ -n "$latest" ]]; then ARCHIVES+=("$latest"); else base="${pair%%:*}"; log_warn "No backups found for $base ($vol_name) in $SRC_DIR"; fi
    done
  elif [[ "$INTERACTIVE" = true ]]; then
    # Prompt user for files per volume
    prompt_select(){
      local label="$1"; local vol="$2"; local required="$3"; local outvar="$4";
      echo
      echo "Select archive for $label (volume: $vol)"
      local options
      IFS=$'\n' read -r -d '' -a options < <(ls -1t "$SRC_DIR"/${vol}-*.tar.gz 2>/dev/null | head -n 10; printf '\0') || true
      local idx=1
      if [[ ${#options[@]} -gt 0 ]]; then
        for f in "${options[@]}"; do echo "  [$idx] $(basename "$f")"; idx=$((idx+1)); done
      else
        echo "  (no matching archives found for pattern: ${vol}-*.tar.gz)"
      fi
      echo -n "Enter number to select, or full path, or leave blank to skip${required:+ (required)}: "
      read -r choice || true
      local selected=""
      if [[ -n "$choice" ]]; then
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#options[@]} )); then
          selected="${options[$((choice-1))]}"
        else
          selected="$choice"
        fi
      fi
      if [[ -n "$selected" && ! -f "$selected" ]]; then
        log_error "File not found: $selected"; exit 1
      fi
      printf -v "$outvar" '%s' "$selected"
    }
    prompt_select "n8n data"      "$VOL_N8N_DATA"   "yes" ARCH_N8N_DATA
    prompt_select "n8n files"     "$VOL_N8N_FILES"  "yes" ARCH_N8N_FILES
        prompt_select "postgres data" "$VOL_POSTGRES"   "yes" ARCH_POSTGRES
    if [[ "$PRESERVE_CERTS" = false ]]; then
      prompt_select "certbot etc"   "$VOL_CERTS"      "no"  ARCH_CERTS
    fi
    USE_EXPLICIT=true
  else
    log_error "No archives specified. Provide per-volume archives, positional archives, --latest, or use --interactive."
    usage; exit 1
  fi
fi

log_step "Resolved volumes:"
echo "  n8n data:      $VOL_N8N_DATA"
echo "  n8n files:     $VOL_N8N_FILES"
echo "  postgres data: $VOL_POSTGRES"
echo "  certbot etc:   $VOL_CERTS"

log_step "Archives to restore:"
if [[ "$USE_EXPLICIT" = true ]]; then
  [[ -n "$ARCH_N8N_DATA" ]]   && echo "  $VOL_N8N_DATA  <=  $ARCH_N8N_DATA"
  [[ -n "$ARCH_N8N_FILES" ]]  && echo "  $VOL_N8N_FILES <=  $ARCH_N8N_FILES"
  [[ -n "$ARCH_POSTGRES" ]]   && echo "  $VOL_POSTGRES  <=  $ARCH_POSTGRES"
  [[ -n "$ARCH_CERTS" ]]      && echo "  $VOL_CERTS     <=  $ARCH_CERTS"
else
  for f in "${ARCHIVES[@]}"; do echo "  - $f"; done
fi

# Ensure volumes exist
if [[ "$DRY_RUN" = false ]]; then
  bash "$PROJECT_ROOT/scripts/setup/ensure_volumes.sh"
else
  log_info "[DRY RUN] Would ensure volumes via scripts/setup/ensure_volumes.sh"
fi

# Stop core services to ensure consistent restore
log_step "Stopping services (postgres, n8n, nginx-rproxy)"
if [[ "$DRY_RUN" = false ]]; then
  (cd "$PROJECT_ROOT" && docker compose stop n8n postgres nginx-rproxy) >/dev/null 2>&1 || true
else
  log_info "[DRY RUN] Would stop services"
fi

# Helper to extract volume name from archive filename
extract_volume_name(){
  local fname="$1"
  local base
  base="$(basename "$fname")"
  base="${base%.tar.gz}"
  # Strip trailing -YYYYMMDD-HHMMSS
  echo "$base" | sed -E 's/-[0-9]{8}-[0-9]{6}$//'
}

CERTS_RESTORED=false

# Restore helper
restore_volume(){
  local volume_name="$1"
  local archive="$2"

  if [[ -z "$archive" ]]; then
    log_warn "No archive provided for $volume_name; skipping"
    return 0
  fi
  if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
    log_error "Volume $volume_name does not exist. Run setup first."; exit 1
  fi

  log_step "Restoring volume: $volume_name from $(basename "$archive")"

  if [[ "$WIPE_BEFORE" = true ]]; then
    if [[ "$DRY_RUN" = false ]]; then
      docker run --rm -v "$volume_name":/data alpine:3.18 sh -lc 'cd /data && find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +'
    else
      log_info "[DRY RUN] Would wipe volume contents: $volume_name"
    fi
  fi

  if [[ "$DRY_RUN" = false ]]; then
    archive_dir="$(cd "$(dirname "$archive")" && pwd)"
    docker run --rm \
      -v "$volume_name":/data \
      -v "$archive_dir":/backup \
      alpine:3.18 sh -lc "cd /data && tar -xzf /backup/$(basename \"$archive\") --strip-components=1"
  else
    log_info "[DRY RUN] Would extract $(basename "$archive") into $volume_name"
  fi

    if [[ "$PRESERVE_CERTS" = false && "$volume_name" == *"n8n-certbot-etc"* ]]; then
    CERTS_RESTORED=true
  fi
}

# Perform restore
if [[ "$USE_EXPLICIT" = true ]]; then
  restore_volume "$VOL_N8N_DATA"   "$ARCH_N8N_DATA"
  restore_volume "$VOL_N8N_FILES"  "$ARCH_N8N_FILES"
  restore_volume "$VOL_POSTGRES"   "$ARCH_POSTGRES"
  if [[ "$PRESERVE_CERTS" = false ]]; then
    restore_volume "$VOL_CERTS"      "$ARCH_CERTS"
  fi
else
  for archive in "${ARCHIVES[@]}"; do
    volume_name="$(extract_volume_name "$archive")"
    # If archive name follows ${PROJECT_NAME}_<base>, map to configured override volume
    suffix="$(echo "$volume_name" | sed -E "s/^${PROJECT_NAME}_//")"
    case "$suffix" in
      n8n_data)
        target_vol="$VOL_N8N_DATA"
        ;;
      n8n_files)
        target_vol="$VOL_N8N_FILES"
        ;;
      n8n-postgres_data)
        target_vol="$VOL_POSTGRES"
        ;;
      n8n-certbot-etc)
        target_vol="$VOL_CERTS"
        ;;
      *)
        target_vol="$volume_name"
        ;;
    esac
    restore_volume "$target_vol" "$archive"
  done
fi

# Post-restore actions
if [[ "$RESTART" = true ]]; then
  log_step "Starting services (postgres, n8n, nginx-rproxy)"
  if [[ "$DRY_RUN" = false ]]; then
    (cd "$PROJECT_ROOT" && docker compose up -d postgres n8n nginx-rproxy)
  else
    log_info "[DRY RUN] Would start services"
  fi
fi

# Reload nginx if certs restored and container is running
if [[ "$CERTS_RESTORED" = true ]]; then
  log_step "Reloading nginx to pick up restored certificates"
  if [[ "$DRY_RUN" = false ]]; then
    if container_id=$(cd "$PROJECT_ROOT" && docker compose ps -q nginx-rproxy 2>/dev/null) && [[ -n "$container_id" ]]; then
      (cd "$PROJECT_ROOT" && docker compose exec -T nginx-rproxy nginx -s reload) || (cd "$PROJECT_ROOT" && docker compose restart nginx-rproxy) || true
    else
      log_info "nginx-rproxy is not running; will pick up certs on next start"
    fi
  else
    log_info "[DRY RUN] Would reload nginx"
  fi
fi

log_step "Restore complete"
