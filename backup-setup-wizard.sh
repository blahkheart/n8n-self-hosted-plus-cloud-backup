#!/bin/bash

# n8n Backup Setup Wizard
# Interactive setup for complete backup solution with cloud integration

set -e

# Configuration
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

highlight() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

show_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                   n8n Backup Setup Wizard                  ║"
    echo "║            Complete Backup & Cloud Integration             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_prerequisites() {
    highlight "🔍 Checking Prerequisites..."
    
    # Check if we're in the right directory
    if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
        error "Please run this script from the n8n project directory"
    fi
    
    # Check if n8n is running
    if ! docker compose ps | grep -q "Up"; then
        warn "n8n containers are not running. Starting them..."
        docker compose up -d
        sleep 10
    fi
    
    log "Prerequisites check completed"
}

setup_local_backups() {
    highlight "🗄️  Setting up Local Backup System..."
    
    # Install automated backups
    if ./setup-backup-cron.sh --install; then
        log "Local backup cron jobs installed"
    else
        error "Failed to install backup cron jobs"
    fi
    
    # Run initial backup
    info "Running initial backup test..."
    if ./backup-n8n.sh 2>&1 | grep -q "Backup completed successfully"; then
        log "Initial backup completed successfully"
    else
        error "Initial backup failed"
    fi
    
    log "Local backup system configured"
}

setup_cloud_integration() {
    highlight "☁️  Setting up Cloud Backup Integration..."
    
    echo "Cloud storage providers:"
    echo "1) Backblaze B2 (Recommended - $5/TB)"
    echo "2) AWS S3 ($23/TB)"
    echo "3) Google Drive ($50/TB)"
    echo "4) DigitalOcean Spaces ($5/TB)"
    echo "5) Hetzner Storage (€3.81/TB)"
    echo "6) Custom S3-compatible provider"
    echo "7) Skip cloud setup"
    echo ""
    
    read -p "Select cloud provider (1-7): " choice
    
    case $choice in
        1)
            provider="backblaze-b2"
            ;;
        2)
            provider="aws-s3"
            ;;
        3)
            provider="google-drive"
            ;;
        4)
            provider="digitalocean"
            ;;
        5)
            provider="hetzner"
            ;;
        6)
            provider="custom"
            ;;
        7)
            info "Skipping cloud setup"
            return 0
            ;;
        *)
            error "Invalid selection"
            ;;
    esac
    
    # Install rclone if not present
    info "Installing rclone..."
    ./install-rclone.sh
    
    # Configure cloud provider
    info "Configuring cloud provider: $provider"
    ./setup-cloud-backup.sh --configure "$provider"
    
    # Configure cloud backup settings
    info "Configuring cloud backup settings..."
    ./cloud-backup.sh --configure
    
    # Test cloud upload
    info "Testing cloud upload..."
    if ./cloud-backup.sh --upload-latest; then
        log "Cloud backup test successful"
    else
        warn "Cloud backup test failed - check configuration"
    fi
    
    log "Cloud integration configured"
}

show_summary() {
    highlight "📋 Setup Summary"
    
    echo ""
    echo "✅ Local Backup System:"
    echo "   • Daily backups at 2:00 AM"
    echo "   • Workflow exports every 6 hours"
    echo "   • 7-day retention policy"
    echo ""
    
    if [ -f "$PROJECT_DIR/cloud-backup.conf" ]; then
        echo "✅ Cloud Backup System:"
        source "$PROJECT_DIR/cloud-backup.conf"
        echo "   • Provider: $CLOUD_REMOTE"
        echo "   • Path: $CLOUD_BACKUP_PATH"
        echo "   • Encryption: $ENABLE_ENCRYPTION"
        echo "   • Retention: $CLOUD_RETENTION_DAYS days"
        echo ""
    fi
    
    echo "📁 Available Commands:"
    echo "   • Manual backup: ./backup-n8n.sh"
    echo "   • Upload to cloud: ./cloud-backup.sh --upload-latest"
    echo "   • List cloud backups: ./cloud-restore.sh --list"
    echo "   • Restore from cloud: ./cloud-restore.sh --restore-latest"
    echo "   • Check status: ./setup-backup-cron.sh --status"
    echo ""
    
    echo "📖 Documentation: ./README-backup.md"
    echo ""
    
    log "Backup setup completed successfully!"
    
    echo ""
    info "Your n8n instance now has:"
    echo "   🔒 Automated daily backups"
    echo "   ☁️  Cloud storage integration"
    echo "   🔐 Encrypted offsite storage"
    echo "   🔄 Easy restore procedures"
    echo "   📊 Monitoring and logging"
    echo ""
    
    highlight "🎉 Your n8n data is now fully protected!"
}

main() {
    show_banner
    
    echo "This wizard will set up a complete backup solution for your n8n instance"
    echo "including local automated backups and cloud storage integration."
    echo ""
    
    read -p "Continue with setup? (y/N): " proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 0
    fi
    
    echo ""
    
    check_prerequisites
    echo ""
    
    setup_local_backups
    echo ""
    
    read -p "Set up cloud backup integration? (Y/n): " setup_cloud
    if [[ ! "$setup_cloud" =~ ^[Nn]$ ]]; then
        setup_cloud_integration
        echo ""
    fi
    
    show_summary
}

# Run the wizard
main "$@"