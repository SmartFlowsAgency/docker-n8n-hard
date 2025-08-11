#!/usr/bin/env bash
set -e

DATA_DIR="/var/lib/postgresql/data"
POSTGRES_UID=999
POSTGRES_GID=999

# Only chown if needed (if the directory or any file is not owned by postgres)
if [ "$(stat -c '%u' "$DATA_DIR")" -ne "$POSTGRES_UID" ] || [ "$(stat -c '%g' "$DATA_DIR")" -ne "$POSTGRES_GID" ]; then
  echo "[INFO] Fixing ownership of $DATA_DIR to $POSTGRES_UID:$POSTGRES_GID"

  chown -R $POSTGRES_UID:$POSTGRES_GID "$DATA_DIR"

  echo "[INFO] Ownership of $DATA_DIR is now $POSTGRES_UID:$POSTGRES_GID"
else
  echo "[INFO] Ownership of $DATA_DIR is correct."
fi

ls -l /docker-entrypoint.sh || echo "[ERROR] /docker-entrypoint.sh not found"
# Exec the official entrypoint

exec /usr/local/bin/docker-entrypoint.sh "$@"