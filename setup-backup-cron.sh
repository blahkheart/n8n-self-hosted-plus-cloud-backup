#!/bin/bash

# n8n Backup Cron Setup Script
# Sets up automated backup scheduling

set -e

# Configuration
PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
BACKUP_SCRIPT="$PROJECT_DIR/backup-n8n.sh"
WORKFLOW_SCRIPT="$PROJECT_DIR/export-workflows.sh"
CRON_BACKUP_LOG="$PROJECT_DIR/logs/backup.log"
CRON_WORKFLOW_LOG="$PROJECT_DIR/logs/workflow-export.log"

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
    echo "  --install      Install backup cron jobs"
    echo "  --remove       Remove backup cron jobs"
    echo "  --status       Show current cron jobs"
    echo "  --logs         Show backup logs"
    echo "  --help         Show this help message"
    echo ""
    echo "Default backup schedule:"
    echo "  - Full backup: Daily at 2:00 AM"
    echo "  - Workflow export: Every 6 hours"
}

check_prerequisites() {
    # Check if backup scripts exist
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        error "Backup script not found: $BACKUP_SCRIPT"
    fi
    
    if [ ! -f "$WORKFLOW_SCRIPT" ]; then
        error "Workflow export script not found: $WORKFLOW_SCRIPT"
    fi
    
    # Check if scripts are executable
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        log "Making backup script executable..."
        chmod +x "$BACKUP_SCRIPT"
    fi
    
    if [ ! -x "$WORKFLOW_SCRIPT" ]; then
        log "Making workflow script executable..."
        chmod +x "$WORKFLOW_SCRIPT"
    fi
    
    log "Prerequisites check passed"
}

install_cron_jobs() {
    log "Installing n8n backup cron jobs..."
    
    # Check prerequisites
    check_prerequisites
    
    # Create log directory and files
    mkdir -p "$PROJECT_DIR/logs"
    touch "$CRON_BACKUP_LOG" "$CRON_WORKFLOW_LOG"
    
    # Create temporary crontab file
    local temp_cron=$(mktemp)
    
    # Get existing crontab (if any)
    crontab -l 2>/dev/null > "$temp_cron" || true
    
    # Remove any existing n8n backup entries
    sed -i '/# n8n backup/d' "$temp_cron"
    sed -i '/backup-n8n\.sh/d' "$temp_cron"
    sed -i '/export-workflows\.sh/d' "$temp_cron"
    
    # Add new cron jobs
    cat >> "$temp_cron" << EOF

# n8n backup jobs - DO NOT EDIT MANUALLY
# Full backup daily at 2:00 AM
0 2 * * * $BACKUP_SCRIPT >> $CRON_BACKUP_LOG 2>&1

# Workflow export every 6 hours
0 */6 * * * $WORKFLOW_SCRIPT >> $CRON_WORKFLOW_LOG 2>&1

EOF
    
    # Install the new crontab
    crontab "$temp_cron"
    rm "$temp_cron"
    
    log "Cron jobs installed successfully!"
    info "Backup schedule:"
    info "  - Full backup: Daily at 2:00 AM"
    info "  - Workflow export: Every 6 hours (00:00, 06:00, 12:00, 18:00)"
    info "Logs:"
    info "  - Backup log: $CRON_BACKUP_LOG"
    info "  - Workflow log: $CRON_WORKFLOW_LOG"
}

remove_cron_jobs() {
    log "Removing n8n backup cron jobs..."
    
    # Create temporary crontab file
    local temp_cron=$(mktemp)
    
    # Get existing crontab
    if crontab -l 2>/dev/null > "$temp_cron"; then
        # Remove n8n backup entries
        sed -i '/# n8n backup/d' "$temp_cron"
        sed -i '/backup-n8n\.sh/d' "$temp_cron"
        sed -i '/export-workflows\.sh/d' "$temp_cron"
        
        # Install the modified crontab
        crontab "$temp_cron"
        log "n8n backup cron jobs removed successfully!"
    else
        warn "No existing crontab found"
    fi
    
    rm "$temp_cron"
}

show_status() {
    log "Current cron jobs:"
    echo ""
    
    if crontab -l 2>/dev/null | grep -E "(backup-n8n|export-workflows)" >/dev/null; then
        info "n8n backup cron jobs found:"
        crontab -l 2>/dev/null | grep -E "(backup-n8n|export-workflows|# n8n backup)" || true
    else
        warn "No n8n backup cron jobs found"
    fi
    
    echo ""
    info "Log files:"
    if [ -f "$CRON_BACKUP_LOG" ]; then
        local backup_size=$(du -h "$CRON_BACKUP_LOG" | cut -f1)
        echo "  - Backup log: $CRON_BACKUP_LOG ($backup_size)"
    else
        echo "  - Backup log: $CRON_BACKUP_LOG (not found)"
    fi
    
    if [ -f "$CRON_WORKFLOW_LOG" ]; then
        local workflow_size=$(du -h "$CRON_WORKFLOW_LOG" | cut -f1)
        echo "  - Workflow log: $CRON_WORKFLOW_LOG ($workflow_size)"
    else
        echo "  - Workflow log: $CRON_WORKFLOW_LOG (not found)"
    fi
    
    echo ""
    info "Cron service status:"
    if systemctl is-active --quiet cron; then
        echo "  - Cron service: Running"
    else
        warn "  - Cron service: Not running"
    fi
}

show_logs() {
    log "Recent backup logs:"
    echo ""
    
    if [ -f "$CRON_BACKUP_LOG" ]; then
        info "=== Backup Log (last 20 lines) ==="
        tail -20 "$CRON_BACKUP_LOG" 2>/dev/null || echo "Log file is empty"
    else
        warn "Backup log not found: $CRON_BACKUP_LOG"
    fi
    
    echo ""
    
    if [ -f "$CRON_WORKFLOW_LOG" ]; then
        info "=== Workflow Export Log (last 20 lines) ==="
        tail -20 "$CRON_WORKFLOW_LOG" 2>/dev/null || echo "Log file is empty"
    else
        warn "Workflow export log not found: $CRON_WORKFLOW_LOG"
    fi
}

# Create a service management script
create_service_script() {
    local service_script="$PROJECT_DIR/backup-service.sh"
    
    cat > "$service_script" << 'EOF'
#!/bin/bash

# n8n Backup Service Management Script

case "$1" in
    start)
        echo "Starting backup service..."
        sudo systemctl start cron
        echo "Backup service started"
        ;;
    stop)
        echo "Stopping backup service..."
        sudo systemctl stop cron
        echo "Backup service stopped"
        ;;
    restart)
        echo "Restarting backup service..."
        sudo systemctl restart cron
        echo "Backup service restarted"
        ;;
    status)
        systemctl status cron
        ;;
    run-backup)
        echo "Running manual backup..."
        /home/blahkheart/Documents/projects/n8n/backup-n8n.sh
        ;;
    run-export)
        echo "Running manual workflow export..."
        /home/blahkheart/Documents/projects/n8n/export-workflows.sh
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|run-backup|run-export}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$service_script"
    log "Service management script created: $service_script"
}

# Main script logic
case "${1:---help}" in
    --install|-i)
        install_cron_jobs
        create_service_script
        ;;
    --remove|-r)
        remove_cron_jobs
        ;;
    --status|-s)
        show_status
        ;;
    --logs|-l)
        show_logs
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