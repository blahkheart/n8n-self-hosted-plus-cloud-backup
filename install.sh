#!/bin/bash

# n8n Backup Solution - One-Click Installer
# Automated installation script for complete n8n backup solution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/yourusername/n8n-backup-solution.git"
INSTALL_DIR="$HOME/n8n-backup-solution"
DOCKER_REQUIRED_VERSION="20.0"
COMPOSE_REQUIRED_VERSION="2.0"

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
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                  n8n Backup Solution Installer                ║"
    echo "║        Enterprise-grade backup for self-hosted n8n           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_system() {
    highlight "🔍 Checking System Requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Operating System: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log "Operating System: macOS"
    else
        error "Unsupported operating system: $OSTYPE"
    fi
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Please do not run this script as root"
    fi
    
    # Check required commands
    local required_commands=("git" "curl" "docker" "docker-compose")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            if [ "$cmd" = "docker-compose" ]; then
                # Try docker compose (newer syntax)
                if ! docker compose version >/dev/null 2>&1; then
                    error "$cmd is required but not installed"
                fi
            else
                error "$cmd is required but not installed"
            fi
        fi
    done
    
    log "All required commands are available"
}

check_docker() {
    highlight "🐳 Checking Docker Installation..."
    
    # Check Docker version
    local docker_version=$(docker --version | grep -oP '\\d+\\.\\d+' | head -1)
    if [ "$(printf '%s\\n' "$DOCKER_REQUIRED_VERSION" "$docker_version" | sort -V | head -n1)" != "$DOCKER_REQUIRED_VERSION" ]; then
        error "Docker version $DOCKER_REQUIRED_VERSION or higher is required. Found: $docker_version"
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
    fi
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | grep -oP '\\d+\\.\\d+' | head -1)
        if [ "$(printf '%s\\n' "$COMPOSE_REQUIRED_VERSION" "$compose_version" | sort -V | head -n1)" != "$COMPOSE_REQUIRED_VERSION" ]; then
            warn "Docker Compose version $COMPOSE_REQUIRED_VERSION or higher is recommended. Found: $compose_version"
        fi
    else
        # Try docker compose
        if ! docker compose version >/dev/null 2>&1; then
            error "Docker Compose is required but not found"
        fi
    fi
    
    log "Docker environment is ready"
}

clone_repository() {
    highlight "📦 Downloading n8n Backup Solution..."
    
    # Remove existing directory if it exists
    if [ -d "$INSTALL_DIR" ]; then
        warn "Directory $INSTALL_DIR already exists. Removing..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Clone the repository
    if git clone "$REPO_URL" "$INSTALL_DIR"; then
        log "Repository cloned successfully"
    else
        error "Failed to clone repository from $REPO_URL"
    fi
    
    cd "$INSTALL_DIR"
}

setup_environment() {
    highlight "⚙️  Setting Up Environment..."
    
    # Create .env file from example
    if [ -f ".env.example" ]; then
        cp .env.example .env
        log "Environment file created"
    fi
    
    # Generate random passwords and keys
    local postgres_password=$(openssl rand -hex 16)
    local encryption_key=$(openssl rand -hex 32)
    
    # Update .env file
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$postgres_password/" .env
    sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$encryption_key/" .env
    
    # Make scripts executable
    chmod +x *.sh
    
    log "Environment configured with secure passwords"
}

start_services() {
    highlight "🚀 Starting n8n Services..."
    
    # Start Docker services
    if docker compose up -d; then
        log "Services started successfully"
    else
        error "Failed to start Docker services"
    fi
    
    # Wait for services to be ready
    info "Waiting for services to start..."
    sleep 15
    
    # Check if services are healthy
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps | grep -q "Up (healthy)"; then
            log "Services are healthy and ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "Services failed to become healthy after $max_attempts attempts"
        fi
        
        info "Waiting for services to be ready... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

setup_ssl() {
    highlight "🔒 Setting Up SSL Certificates..."
    
    # Check if mkcert is available
    if command -v mkcert >/dev/null 2>&1; then
        log "mkcert found, generating SSL certificates..."
        
        # Install CA
        mkcert -install >/dev/null 2>&1 || warn "Failed to install mkcert CA"
        
        # Generate certificates
        if mkcert -cert-file localhost.pem -key-file localhost-key.pem localhost 127.0.0.1 ::1; then
            log "SSL certificates generated"
        else
            warn "Failed to generate SSL certificates - HTTPS may not work"
        fi
    else
        warn "mkcert not found - installing..."
        
        # Install mkcert based on OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y libnss3-tools
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y nss-tools
            fi
            
            # Download and install mkcert
            curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
            chmod +x mkcert-v*-linux-amd64
            sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
            
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew >/dev/null 2>&1; then
                brew install mkcert
            else
                warn "Please install Homebrew and run: brew install mkcert"
            fi
        fi
        
        # Try again
        if command -v mkcert >/dev/null 2>&1; then
            mkcert -install
            mkcert -cert-file localhost.pem -key-file localhost-key.pem localhost 127.0.0.1 ::1
            log "SSL certificates configured"
        else
            warn "Could not install mkcert - using HTTP only"
        fi
    fi
}

run_backup_wizard() {
    highlight "🎯 Running Backup Setup Wizard..."
    
    echo ""
    echo "The backup setup wizard will configure:"
    echo "  • Automated daily backups"
    echo "  • Cloud storage integration (optional)"
    echo "  • Monitoring and logging"
    echo ""
    
    read -p "Run backup setup wizard now? (Y/n): " run_wizard
    
    if [[ ! "$run_wizard" =~ ^[Nn]$ ]]; then
        if ./backup-setup-wizard.sh; then
            log "Backup system configured successfully"
        else
            warn "Backup wizard encountered issues - you can run it later"
        fi
    else
        info "Skipping backup wizard - you can run it later with: ./backup-setup-wizard.sh"
    fi
}

show_completion() {
    highlight "🎉 Installation Complete!"
    
    echo ""
    echo "Your n8n backup solution is ready!"
    echo ""
    echo "📍 Installation Directory: $INSTALL_DIR"
    echo "🌐 n8n URL: https://localhost:5678"
    echo "📊 Default Credentials: Check .env file"
    echo ""
    
    echo "🚀 Next Steps:"
    echo ""
    echo "1. Open n8n in your browser:"
    echo "   https://localhost:5678"
    echo ""
    echo "2. Complete n8n initial setup"
    echo ""
    echo "3. Configure cloud backup (if not done):"
    echo "   cd $INSTALL_DIR"
    echo "   ./setup-cloud-backup.sh --configure backblaze-b2"
    echo ""
    echo "4. Test your backup system:"
    echo "   ./backup-n8n.sh"
    echo "   ./cloud-backup.sh --upload-latest"
    echo ""
    
    echo "📚 Documentation:"
    echo "  • README.md - Complete documentation"
    echo "  • docs/ - Additional guides and tutorials"
    echo ""
    
    echo "🆘 Need Help?"
    echo "  • GitHub Issues: https://github.com/yourusername/n8n-backup-solution/issues"
    echo "  • Documentation: https://github.com/yourusername/n8n-backup-solution/wiki"
    echo ""
    
    echo "🤝 Contributing:"
    echo "  • Star the project: https://github.com/yourusername/n8n-backup-solution"
    echo "  • Report issues and suggest improvements"
    echo "  • Share with the n8n community"
    echo ""
    
    log "Installation completed successfully!"
}

cleanup_on_error() {
    if [ -d "$INSTALL_DIR" ]; then
        warn "Cleaning up due to error..."
        cd "$HOME"
        rm -rf "$INSTALL_DIR"
    fi
}

main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    show_banner
    
    echo "This script will install and configure the complete n8n backup solution."
    echo "It includes n8n, PostgreSQL, automated backups, and cloud integration."
    echo ""
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    echo ""
    
    check_system
    echo ""
    
    check_docker
    echo ""
    
    clone_repository
    echo ""
    
    setup_environment
    echo ""
    
    setup_ssl
    echo ""
    
    start_services
    echo ""
    
    run_backup_wizard
    echo ""
    
    show_completion
}

# Run the installer
main "$@"