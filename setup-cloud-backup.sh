#!/bin/bash

# n8n Cloud Backup Setup Script
# Configures cloud storage providers for automated backup uploads

set -e

# Configuration
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
BIN_DIR="$PROJECT_DIR/bin"
RCLONE_CONFIG_DIR="$PROJECT_DIR/.rclone"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"

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
    echo "  --configure [provider]    Configure cloud storage provider"
    echo "  --list                   List configured providers"
    echo "  --test [provider]        Test connection to provider"
    echo "  --remove [provider]      Remove provider configuration"
    echo "  --help                   Show this help message"
    echo ""
    echo "Supported providers:"
    echo "  backblaze-b2            Backblaze B2 (recommended)"
    echo "  aws-s3                  Amazon S3"
    echo "  google-drive            Google Drive"
    echo "  dropbox                 Dropbox"
    echo "  digitalocean            DigitalOcean Spaces"
    echo "  hetzner                 Hetzner Storage Box"
    echo "  custom                  Custom S3-compatible provider"
    echo ""
    echo "Examples:"
    echo "  $0 --configure backblaze-b2"
    echo "  $0 --test mybackup"
    echo "  $0 --list"
}

check_rclone() {
    if ! command -v rclone >/dev/null 2>&1; then
        error "rclone not found. Please run ./install-rclone.sh first"
    fi
    
    # Create rclone config directory
    mkdir -p "$RCLONE_CONFIG_DIR"
    
    log "Using rclone: $(which rclone)"
    log "Version: $(rclone version | head -1)"
}

configure_backblaze_b2() {
    local remote_name="$1"
    
    highlight "=== Configuring Backblaze B2 ==="
    echo ""
    echo "You'll need:"
    echo "1. Backblaze account (sign up at backblaze.com)"
    echo "2. Application Key ID and Application Key"
    echo "3. Bucket name (create one in B2 dashboard)"
    echo ""
    echo "To get your credentials:"
    echo "1. Go to https://secure.backblaze.com/app_keys.htm"
    echo "2. Create a new Application Key"
    echo "3. Copy the Key ID and Application Key"
    echo ""
    
    read -p "Enter your Application Key ID: " key_id
    read -p "Enter your Application Key: " -s app_key
    echo
    read -p "Enter your bucket name: " bucket_name
    
    # Create rclone config entry
    cat >> "$RCLONE_CONFIG_FILE" << EOF

[$remote_name]
type = b2
account = $key_id
key = $app_key
endpoint = 
EOF
    
    log "Backblaze B2 configured as '$remote_name'"
    log "Bucket: $bucket_name"
    
    # Test the connection
    if rclone --config="$RCLONE_CONFIG_FILE" ls "$remote_name:$bucket_name" >/dev/null 2>&1; then
        log "✅ Connection test successful!"
    else
        warn "❌ Connection test failed. Please check your credentials."
    fi
}

configure_aws_s3() {
    local remote_name="$1"
    
    highlight "=== Configuring Amazon S3 ==="
    echo ""
    echo "You'll need:"
    echo "1. AWS account"
    echo "2. Access Key ID and Secret Access Key"
    echo "3. S3 bucket name and region"
    echo ""
    
    read -p "Enter your Access Key ID: " access_key_id
    read -p "Enter your Secret Access Key: " -s secret_key
    echo
    read -p "Enter your bucket region (e.g., us-east-1): " region
    read -p "Enter your bucket name: " bucket_name
    
    cat >> "$RCLONE_CONFIG_FILE" << EOF

[$remote_name]
type = s3
provider = AWS
access_key_id = $access_key_id
secret_access_key = $secret_key
region = $region
endpoint = 
EOF
    
    log "AWS S3 configured as '$remote_name'"
    log "Region: $region, Bucket: $bucket_name"
}

configure_google_drive() {
    local remote_name="$1"
    
    highlight "=== Configuring Google Drive ==="
    echo ""
    echo "This will open a browser window for authentication."
    echo "Make sure you're logged into the correct Google account."
    echo ""
    
    # Use rclone config for interactive setup
    rclone --config="$RCLONE_CONFIG_FILE" config create "$remote_name" drive
    
    log "Google Drive configured as '$remote_name'"
}

configure_dropbox() {
    local remote_name="$1"
    
    highlight "=== Configuring Dropbox ==="
    echo ""
    echo "This will open a browser window for authentication."
    echo ""
    
    rclone --config="$RCLONE_CONFIG_FILE" config create "$remote_name" dropbox
    
    log "Dropbox configured as '$remote_name'"
}

configure_digitalocean() {
    local remote_name="$1"
    
    highlight "=== Configuring DigitalOcean Spaces ==="
    echo ""
    echo "You'll need:"
    echo "1. DigitalOcean account with Spaces enabled"
    echo "2. Spaces Access Key and Secret Key"
    echo "3. Space name and region"
    echo ""
    
    read -p "Enter your Spaces Access Key: " access_key
    read -p "Enter your Spaces Secret Key: " -s secret_key
    echo
    read -p "Enter your region (e.g., nyc3, fra1, sgp1): " region
    read -p "Enter your space name: " space_name
    
    cat >> "$RCLONE_CONFIG_FILE" << EOF

[$remote_name]
type = s3
provider = DigitalOcean
access_key_id = $access_key
secret_access_key = $secret_key
endpoint = ${region}.digitaloceanspaces.com
region = $region
EOF
    
    log "DigitalOcean Spaces configured as '$remote_name'"
    log "Region: $region, Space: $space_name"
}

configure_hetzner() {
    local remote_name="$1"
    
    highlight "=== Configuring Hetzner Storage Box ==="
    echo ""
    echo "You'll need:"
    echo "1. Hetzner Storage Box"
    echo "2. Username and password"
    echo "3. Storage Box hostname"
    echo ""
    
    read -p "Enter your Storage Box username: " username
    read -p "Enter your Storage Box password: " -s password
    echo
    read -p "Enter your Storage Box hostname (e.g., u123456.your-storagebox.de): " hostname
    
    cat >> "$RCLONE_CONFIG_FILE" << EOF

[$remote_name]
type = sftp
host = $hostname
user = $username
pass = $(echo "$password" | rclone obscure)
EOF
    
    log "Hetzner Storage Box configured as '$remote_name'"
    log "Host: $hostname"
}

configure_custom_s3() {
    local remote_name="$1"
    
    highlight "=== Configuring Custom S3-Compatible Provider ==="
    echo ""
    echo "This works with providers like:"
    echo "- Wasabi"
    echo "- MinIO"
    echo "- Cloudflare R2"
    echo "- Any S3-compatible service"
    echo ""
    
    read -p "Enter provider name: " provider_name
    read -p "Enter endpoint URL (e.g., s3.wasabisys.com): " endpoint
    read -p "Enter access key ID: " access_key_id
    read -p "Enter secret access key: " -s secret_key
    echo
    read -p "Enter region (if required): " region
    
    cat >> "$RCLONE_CONFIG_FILE" << EOF

[$remote_name]
type = s3
provider = Other
access_key_id = $access_key_id
secret_access_key = $secret_key
endpoint = $endpoint
region = $region
EOF
    
    log "$provider_name configured as '$remote_name'"
    log "Endpoint: $endpoint"
}

configure_provider() {
    local provider="$1"
    local remote_name
    
    read -p "Enter a name for this remote (e.g., 'mybackup'): " remote_name
    
    # Validate remote name
    if [[ ! "$remote_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Remote name must contain only letters, numbers, underscores, and hyphens"
    fi
    
    case "$provider" in
        backblaze-b2)
            configure_backblaze_b2 "$remote_name"
            ;;
        aws-s3)
            configure_aws_s3 "$remote_name"
            ;;
        google-drive)
            configure_google_drive "$remote_name"
            ;;
        dropbox)
            configure_dropbox "$remote_name"
            ;;
        digitalocean)
            configure_digitalocean "$remote_name"
            ;;
        hetzner)
            configure_hetzner "$remote_name"
            ;;
        custom)
            configure_custom_s3 "$remote_name"
            ;;
        *)
            error "Unknown provider: $provider"
            ;;
    esac
    
    echo ""
    log "Configuration completed!"
    log "Remote name: $remote_name"
    log "You can now use this remote in backup scripts"
    
    # Create a simple test
    echo ""
    read -p "Would you like to test the connection? (y/N): " test_conn
    if [[ "$test_conn" =~ ^[Yy]$ ]]; then
        test_provider "$remote_name"
    fi
}

list_providers() {
    if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
        warn "No cloud providers configured yet"
        echo "Run: $0 --configure [provider] to set up a provider"
        return
    fi
    
    log "Configured cloud storage providers:"
    rclone --config="$RCLONE_CONFIG_FILE" listremotes
    
    echo ""
    info "To test a provider: $0 --test [remote_name]"
    info "To remove a provider: $0 --remove [remote_name]"
}

test_provider() {
    local remote_name="$1"
    
    if [ -z "$remote_name" ]; then
        error "Please specify a remote name to test"
    fi
    
    log "Testing connection to '$remote_name'..."
    
    if rclone --config="$RCLONE_CONFIG_FILE" ls "$remote_name:" --max-depth 1 >/dev/null 2>&1; then
        log "✅ Connection to '$remote_name' successful!"
    else
        error "❌ Connection to '$remote_name' failed!"
    fi
}

remove_provider() {
    local remote_name="$1"
    
    if [ -z "$remote_name" ]; then
        error "Please specify a remote name to remove"
    fi
    
    if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
        error "No configuration file found"
    fi
    
    warn "This will remove the configuration for '$remote_name'"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rclone --config="$RCLONE_CONFIG_FILE" config delete "$remote_name" || error "Failed to remove '$remote_name'"
        log "Removed configuration for '$remote_name'"
    else
        log "Cancelled"
    fi
}

# Main script logic
case "${1:---help}" in
    --configure|-c)
        check_rclone
        if [ -z "$2" ]; then
            echo "Available providers:"
            echo "  backblaze-b2 (recommended - cheapest at $5/TB)"
            echo "  aws-s3"
            echo "  google-drive"
            echo "  dropbox"
            echo "  digitalocean"
            echo "  hetzner"
            echo "  custom"
            echo ""
            read -p "Select a provider: " provider
        else
            provider="$2"
        fi
        configure_provider "$provider"
        ;;
    --list|-l)
        check_rclone
        list_providers
        ;;
    --test|-t)
        check_rclone
        test_provider "$2"
        ;;
    --remove|-r)
        check_rclone
        remove_provider "$2"
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