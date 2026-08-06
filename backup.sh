#!/bin/bash

set -euo pipefail

DATE=$(date +"%Y%m%d%H%M")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

DB_NAME="${POSTGRES_DB:-xboltmedia}"
DB_USER="${DB_USERNAME:-xboltmedia}"
: "${DB_PASSWORD:?set DB_PASSWORD}"
BACKUP_DIR="/home/ubuntu/backups"
BACKUP_PATTERN="db_backup_*.sql"
RETENTION_DAYS=30
BACKUP_INTERVAL_DAYS=3

mkdir -p "$BACKUP_DIR"

find "$BACKUP_DIR" -name "$BACKUP_PATTERN" -type f -mtime +"$RETENTION_DAYS" -exec rm -f {} \;

LATEST_BACKUP=$(find "$BACKUP_DIR" -name "$BACKUP_PATTERN" -type f -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2-)

if [ -n "$LATEST_BACKUP" ] && [ "$(find "$LATEST_BACKUP" -mtime -"$BACKUP_INTERVAL_DAYS" -print)" ]; then
  echo "Latest backup is less than $BACKUP_INTERVAL_DAYS days old. Skipping backup."
  exit 0
fi

BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql"

(cd "$SCRIPT_DIR" && docker compose exec -T -e PGPASSWORD="$DB_PASSWORD" db pg_dump -U "$DB_USER" "$DB_NAME") > "$BACKUP_FILE"

echo "Backup created at $BACKUP_FILE"
