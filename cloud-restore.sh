#!/bin/bash

# n8n Cloud Restore Script
# Downloads and restores backups from cloud storage

set -e

# Configuration
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
BIN_DIR="$PROJECT_DIR/bin"
BACKUP_DIR="/home/blahkheart/Documents/projects/n8n/backups"
RCLONE_CONFIG_DIR="$PROJECT_DIR/.rclone"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
CLOUD_CONFIG_FILE="$PROJECT_DIR/cloud-backup.conf"
TEMP_RESTORE_DIR="$BACKUP_DIR/cloud_restore_temp"

# Add our local bin to PATH
export PATH="$BIN_DIR:$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

highlight() {
    echo -e "${CYAN}$1${NC}"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list                   List available cloud backups"
    echo "  --download [backup_date] Download specific backup from cloud"
    echo "  --download-latest        Download latest backup from cloud"
    echo "  --restore [backup_date]  Download and restore specific backup"
    echo "  --restore-latest         Download and restore latest backup"
    echo "  --cleanup                Cleanup temporary download files"
    echo "  --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list"
    echo "  $0 --download 20241201_143022"
    echo "  $0 --restore-latest"
}

check_prerequisites() {
    # Check if rclone is available
    if ! command -v rclone >/dev/null 2>&1; then
        error "rclone not found. Please run ./install-rclone.sh first"
    fi
    
    # Check if rclone is configured
    if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
        error "No cloud storage configured. Please run: ./setup-cloud-backup.sh --configure"
    fi
    
    # Check if cloud backup is configured
    if [ ! -f "$CLOUD_CONFIG_FILE" ]; then
        error "Cloud backup not configured. Please run: ./cloud-backup.sh --configure"
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$TEMP_RESTORE_DIR"
}

load_cloud_config() {
    source "$CLOUD_CONFIG_FILE"
    
    if [ -z "$CLOUD_REMOTE" ]; then
        error "CLOUD_REMOTE not set in $CLOUD_CONFIG_FILE"
    fi
    
    # Check if the remote exists
    if ! rclone --config="$RCLONE_CONFIG_FILE" listremotes | grep -q "^${CLOUD_REMOTE}:$"; then
        error "Cloud remote '$CLOUD_REMOTE' not found"
    fi
}

get_rclone_flags() {
    local flags="--config=$RCLONE_CONFIG_FILE --progress"
    
    # Add bandwidth limit if set
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        flags="$flags --bwlimit=$BANDWIDTH_LIMIT"
    fi
    
    # Add parallel downloads
    if [ -n "$PARALLEL_UPLOADS" ] && [ "$PARALLEL_UPLOADS" -gt 1 ]; then
        flags="$flags --transfers=$PARALLEL_UPLOADS"
    fi
    
    echo "$flags"
}

decrypt_file() {
    local encrypted_file="$1"
    local decrypted_file="${encrypted_file%.encrypted}"
    
    if [[ "$encrypted_file" == *.encrypted ]]; then
        local password="$ENCRYPTION_PASSWORD"
        
        if [ -z "$password" ]; then
            read -p "Enter decryption password: " -s password
            echo
        fi
        
        log "Decrypting $(basename "$encrypted_file")..."
        
        if gpg --batch --yes --passphrase "$password" --decrypt "$encrypted_file" > "$decrypted_file" 2>/dev/null; then
            rm -f "$encrypted_file"
            echo "$decrypted_file"
        else
            error "Failed to decrypt $(basename "$encrypted_file"). Wrong password?"
        fi
    else
        echo "$encrypted_file"
    fi
}

list_cloud_backups() {
    log "Listing available backups in cloud storage..."
    
    local flags=$(get_rclone_flags)
    local cloud_path="$CLOUD_REMOTE:$CLOUD_BACKUP_PATH"
    
    echo ""
    highlight "=== Available Cloud Backups ==="
    
    # List directories (backup dates)
    local backups=$(rclone $flags lsd "$cloud_path" 2>/dev/null | awk '{print $5}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r)
    
    if [ -z "$backups" ]; then
        warn "No backups found in cloud storage"
        return 1
    fi
    
    local counter=1
    echo "$backups" | while read -r backup_date; do
        echo "  $counter) $backup_date"
        
        # Try to get backup info from manifest if available
        local manifest_path="$cloud_path/$backup_date/backup_manifest_${backup_date}.txt"
        local backup_info=$(rclone $flags cat "$manifest_path" 2>/dev/null | grep "Created:" | cut -d: -f2- | xargs 2>/dev/null || echo "No details available")
        echo "     Created: $backup_info"
        
        # Get backup size
        local backup_size=$(rclone $flags size "$cloud_path/$backup_date" 2>/dev/null | grep "Total size:" | awk '{print $3, $4}' || echo "Unknown size")
        echo "     Size: $backup_size"
        echo ""
        
        ((counter++))
    done
    
    return 0
}

select_cloud_backup() {
    local backups=($(rclone $(get_rclone_flags) lsd "$CLOUD_REMOTE:$CLOUD_BACKUP_PATH" 2>/dev/null | awk '{print $5}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "No backups found in cloud storage"
    fi
    
    echo "Available cloud backups:"
    for i in "${!backups[@]}"; do
        echo "  $((i+1))) ${backups[i]}"
    done
    
    echo ""
    read -p "Select backup number (1-${#backups[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
        echo "${backups[$((selection-1))]}"
    else
        error "Invalid selection"
    fi
}

download_backup() {
    local backup_date="$1"
    
    if [ -z "$backup_date" ]; then
        error "Please specify a backup date"
    fi
    
    log "Downloading backup: $backup_date"
    
    local flags=$(get_rclone_flags)
    local cloud_backup_path="$CLOUD_REMOTE:$CLOUD_BACKUP_PATH/$backup_date"
    local local_download_path="$TEMP_RESTORE_DIR/$backup_date"
    
    # Create local download directory
    mkdir -p "$local_download_path"
    
    # Check if backup exists in cloud
    if ! rclone $flags lsd "$CLOUD_REMOTE:$CLOUD_BACKUP_PATH" | grep -q "$backup_date"; then
        error "Backup $backup_date not found in cloud storage"
    fi
    
    # Download all files for this backup
    log "Downloading backup files from cloud..."
    
    if rclone $flags copy "$cloud_backup_path" "$local_download_path"; then
        log "✅ Download completed: $local_download_path"
        
        # Decrypt files if they are encrypted
        for file in "$local_download_path"/*.encrypted; do
            if [ -f "$file" ]; then
                decrypt_file "$file"
            fi
        done
        
        # Move files to main backup directory
        log "Moving files to backup directory..."
        mv "$local_download_path"/* "$BACKUP_DIR/"
        rmdir "$local_download_path"
        
        log "✅ Backup $backup_date downloaded and ready for restore"
        
        # Verify essential files are present
        local db_backup="$BACKUP_DIR/n8n_database_${backup_date}.sql.gz"
        local data_backup="$BACKUP_DIR/n8n_data_${backup_date}.tar.gz"
        local config_backup="$BACKUP_DIR/n8n_config_${backup_date}.tar.gz"
        
        local missing_files=()
        [ ! -f "$db_backup" ] && missing_files+=("Database backup")
        [ ! -f "$data_backup" ] && missing_files+=("Data backup")
        [ ! -f "$config_backup" ] && missing_files+=("Config backup")
        
        if [ ${#missing_files[@]} -gt 0 ]; then
            warn "Some backup files are missing: ${missing_files[*]}"
        else
            log "All essential backup files downloaded successfully"
        fi
        
        return 0
    else
        error "❌ Download failed for backup: $backup_date"
        return 1
    fi
}

download_latest() {
    log "Finding latest backup in cloud storage..."
    
    local flags=$(get_rclone_flags)
    local latest_backup=$(rclone $flags lsd "$CLOUD_REMOTE:$CLOUD_BACKUP_PATH" 2>/dev/null | awk '{print $5}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | head -1)
    
    if [ -z "$latest_backup" ]; then
        error "No backups found in cloud storage"
    fi
    
    log "Latest cloud backup: $latest_backup"
    download_backup "$latest_backup"
}

restore_from_cloud() {
    local backup_date="$1"
    local should_download=true
    
    if [ -z "$backup_date" ]; then
        # Interactive mode
        if list_cloud_backups; then
            backup_date=$(select_cloud_backup)
        else
            return 1
        fi
    fi
    
    # Check if backup is already downloaded locally
    local db_backup="$BACKUP_DIR/n8n_database_${backup_date}.sql.gz"
    local data_backup="$BACKUP_DIR/n8n_data_${backup_date}.tar.gz"
    local config_backup="$BACKUP_DIR/n8n_config_${backup_date}.tar.gz"
    
    if [ -f "$db_backup" ] && [ -f "$data_backup" ] && [ -f "$config_backup" ]; then
        log "Backup $backup_date already exists locally"
        read -p "Download from cloud again? (y/N): " download_again
        if [[ ! "$download_again" =~ ^[Yy]$ ]]; then
            should_download=false
        fi
    fi
    
    # Download if needed
    if [ "$should_download" = "true" ]; then
        download_backup "$backup_date" || return 1
    fi
    
    # Run the local restore script
    local restore_script="$PROJECT_DIR/restore-n8n.sh"
    
    if [ ! -f "$restore_script" ] || [ ! -x "$restore_script" ]; then
        error "Local restore script not found: $restore_script"
    fi
    
    log "Starting restore process..."
    warn "This will restore your n8n instance from cloud backup: $backup_date"
    
    exec "$restore_script" "$backup_date"
}

restore_latest_from_cloud() {
    log "Restoring latest backup from cloud storage..."
    
    local flags=$(get_rclone_flags)
    local latest_backup=$(rclone $flags lsd "$CLOUD_REMOTE:$CLOUD_BACKUP_PATH" 2>/dev/null | awk '{print $5}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | head -1)
    
    if [ -z "$latest_backup" ]; then
        error "No backups found in cloud storage"
    fi
    
    log "Latest cloud backup: $latest_backup"
    restore_from_cloud "$latest_backup"
}

cleanup_temp_files() {
    log "Cleaning up temporary download files..."
    
    if [ -d "$TEMP_RESTORE_DIR" ]; then
        rm -rf "$TEMP_RESTORE_DIR"
        log "✅ Temporary files cleaned up"
    else
        log "No temporary files to clean up"
    fi
}

# Main script logic
case "${1:---help}" in
    --list|-l)
        check_prerequisites
        load_cloud_config
        list_cloud_backups
        ;;
    --download|-d)
        check_prerequisites
        load_cloud_config
        download_backup "$2"
        ;;
    --download-latest)
        check_prerequisites
        load_cloud_config
        download_latest
        ;;
    --restore|-r)
        check_prerequisites
        load_cloud_config
        restore_from_cloud "$2"
        ;;
    --restore-latest)
        check_prerequisites
        load_cloud_config
        restore_latest_from_cloud
        ;;
    --cleanup)
        cleanup_temp_files
        ;;
    --help|-h)
        show_usage
        ;;
    *)
        error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac