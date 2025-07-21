#!/bin/bash

# n8n Backup Script
# Backs up PostgreSQL database, n8n data volume, and configuration files

set -e

# Configuration
BACKUP_DIR="/home/blahkheart/Documents/projects/n8n/backups"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
DB_CONTAINER="n8n-db-1"
N8N_CONTAINER="n8n-n8n-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting n8n backup process..."

# Check if containers are running
if ! docker ps | grep -q "$DB_CONTAINER"; then
    error "Database container $DB_CONTAINER is not running"
fi

if ! docker ps | grep -q "$N8N_CONTAINER"; then
    error "n8n container $N8N_CONTAINER is not running"
fi

# 1. Database backup
log "Creating PostgreSQL database backup..."
DB_BACKUP_FILE="$BACKUP_DIR/n8n_database_$DATE.sql"
docker exec "$DB_CONTAINER" pg_dump -U n8n -d n8n > "$DB_BACKUP_FILE"
gzip "$DB_BACKUP_FILE"
log "Database backup created: ${DB_BACKUP_FILE}.gz"

# 2. n8n data volume backup
log "Creating n8n data volume backup..."
N8N_DATA_BACKUP="$BACKUP_DIR/n8n_data_$DATE.tar.gz"
docker run --rm \
    -v n8n_n8n_data:/source:ro \
    -v "$BACKUP_DIR":/backup \
    ubuntu tar czf "/backup/n8n_data_$DATE.tar.gz" -C /source .
log "n8n data backup created: $N8N_DATA_BACKUP"

# 3. Configuration files backup
log "Creating configuration backup..."
CONFIG_BACKUP="$BACKUP_DIR/n8n_config_$DATE.tar.gz"
tar czf "$CONFIG_BACKUP" -C "$PROJECT_DIR" \
    docker-compose.yml \
    .env \
    blahkheart.localtest.me.pem \
    blahkheart.localtest.me-key.pem
log "Configuration backup created: $CONFIG_BACKUP"

# 4. Create backup manifest
MANIFEST_FILE="$BACKUP_DIR/backup_manifest_$DATE.txt"
cat > "$MANIFEST_FILE" << EOF
n8n Backup Manifest
Created: $(date)
Backup ID: $DATE

Files included:
- Database: n8n_database_${DATE}.sql.gz
- n8n Data: n8n_data_${DATE}.tar.gz
- Configuration: n8n_config_${DATE}.tar.gz

Database info:
- Type: PostgreSQL 16
- Database: n8n
- User: n8n

n8n version: $(docker exec "$N8N_CONTAINER" cat /package.json | grep '"version"' | cut -d'"' -f4)

Restore instructions:
1. Stop containers: docker-compose -f $COMPOSE_FILE down
2. Restore database: gunzip -c n8n_database_${DATE}.sql.gz | docker exec -i <db_container> psql -U n8n -d n8n
3. Restore n8n data: docker run --rm -v n8n_n8n_data:/target -v \$(pwd):/backup ubuntu tar xzf /backup/n8n_data_${DATE}.tar.gz -C /target
4. Restore config: tar xzf n8n_config_${DATE}.tar.gz -C $PROJECT_DIR
5. Start containers: docker-compose -f $COMPOSE_FILE up -d
EOF

log "Backup manifest created: $MANIFEST_FILE"

# 5. Cleanup old backups (keep last 7 days)
log "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "n8n_*" -type f -mtime +7 -delete 2>/dev/null || true

# 6. Show backup summary
TOTAL_SIZE=$(du -sh "$BACKUP_DIR"/*"$DATE"* | awk '{sum+=$1} END {print sum "B"}' 2>/dev/null || echo "Unknown")
log "Backup completed successfully!"
log "Backup files:"
ls -lh "$BACKUP_DIR"/*"$DATE"*
log "Total backup size: $TOTAL_SIZE"

# 7. Upload to cloud storage (if configured)
CLOUD_BACKUP_SCRIPT="$PROJECT_DIR/cloud-backup.sh"
if [ -f "$CLOUD_BACKUP_SCRIPT" ] && [ -x "$CLOUD_BACKUP_SCRIPT" ]; then
    if [ -f "$PROJECT_DIR/cloud-backup.conf" ]; then
        log "Uploading to cloud storage..."
        if "$CLOUD_BACKUP_SCRIPT" --upload "$DATE" 2>/dev/null; then
            log "✅ Cloud upload completed successfully"
        else
            warn "⚠️ Cloud upload failed (backup still saved locally)"
        fi
    else
        warn "💡 Cloud backup not configured. Run: ./setup-cloud-backup.sh --configure"
    fi
else
    warn "💡 Cloud backup script not found. Cloud upload skipped."
fi