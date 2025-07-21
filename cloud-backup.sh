#!/bin/bash

# n8n Cloud Backup Upload Script
# Uploads local backups to configured cloud storage providers

set -e

# Configuration
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
BIN_DIR="$PROJECT_DIR/bin"
BACKUP_DIR="/home/blahkheart/Documents/projects/n8n/backups"
RCLONE_CONFIG_DIR="$PROJECT_DIR/.rclone"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
CLOUD_CONFIG_FILE="$PROJECT_DIR/cloud-backup.conf"

# Add our local bin to PATH
export PATH="$BIN_DIR:$PATH"

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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --upload [backup_date]   Upload specific backup to cloud"
    echo "  --upload-latest          Upload latest backup to cloud"
    echo "  --upload-all             Upload all local backups to cloud"
    echo "  --sync                   Sync backup directory with cloud"
    echo "  --list-cloud             List backups in cloud storage"
    echo "  --configure              Configure cloud backup settings"
    echo "  --status                 Show cloud backup status"
    echo "  --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --upload-latest"
    echo "  $0 --upload 20241201_143022"
    echo "  $0 --sync"
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
    
    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Backup directory not found: $BACKUP_DIR"
    fi
}

load_cloud_config() {
    # Create default config if it doesn't exist
    if [ ! -f "$CLOUD_CONFIG_FILE" ]; then
        cat > "$CLOUD_CONFIG_FILE" << 'EOF'
# n8n Cloud Backup Configuration
# Edit this file to customize your cloud backup settings

# Primary cloud storage remote (from rclone config)
CLOUD_REMOTE=""

# Cloud backup path (folder in cloud storage)
CLOUD_BACKUP_PATH="n8n-backups"

# Retention policy for cloud backups (days)
CLOUD_RETENTION_DAYS=30

# Enable encryption for cloud uploads (true/false)
ENABLE_ENCRYPTION=true

# Encryption password (leave empty to prompt)
ENCRYPTION_PASSWORD=""

# Upload bandwidth limit (e.g., "1M" for 1MB/s, empty for unlimited)
BANDWIDTH_LIMIT=""

# Enable compression for uploads (true/false)
ENABLE_COMPRESSION=true

# Parallel upload threads (1-8, more = faster but more bandwidth)
PARALLEL_UPLOADS=2

# Enable versioning (keep multiple versions of same backup)
ENABLE_VERSIONING=false
EOF
        warn "Created default cloud backup config: $CLOUD_CONFIG_FILE"
        warn "Please edit this file to configure your settings"
    fi
    
    # Source the config
    source "$CLOUD_CONFIG_FILE"
    
    # Validate essential settings
    if [ -z "$CLOUD_REMOTE" ]; then
        error "CLOUD_REMOTE not set in $CLOUD_CONFIG_FILE"
    fi
    
    # Check if the remote exists
    if ! rclone --config="$RCLONE_CONFIG_FILE" listremotes | grep -q "^${CLOUD_REMOTE}:$"; then
        error "Cloud remote '$CLOUD_REMOTE' not found. Available remotes:"
        rclone --config="$RCLONE_CONFIG_FILE" listremotes
        exit 1
    fi
}

get_rclone_flags() {
    local flags="--config=$RCLONE_CONFIG_FILE"
    
    # Add bandwidth limit if set
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        flags="$flags --bwlimit=$BANDWIDTH_LIMIT"
    fi
    
    # Add parallel uploads
    if [ -n "$PARALLEL_UPLOADS" ] && [ "$PARALLEL_UPLOADS" -gt 1 ]; then
        flags="$flags --transfers=$PARALLEL_UPLOADS"
    fi
    
    # Note: Compression is handled by the storage provider or file format
    # rclone doesn't have a --compress flag in all versions
    
    # Add progress display
    flags="$flags --progress"
    
    echo "$flags"
}

encrypt_file() {
    local file="$1"
    local encrypted_file="${file}.encrypted"
    
    if [ "$ENABLE_ENCRYPTION" = "true" ]; then
        local password="$ENCRYPTION_PASSWORD"
        
        if [ -z "$password" ]; then
            read -p "Enter encryption password: " -s password
            echo
        fi
        
        log "Encrypting $(basename "$file")..."
        gpg --batch --yes --passphrase "$password" --cipher-algo AES256 --symmetric --output "$encrypted_file" "$file"
        echo "$encrypted_file"
    else
        echo "$file"
    fi
}

upload_file() {
    local file="$1"
    local cloud_path="$2"
    local flags=$(get_rclone_flags)
    
    # Encrypt file if encryption is enabled
    local upload_file=$(encrypt_file "$file")
    
    log "Uploading $(basename "$upload_file") to cloud storage..."
    
    if rclone $flags copy "$upload_file" "$CLOUD_REMOTE:blahkheart-n8n-backups/$cloud_path/"; then
        log "✅ Upload successful: $(basename "$upload_file")"
        
        # Clean up encrypted file if it was created
        if [ "$upload_file" != "$file" ]; then
            rm -f "$upload_file"
        fi
        
        return 0
    else
        error "❌ Upload failed: $(basename "$upload_file")"
        return 1
    fi
}

upload_backup() {
    local backup_date="$1"
    
    if [ -z "$backup_date" ]; then
        error "Please specify a backup date"
    fi
    
    log "Uploading backup: $backup_date"
    
    # Define backup files
    local db_backup="$BACKUP_DIR/n8n_database_${backup_date}.sql.gz"
    local data_backup="$BACKUP_DIR/n8n_data_${backup_date}.tar.gz"
    local config_backup="$BACKUP_DIR/n8n_config_${backup_date}.tar.gz"
    local workflow_backup="$BACKUP_DIR/n8n_workflows_${backup_date}.tar.gz"
    local manifest="$BACKUP_DIR/backup_manifest_${backup_date}.txt"
    
    # Check if files exist
    local missing_files=()
    [ ! -f "$db_backup" ] && missing_files+=("Database backup")
    [ ! -f "$data_backup" ] && missing_files+=("Data backup")
    [ ! -f "$config_backup" ] && missing_files+=("Config backup")
    [ ! -f "$manifest" ] && missing_files+=("Backup manifest")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        error "Missing backup files for $backup_date: ${missing_files[*]}"
    fi
    
    # Create cloud directory structure
    local cloud_date_path="$CLOUD_BACKUP_PATH/$backup_date"
    
    # Upload files
    local upload_success=true
    
    upload_file "$db_backup" "$cloud_date_path" || upload_success=false
    upload_file "$data_backup" "$cloud_date_path" || upload_success=false
    upload_file "$config_backup" "$cloud_date_path" || upload_success=false
    upload_file "$manifest" "$cloud_date_path" || upload_success=false
    
    # Upload workflow backup if it exists
    if [ -f "$workflow_backup" ]; then
        upload_file "$workflow_backup" "$cloud_date_path" || upload_success=false
    fi
    
    if [ "$upload_success" = "true" ]; then
        log "✅ Backup $backup_date uploaded successfully to cloud storage"
        
        # Create a upload record
        echo "$(date): Uploaded backup $backup_date to $CLOUD_REMOTE:$cloud_date_path" >> "$BACKUP_DIR/cloud_upload.log"
    else
        error "❌ Some files failed to upload for backup $backup_date"
    fi
}

upload_latest() {
    log "Finding latest backup..."
    
    # Find the most recent backup manifest
    local latest_manifest=$(find "$BACKUP_DIR" -name "backup_manifest_*.txt" -type f | sort -r | head -1)
    
    if [ -z "$latest_manifest" ]; then
        error "No backups found in $BACKUP_DIR"
    fi
    
    local backup_date=$(basename "$latest_manifest" | sed 's/backup_manifest_\(.*\)\.txt/\1/')
    log "Latest backup: $backup_date"
    
    upload_backup "$backup_date"
}

upload_all() {
    log "Uploading all local backups to cloud storage..."
    
    # Find all backup manifests
    local manifests=($(find "$BACKUP_DIR" -name "backup_manifest_*.txt" -type f | sort))
    
    if [ ${#manifests[@]} -eq 0 ]; then
        warn "No backups found in $BACKUP_DIR"
        return
    fi
    
    log "Found ${#manifests[@]} backups to upload"
    
    local success_count=0
    local total_count=${#manifests[@]}
    
    for manifest in "${manifests[@]}"; do
        local backup_date=$(basename "$manifest" | sed 's/backup_manifest_\(.*\)\.txt/\1/')
        
        log "Processing backup $((success_count + 1))/$total_count: $backup_date"
        
        if upload_backup "$backup_date"; then
            ((success_count++))
        else
            warn "Failed to upload backup: $backup_date"
        fi
    done
    
    log "Upload completed: $success_count/$total_count backups uploaded successfully"
}

sync_to_cloud() {
    log "Syncing backup directory with cloud storage..."
    
    local flags=$(get_rclone_flags)
    local cloud_path="$CLOUD_REMOTE:$CLOUD_BACKUP_PATH"
    
    # Use rclone sync to mirror the backup directory
    log "Syncing $BACKUP_DIR to $cloud_path"
    
    if rclone $flags sync "$BACKUP_DIR" "$cloud_path" --exclude="*.log" --exclude="workflows/"; then
        log "✅ Sync completed successfully"
    else
        error "❌ Sync failed"
    fi
}

list_cloud_backups() {
    log "Listing backups in cloud storage..."
    
    local flags=$(get_rclone_flags)
    local cloud_path="$CLOUD_REMOTE:$CLOUD_BACKUP_PATH"
    
    if rclone $flags lsd "$cloud_path" 2>/dev/null; then
        echo ""
        info "To download a backup, use: rclone copy $cloud_path/BACKUP_DATE /local/path"
    else
        warn "No backups found in cloud storage or connection failed"
    fi
}

cleanup_old_cloud_backups() {
    if [ -z "$CLOUD_RETENTION_DAYS" ] || [ "$CLOUD_RETENTION_DAYS" -eq 0 ]; then
        return
    fi
    
    log "Cleaning up cloud backups older than $CLOUD_RETENTION_DAYS days..."
    
    # This is a placeholder - implementation would depend on cloud provider
    # Some providers support lifecycle policies for automatic cleanup
    warn "Automatic cloud cleanup not implemented yet"
    warn "Please set up lifecycle policies in your cloud provider dashboard"
}

configure_cloud_backup() {
    log "Configuring cloud backup settings..."
    
    # List available remotes
    echo "Available cloud storage remotes:"
    rclone --config="$RCLONE_CONFIG_FILE" listremotes
    echo ""
    
    read -p "Enter the remote name to use for backups: " remote_name
    
    # Validate remote exists
    if ! rclone --config="$RCLONE_CONFIG_FILE" listremotes | grep -q "^${remote_name}:$"; then
        error "Remote '$remote_name' not found"
    fi
    
    read -p "Enter cloud backup path [n8n-backups]: " backup_path
    backup_path=${backup_path:-n8n-backups}
    
    read -p "Enable encryption? (y/N): " enable_encryption
    if [[ "$enable_encryption" =~ ^[Yy]$ ]]; then
        enable_encryption="true"
    else
        enable_encryption="false"
    fi
    
    read -p "Retention period in days [30]: " retention_days
    retention_days=${retention_days:-30}
    
    # Create config file
    cat > "$CLOUD_CONFIG_FILE" << EOF
# n8n Cloud Backup Configuration
# Edit this file to customize your cloud backup settings

# Primary cloud storage remote (from rclone config)
CLOUD_REMOTE="$remote_name"

# Cloud backup path (folder in cloud storage)
CLOUD_BACKUP_PATH="$backup_path"

# Retention policy for cloud backups (days)
CLOUD_RETENTION_DAYS=$retention_days

# Enable encryption for cloud uploads (true/false)
ENABLE_ENCRYPTION=$enable_encryption

# Encryption password (leave empty to prompt)
ENCRYPTION_PASSWORD=""

# Upload bandwidth limit (e.g., "1M" for 1MB/s, empty for unlimited)
BANDWIDTH_LIMIT=""

# Enable compression for uploads (true/false)
ENABLE_COMPRESSION=true

# Parallel upload threads (1-8, more = faster but more bandwidth)
PARALLEL_UPLOADS=2

# Enable versioning (keep multiple versions of same backup)
ENABLE_VERSIONING=false
EOF
    
    log "Cloud backup configuration updated!"
    log "Remote: $remote_name"
    log "Path: $backup_path"
    log "Encryption: $enable_encryption"
    log "Retention: $retention_days days"
}

show_status() {
    log "Cloud backup status:"
    echo ""
    
    if [ -f "$CLOUD_CONFIG_FILE" ]; then
        source "$CLOUD_CONFIG_FILE"
        echo "Remote: $CLOUD_REMOTE"
        echo "Path: $CLOUD_BACKUP_PATH"
        echo "Encryption: $ENABLE_ENCRYPTION"
        echo "Retention: $CLOUD_RETENTION_DAYS days"
    else
        warn "Cloud backup not configured"
        return
    fi
    
    echo ""
    info "Testing connection..."
    if rclone --config="$RCLONE_CONFIG_FILE" ls "$CLOUD_REMOTE:" --max-depth 1 >/dev/null 2>&1; then
        log "✅ Cloud storage connection OK"
    else
        error "❌ Cloud storage connection failed"
    fi
    
    echo ""
    info "Recent uploads:"
    if [ -f "$BACKUP_DIR/cloud_upload.log" ]; then
        tail -5 "$BACKUP_DIR/cloud_upload.log" 2>/dev/null || echo "No upload history"
    else
        echo "No upload history"
    fi
}

# Main script logic
case "${1:---help}" in
    --upload|-u)
        check_prerequisites
        load_cloud_config
        upload_backup "$2"
        ;;
    --upload-latest)
        check_prerequisites
        load_cloud_config
        upload_latest
        ;;
    --upload-all)
        check_prerequisites
        load_cloud_config
        upload_all
        ;;
    --sync|-s)
        check_prerequisites
        load_cloud_config
        sync_to_cloud
        ;;
    --list-cloud|-l)
        check_prerequisites
        load_cloud_config
        list_cloud_backups
        ;;
    --configure|-c)
        check_prerequisites
        configure_cloud_backup
        ;;
    --status)
        check_prerequisites
        show_status
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