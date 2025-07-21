#!/bin/bash

# n8n Restore Script
# Restores PostgreSQL database, n8n data volume, and configuration files

set -e

# Configuration
BACKUP_DIR="/home/blahkheart/Documents/projects/n8n/backups"
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

show_usage() {
    echo "Usage: $0 [BACKUP_DATE] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  BACKUP_DATE    Date of backup to restore (format: YYYYMMDD_HHMMSS)"
    echo "  --list         List available backups"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                    # List available backups"
    echo "  $0 20241201_143022          # Restore specific backup"
    echo "  $0                          # Interactive mode - choose from available backups"
}

list_backups() {
    log "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        # Find all manifest files and extract dates
        find "$BACKUP_DIR" -name "backup_manifest_*.txt" -type f | sort -r | while read -r manifest; do
            if [ -f "$manifest" ]; then
                BACKUP_DATE=$(basename "$manifest" | sed 's/backup_manifest_\(.*\)\.txt/\1/')
                BACKUP_TIME=$(grep "Created:" "$manifest" | cut -d: -f2- | xargs)
                echo "  - $BACKUP_DATE ($BACKUP_TIME)"
            fi
        done
    else
        warn "Backup directory not found: $BACKUP_DIR"
    fi
}

select_backup_interactive() {
    echo "Available backups:"
    local backups=()
    local counter=1
    
    # Collect backups into array
    if [ -d "$BACKUP_DIR" ]; then
        while IFS= read -r -d '' manifest; do
            BACKUP_DATE=$(basename "$manifest" | sed 's/backup_manifest_\(.*\)\.txt/\1/')
            BACKUP_TIME=$(grep "Created:" "$manifest" | cut -d: -f2- | xargs)
            echo "  $counter) $BACKUP_DATE ($BACKUP_TIME)"
            backups+=("$BACKUP_DATE")
            ((counter++))
        done < <(find "$BACKUP_DIR" -name "backup_manifest_*.txt" -type f -print0 | sort -rz)
    fi
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "No backups found in $BACKUP_DIR"
    fi
    
    echo ""
    read -p "Select backup number (1-${#backups[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
        echo "${backups[$((selection-1))]}"
    else
        error "Invalid selection"
    fi
}

validate_backup_files() {
    local backup_date="$1"
    local missing_files=()
    
    local db_backup="$BACKUP_DIR/n8n_database_${backup_date}.sql.gz"
    local data_backup="$BACKUP_DIR/n8n_data_${backup_date}.tar.gz"
    local config_backup="$BACKUP_DIR/n8n_config_${backup_date}.tar.gz"
    
    [ ! -f "$db_backup" ] && missing_files+=("Database backup: $db_backup")
    [ ! -f "$data_backup" ] && missing_files+=("Data backup: $data_backup")
    [ ! -f "$config_backup" ] && missing_files+=("Config backup: $config_backup")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        error "Missing backup files for $backup_date:"
        printf '  - %s\n' "${missing_files[@]}"
        exit 1
    fi
    
    log "All backup files found for $backup_date"
}

restore_backup() {
    local backup_date="$1"
    
    log "Starting restore process for backup: $backup_date"
    
    # Validate backup files exist
    validate_backup_files "$backup_date"
    
    # Define backup file paths
    local db_backup="$BACKUP_DIR/n8n_database_${backup_date}.sql.gz"
    local data_backup="$BACKUP_DIR/n8n_data_${backup_date}.tar.gz"
    local config_backup="$BACKUP_DIR/n8n_config_${backup_date}.tar.gz"
    
    # Confirmation prompt
    warn "This will OVERWRITE your current n8n installation!"
    warn "Current data will be lost. Make sure you have a recent backup."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Restore cancelled by user"
        exit 0
    fi
    
    # Step 1: Stop containers
    log "Stopping n8n containers..."
    cd "$PROJECT_DIR"
    docker-compose down || warn "Could not stop containers (they may not be running)"
    
    # Step 2: Backup current state (just in case)
    local emergency_backup_dir="$BACKUP_DIR/emergency_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$emergency_backup_dir"
    log "Creating emergency backup of current state in: $emergency_backup_dir"
    
    # Backup current volumes if they exist
    if docker volume ls | grep -q "n8n_n8n_data"; then
        docker run --rm \
            -v n8n_n8n_data:/source:ro \
            -v "$emergency_backup_dir":/backup \
            ubuntu tar czf "/backup/current_n8n_data.tar.gz" -C /source . || warn "Could not backup current n8n data"
    fi
    
    if docker volume ls | grep -q "n8n_postgres_data"; then
        docker run --rm \
            -v n8n_postgres_data:/source:ro \
            -v "$emergency_backup_dir":/backup \
            ubuntu tar czf "/backup/current_postgres_data.tar.gz" -C /source . || warn "Could not backup current postgres data"
    fi
    
    # Step 3: Remove existing volumes
    log "Removing existing volumes..."
    docker volume rm n8n_n8n_data 2>/dev/null || warn "n8n data volume not found"
    docker volume rm n8n_postgres_data 2>/dev/null || warn "postgres data volume not found"
    
    # Step 4: Restore configuration files
    log "Restoring configuration files..."
    tar xzf "$config_backup" -C "$(dirname "$PROJECT_DIR")"
    
    # Step 5: Start only the database to restore data
    log "Starting database container..."
    docker-compose up -d db
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    sleep 10
    
    # Check if database is ready
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T db pg_isready -U n8n >/dev/null 2>&1; then
            log "Database is ready"
            break
        fi
        info "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "Database failed to start after $max_attempts attempts"
    fi
    
    # Step 6: Restore database
    log "Restoring database..."
    gunzip -c "$db_backup" | docker-compose exec -T db psql -U n8n -d n8n
    
    # Step 7: Stop database and restore n8n data volume
    log "Stopping database to restore data volume..."
    docker-compose stop db
    
    # Create n8n data volume and restore
    log "Restoring n8n data volume..."
    docker volume create n8n_n8n_data
    docker run --rm \
        -v n8n_n8n_data:/target \
        -v "$BACKUP_DIR":/backup \
        ubuntu tar xzf "/backup/n8n_data_${backup_date}.tar.gz" -C /target
    
    # Step 8: Start all services
    log "Starting all services..."
    docker-compose up -d
    
    # Step 9: Wait for services to be ready
    log "Waiting for services to start..."
    sleep 15
    
    # Check service health
    local health_check_attempts=0
    local max_health_checks=10
    
    while [ $health_check_attempts -lt $max_health_checks ]; do
        if curl -s -k --max-time 5 "https://blahkheart.localtest.me:5678/healthz" >/dev/null 2>&1; then
            log "n8n is healthy and ready!"
            break
        fi
        info "Waiting for n8n to be ready... (attempt $((health_check_attempts + 1))/$max_health_checks)"
        sleep 10
        ((health_check_attempts++))
    done
    
    if [ $health_check_attempts -ge $max_health_checks ]; then
        warn "n8n health check failed, but restore process completed"
        warn "Check logs with: docker-compose logs"
    fi
    
    log "Restore completed successfully!"
    log "n8n should be available at: https://blahkheart.localtest.me:5678"
    log "Emergency backup created at: $emergency_backup_dir"
    
    # Show restore summary
    info "Restore Summary:"
    info "  - Database restored from: $db_backup"
    info "  - Data restored from: $data_backup"
    info "  - Configuration restored from: $config_backup"
    info "  - Emergency backup: $emergency_backup_dir"
}

# Main script logic
case "${1:-}" in
    --help|-h)
        show_usage
        exit 0
        ;;
    --list|-l)
        list_backups
        exit 0
        ;;
    "")
        # Interactive mode
        BACKUP_DATE=$(select_backup_interactive)
        restore_backup "$BACKUP_DATE"
        ;;
    *)
        # Direct backup date provided
        if [[ "$1" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
            restore_backup "$1"
        else
            error "Invalid backup date format. Expected: YYYYMMDD_HHMMSS"
            show_usage
            exit 1
        fi
        ;;
esac