#!/bin/bash

# n8n Workflow Export Script
# Exports all workflows via n8n API

set -e

# Configuration
BACKUP_DIR="/home/blahkheart/Documents/projects/n8n/backups"
DATE=$(date +%Y%m%d_%H%M%S)
N8N_HOST="http://blahkheart.localtest.me:5678"
N8N_USER="blahkheart"
N8N_PASSWORD="1e75534f383711c167b60_amethyst0x9"

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
mkdir -p "$BACKUP_DIR/workflows"

log "Starting n8n workflow export..."

# Check if n8n is accessible
if ! curl -s --max-time 10 "$N8N_HOST/healthz" > /dev/null; then
    error "n8n instance is not accessible at $N8N_HOST"
fi

# Create auth header
AUTH_HEADER=$(echo -n "$N8N_USER:$N8N_PASSWORD" | base64)

# Export all workflows
WORKFLOW_BACKUP_DIR="$BACKUP_DIR/workflows/workflows_$DATE"
mkdir -p "$WORKFLOW_BACKUP_DIR"

log "Fetching workflow list..."
WORKFLOWS_JSON=$(curl -s \
    -H "Authorization: Basic $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    "$N8N_HOST/api/v1/workflows" || error "Failed to fetch workflows")

# Check if we got any workflows
if echo "$WORKFLOWS_JSON" | jq -e '.data | length > 0' > /dev/null 2>&1; then
    WORKFLOW_COUNT=$(echo "$WORKFLOWS_JSON" | jq '.data | length')
    log "Found $WORKFLOW_COUNT workflows to export"
    
    # Export each workflow individually
    echo "$WORKFLOWS_JSON" | jq -r '.data[] | .id' | while read -r workflow_id; do
        if [ -n "$workflow_id" ]; then
            log "Exporting workflow ID: $workflow_id"
            
            # Get workflow details
            WORKFLOW_DATA=$(curl -s \
                -H "Authorization: Basic $AUTH_HEADER" \
                -H "Content-Type: application/json" \
                "$N8N_HOST/api/v1/workflows/$workflow_id" || warn "Failed to export workflow $workflow_id")
            
            if [ -n "$WORKFLOW_DATA" ]; then
                # Get workflow name for filename (sanitize for filesystem)
                WORKFLOW_NAME=$(echo "$WORKFLOW_DATA" | jq -r '.data.name // "unnamed"' | sed 's/[^a-zA-Z0-9._-]/_/g')
                WORKFLOW_FILE="$WORKFLOW_BACKUP_DIR/${workflow_id}_${WORKFLOW_NAME}.json"
                
                echo "$WORKFLOW_DATA" | jq '.data' > "$WORKFLOW_FILE"
                log "Exported workflow: $WORKFLOW_FILE"
            fi
        fi
    done
    
    # Create a combined export file
    COMBINED_EXPORT="$WORKFLOW_BACKUP_DIR/all_workflows_combined.json"
    echo "$WORKFLOWS_JSON" > "$COMBINED_EXPORT"
    log "Created combined export: $COMBINED_EXPORT"
    
else
    log "No workflows found to export"
    echo '{"data": [], "nextCursor": null}' > "$WORKFLOW_BACKUP_DIR/no_workflows.json"
fi

# Export credentials (metadata only, not actual credential data for security)
log "Exporting credential metadata..."
CREDENTIALS_JSON=$(curl -s \
    -H "Authorization: Basic $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    "$N8N_HOST/api/v1/credentials" || warn "Failed to fetch credentials metadata")

if [ -n "$CREDENTIALS_JSON" ]; then
    echo "$CREDENTIALS_JSON" > "$WORKFLOW_BACKUP_DIR/credentials_metadata.json"
    CRED_COUNT=$(echo "$CREDENTIALS_JSON" | jq '.data | length' 2>/dev/null || echo "0")
    log "Exported metadata for $CRED_COUNT credentials"
fi

# Create workflow backup archive
WORKFLOW_ARCHIVE="$BACKUP_DIR/n8n_workflows_$DATE.tar.gz"
tar czf "$WORKFLOW_ARCHIVE" -C "$BACKUP_DIR/workflows" "workflows_$DATE"
log "Created workflow archive: $WORKFLOW_ARCHIVE"

# Create workflow restore script
RESTORE_SCRIPT="$WORKFLOW_BACKUP_DIR/restore_workflows.sh"
cat > "$RESTORE_SCRIPT" << 'EOF'
#!/bin/bash

# n8n Workflow Restore Script
# Usage: ./restore_workflows.sh [n8n_host] [username] [password]

N8N_HOST="${1:-http://blahkheart.localtest.me:5678}"
N8N_USER="${2:-blahkheart}"
N8N_PASSWORD="${3:-1e75534f383711c167b60_amethyst0x9}"

AUTH_HEADER=$(echo -n "$N8N_USER:$N8N_PASSWORD" | base64)

echo "Restoring workflows to $N8N_HOST..."

for workflow_file in *.json; do
    if [[ "$workflow_file" != "all_workflows_combined.json" && "$workflow_file" != "credentials_metadata.json" && "$workflow_file" != "no_workflows.json" ]]; then
        echo "Importing $workflow_file..."
        curl \
            -H "Authorization: Basic $AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -X POST \
            -d @"$workflow_file" \
            "$N8N_HOST/api/v1/workflows" || echo "Failed to import $workflow_file"
    fi
done

echo "Workflow restore completed!"
EOF

chmod +x "$RESTORE_SCRIPT"
log "Created workflow restore script: $RESTORE_SCRIPT"

# Create export manifest
MANIFEST_FILE="$WORKFLOW_BACKUP_DIR/export_manifest.txt"
cat > "$MANIFEST_FILE" << EOF
n8n Workflow Export Manifest
Created: $(date)
Export ID: $DATE

Files included:
- Individual workflow files: ${workflow_id}_${WORKFLOW_NAME}.json
- Combined export: all_workflows_combined.json
- Credentials metadata: credentials_metadata.json
- Restore script: restore_workflows.sh

Export info:
- Source: $N8N_HOST
- User: $N8N_USER
- Workflow count: $(ls -1 "$WORKFLOW_BACKUP_DIR"/*.json 2>/dev/null | grep -v "all_workflows_combined\|credentials_metadata\|no_workflows" | wc -l || echo "0")

Restore instructions:
1. Extract workflow archive: tar xzf n8n_workflows_${DATE}.tar.gz
2. Navigate to workflow directory: cd workflows_${DATE}
3. Run restore script: ./restore_workflows.sh [host] [user] [password]

Note: Credentials must be manually recreated for security reasons.
EOF

log "Export manifest created: $MANIFEST_FILE"

# Cleanup old workflow exports (keep last 7 days)
find "$BACKUP_DIR" -name "n8n_workflows_*" -type f -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_DIR/workflows" -name "workflows_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

# Show export summary
EXPORT_SIZE=$(du -sh "$WORKFLOW_BACKUP_DIR" | cut -f1)
log "Workflow export completed successfully!"
log "Export location: $WORKFLOW_BACKUP_DIR"
log "Archive: $WORKFLOW_ARCHIVE"
log "Export size: $EXPORT_SIZE"