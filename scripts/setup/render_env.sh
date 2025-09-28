#!/usr/bin/env bash
# Usage: render_env.sh <vars.yaml>
# Example: render_env.sh build/env/vars.yaml

set -euo pipefail

if [[ $# -lt 1 || $# -gt 1 ]]; then
  echo "Usage: $0 <vars.yaml>" >&2
  exit 1
fi

VARS_YAML="$1"

# Resolve ARTIFACT_ROOT
ARTIFACT_ROOT=$(pwd)

# Verbosity controls
# Set DEBUG=1 or VERBOSE=1 to enable debug logging
DEBUG="${DEBUG:-}"
VERBOSE="${VERBOSE:-}"
debug() { if [[ -n "$DEBUG" || "${VERBOSE}" == "1" ]]; then echo "$1" >&2; fi }

# Redaction helper for sensitive keys
is_sensitive_key() {
  local key="$1"
  [[ "$key" =~ (PASSWORD|SECRET|TOKEN|KEY|ENCRYPTION|AUTH)_?([A-Z0-9_]*)$ ]]
}
redact_value() {
  local val="$1"
  local len=${#val}
  if (( len <= 4 )); then echo "****"; else echo "${val:0:2}****${val: -2}"; fi
}

echo "[INFO] Rendering env files from $VARS_YAML using current directory: $(pwd)"

echo "[INFO] ARTIFACT_ROOT $ARTIFACT_ROOT"
YQ_BIN="$ARTIFACT_ROOT/bin/yq"
echo "[INFO] YQ_BIN $YQ_BIN"

# Determine candidate override locations
ENV_DIRNAME="$(dirname "$VARS_YAML")"
PARENT_DIRNAME="$(cd "$ENV_DIRNAME/.." && pwd)"

OVERRIDE_CANDIDATES=(
  "$ARTIFACT_ROOT/.env"
  "$PARENT_DIRNAME/.env"
  "$PARENT_DIRNAME/.env.*"
  "$ENV_DIRNAME/.env"
  "$ENV_DIRNAME/.env.*"
)

# Persist generated secrets across builds by reusing values from previous renders
# Specifically, if PG_DB_PASSWORD is not provided by user overrides but an older
# build/env/.env.postgres exists with POSTGRES_PASSWORD, reuse that value. This
# keeps Postgres and n8n credentials stable across rebuilds unless explicitly overridden.
if [[ -z "${PG_DB_PASSWORD:-}" && -f "$ENV_DIRNAME/.env.postgres" ]]; then
  prev_pg_pw=$(grep -E '^POSTGRES_PASSWORD=' "$ENV_DIRNAME/.env.postgres" | head -n1 | cut -d'=' -f2- || true)
  if [[ -n "$prev_pg_pw" ]]; then
    debug "[DEBUG] Reusing persisted PG_DB_PASSWORD from $ENV_DIRNAME/.env.postgres"
    PG_DB_PASSWORD="$prev_pg_pw"
  fi
fi

# Function to generate secrets (expand as needed)
generate_secret() {
  local type="$1"
  case "$type" in
    openssl_32)
      openssl rand -base64 32 | tr -d '\n' ;;
    random_base64_32)
      head -c 32 /dev/urandom | base64 | tr -d '\n' ;;
    random_base64_24)
      head -c 24 /dev/urandom | base64 | tr -d '\n' ;;
    *)
      echo "[ERROR] Unknown generation type: $type" >&2
      exit 2
      ;;
  esac
}

# --- GLOBAL VALUE INGESTION ---
# Build ALL_VALUES map from all sections/keys in vars.yaml
ALL_SECTIONS=$($YQ_BIN eval -r 'keys | .[]' "$VARS_YAML")
if [[ -z "$ALL_SECTIONS" ]]; then
  echo "[ERROR] No sections found in $VARS_YAML. Contents:" >&2
  sed -n '1,120p' "$VARS_YAML" >&2 || true
  exit 2
fi
declare -A ALL_VALUES
for section in $ALL_SECTIONS; do
  for key in $($YQ_BIN eval ".${section} | keys | .[]" "$VARS_YAML"); do
    # Check for override in all candidate files FIRST
    override_found=false
    for override_file in "${OVERRIDE_CANDIDATES[@]}"; do
      if [[ -f "$override_file" ]]; then
        # Grep for the key at the beginning of a line, followed by '='; tolerate no-match under set -e
        match=$(grep -m1 "^${key}=" "$override_file" || true)
        if [[ -n "$match" ]]; then
          # Extract the value after the first '='
          value="${match#*=}"
          debug "[DEBUG] Using override for $key from $override_file: $value"
          ALL_VALUES[$key]="$value"
          override_found=true
          break
        fi
      fi
    done
    
    # Only generate if no override was found
    if [[ "$override_found" == "false" ]]; then
      generate=$($YQ_BIN eval ".${section}.${key}.generate" "$VARS_YAML")
      if [[ "$generate" == "true" ]]; then
        type=$($YQ_BIN eval ".${section}.${key}.type" "$VARS_YAML")
        ALL_VALUES[$key]="$(generate_secret "$type")"
        continue
      fi
      default=$($YQ_BIN eval ".${section}.${key}.default // \"\"" "$VARS_YAML")
      if [[ -n "$default" && "$default" != "null" ]]; then
        ALL_VALUES[$key]="$default"
      fi
    fi
  done
done

# Only dump ALL_VALUES in debug, and redact sensitive values
if [[ -n "$DEBUG" || "${VERBOSE}" == "1" ]]; then
  debug "[DEBUG] ALL_VALUES map before rendering sections:"
  for k in "${!ALL_VALUES[@]}"; do
    val="${ALL_VALUES[$k]}"
    if is_sensitive_key "$k"; then
      debug "[DEBUG]   $k = $(redact_value "$val")"
    else
      debug "[DEBUG]   $k = $val"
    fi
  done
fi

# --- RENDER ALL SECTIONS TO ENV FILES ---
# For each section, render to build/env/.env.<section>
for section in $ALL_SECTIONS; do
  OUT_FILE="$(dirname "$VARS_YAML")/.env.$section"
  echo "[INFO] Rendering $OUT_FILE from $section section of $VARS_YAML using ALL_VALUES"
  : > "$OUT_FILE"
  {
    for key in $($YQ_BIN eval ".${section} | keys | .[]" "$VARS_YAML"); do
      required=$($YQ_BIN eval ".${section}.${key}.required" "$VARS_YAML")
      value="${ALL_VALUES[$key]:-}"
      # Alias resolution: if value is $VAR, substitute actual value from ALL_VALUES
      if [[ "$value" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)$ ]]; then
        ref_var="${value:1}"
        value="${ALL_VALUES[$ref_var]:-}"
      fi
      if [[ -z "$value" && "$required" == "true" ]]; then
        echo "[ERROR] Required variable $key missing for section $section" >&2
        continue
      fi
      if [[ -n "$value" ]]; then
        echo "$key=$value"
      fi
    done
  } >> "$OUT_FILE"
  echo "[INFO] Rendered $OUT_FILE from $section section of $VARS_YAML"
done

exit 0
