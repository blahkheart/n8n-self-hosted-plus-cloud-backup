#!/bin/bash

# Install rclone locally for n8n backup project

set -e

PROJECT_DIR="/home/blahkheart/Documents/projects/n8n"
BIN_DIR="$PROJECT_DIR/bin"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Create bin directory
mkdir -p "$BIN_DIR"

# Check if rclone is already installed globally
if command -v rclone >/dev/null 2>&1; then
    log "rclone is already installed globally: $(which rclone)"
    log "Version: $(rclone version | head -1)"
    exit 0
fi

# Check if rclone is already installed locally
if [ -f "$BIN_DIR/rclone" ]; then
    log "rclone is already installed locally: $BIN_DIR/rclone"
    log "Version: $($BIN_DIR/rclone version | head -1)"
    exit 0
fi

log "Installing rclone locally..."

# Download rclone
log "Downloading rclone..."
cd "$PROJECT_DIR"
curl -LO https://downloads.rclone.org/rclone-current-linux-amd64.zip

# Extract rclone
log "Extracting rclone..."
unzip -q rclone-current-linux-amd64.zip

# Find the extracted directory (it has a version number)
RCLONE_DIR=$(find . -name "rclone-v*-linux-amd64" -type d | head -1)

if [ -z "$RCLONE_DIR" ]; then
    echo "Error: Could not find extracted rclone directory"
    exit 1
fi

# Copy binary to bin directory
cp "$RCLONE_DIR/rclone" "$BIN_DIR/"
chmod +x "$BIN_DIR/rclone"

# Cleanup
rm -rf "$RCLONE_DIR"
rm rclone-current-linux-amd64.zip

log "rclone installed successfully to: $BIN_DIR/rclone"
log "Version: $($BIN_DIR/rclone version | head -1)"

# Add to PATH in current session
export PATH="$BIN_DIR:$PATH"

log "Installation completed!"
log "To use rclone in future sessions, add this to your ~/.bashrc:"
log "export PATH=\"$BIN_DIR:\$PATH\""