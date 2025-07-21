# n8n Self-Hosted + Backup Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![n8n](https://img.shields.io/badge/n8n-Latest-orange.svg)](https://n8n.io)
[![Backup](https://img.shields.io/badge/Backup-Automated-green.svg)](#)

> **Enterprise-grade backup solution for self-hosted n8n with automated cloud integration**

A complete, production-ready backup and restore system for n8n workflow automation platform with local redundancy and cloud storage integration. Features automated daily backups, cloud synchronization, encryption, and disaster recovery.

## 🚀 Features

- **🔄 Self-hosted n8n setup** - Self-hosted n8n via docker
- **🔄 Automated Daily Backups** - PostgreSQL database, n8n data, configurations
- **☁️ Cloud Storage Integration** - Backblaze B2, AWS S3, Google Drive, and more
- **🔐 Security First** - Encryption at rest and in transit
- **🛡️ Disaster Recovery** - Complete system restoration capabilities
- **📊 Monitoring & Logging** - Comprehensive backup status and history
- **💰 Cost Optimized** - Starting at $0.40/year with Backblaze B2
- **🐳 Docker Ready** - Complete containerized solution
- **⚡ One-Click Setup** - Interactive wizard for easy configuration

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Cloud Providers](#-supported-cloud-providers)
- [Backup & Restore](#-backup--restore)
- [Monitoring](#-monitoring)
- [Contributing](#-contributing)
- [License](#-license)

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Linux/macOS environment
- Internet connection for cloud backup (optional)

### 1. Clone Repository

```bash
git clone https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup.git
cd n8n-self-hosted-plus-cloud-backup
```

### 2. Start n8n

```bash
docker compose up -d
```

### 3. Setup Automated Backups

```bash
# Run the interactive setup wizard
./backup-setup-wizard.sh
```

That's it! Your n8n instance is now running with enterprise-grade backup protection.

## 📦 Installation

### Method 1: One-Click Setup (Recommended)

```bash
# Clone and setup everything
curl -sSL https://raw.githubusercontent.com/blahkheart/n8n-self-hosted-plus-cloud-backup/main/install.sh | bash
```

### Method 2: Manual Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup.git
   cd n8n-self-hosted-plus-cloud-backup
   ```

2. **Start n8n services**
   ```bash
   docker compose up -d
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

4. **Run setup wizard**
   ```bash
   ./backup-setup-wizard.sh
   ```

### Method 3: Docker Hub

```bash
# Pull and run the complete solution
docker run -d \
  --name n8n-with-backups \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -v ./backups:/backups \
  yourusername/n8n-self-hosted-plus-cloud-backup:latest
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_HOST` | n8n host URL | `localhost` |
| `N8N_PORT` | n8n port | `5678` |
| `N8N_PROTOCOL` | HTTP/HTTPS | `https` |
| `POSTGRES_DB` | Database name | `n8n` |
| `POSTGRES_USER` | Database user | `n8n` |
| `POSTGRES_PASSWORD` | Database password | `required` |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | `auto-generated` |
| `GENERIC_TIMEZONE` | Timezone | `UTC` |

### SSL/TLS Setup

The solution includes automatic SSL certificate generation using mkcert for local development:

```bash
# Generate certificates (done automatically)
mkcert -install
mkcert yourdomain.localtest.me
```

## 🎯 Usage

### Daily Operations

```bash
# Manual backup
./backup-n8n.sh

# Upload to cloud
./cloud-backup.sh --upload-latest

# Check backup status
./setup-backup-cron.sh --status

# View recent logs
tail -f logs/backup.log
```

### Cloud Integration

```bash
# Configure cloud provider
./setup-cloud-backup.sh --configure backblaze-b2

# Test cloud connection
./setup-cloud-backup.sh --test mybackup

# List cloud backups
./cloud-restore.sh --list
```

### Disaster Recovery

```bash
# List available backups
./restore-n8n.sh --list

# Restore from local backup
./restore-n8n.sh 20241201_143022

# Restore from cloud
./cloud-restore.sh --restore-latest
```

## ☁️ Supported Cloud Providers

| Provider | Monthly Cost | Features | Setup Command |
|----------|--------------|----------|---------------|
| **Backblaze B2** ⭐ | $5/TB | Free egress via Cloudflare | `./setup-cloud-backup.sh --configure backblaze-b2` |
| **AWS S3** | $23/TB | Enterprise features | `./setup-cloud-backup.sh --configure aws-s3` |
| **Google Drive** | $60/TB | 15GB free tier | `./setup-cloud-backup.sh --configure google-drive` |
| **DigitalOcean** | $5/TB | Simple pricing | `./setup-cloud-backup.sh --configure digitalocean` |
| **Hetzner** | €3.81/TB | GDPR compliant | `./setup-cloud-backup.sh --configure hetzner` |
| **Custom S3** | Varies | Any S3-compatible | `./setup-cloud-backup.sh --configure custom` |

⭐ **Recommended**: Backblaze B2 offers the best value with free egress bandwidth via Cloudflare.

### Cost Calculator

| Backup Size | Daily Backups | Monthly Cost (B2) | Annual Cost |
|-------------|---------------|-------------------|-------------|
| 10MB | 30 backups | $0.00 | $0.40 |
| 100MB | 30 backups | $0.00 | $4.00 |
| 1GB | 30 backups | $0.15 | $1.80 |
| 10GB | 30 backups | $1.50 | $18.00 |

## 🔄 Backup & Restore

### What Gets Backed Up

✅ **Complete n8n Database** (PostgreSQL)
- All workflows and executions
- User settings and credentials metadata
- Execution history and logs

✅ **n8n Application Data**
- User uploads and files
- Custom node installations
- Application settings

✅ **System Configuration**
- Docker Compose configuration
- Environment variables
- SSL certificates
- Backup scripts and settings

### Backup Schedule

| Type | Frequency | Time | Retention |
|------|-----------|------|-----------|
| **Full System Backup** | Daily | 2:00 AM | 7 days local, 365 days cloud |
| **Workflow Export** | Every 6 hours | 00:00, 06:00, 12:00, 18:00 | 7 days |
| **Incremental Sync** | Real-time | On changes | Latest only |

### Restore Scenarios

#### 1. Complete Disaster Recovery
```bash
# Start from scratch on new system
git clone https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup.git
cd n8n-self-hosted-plus-cloud-backup
./cloud-restore.sh --restore-latest
```

#### 2. Workflow Recovery Only
```bash
# Restore just workflows (non-destructive)
./cloud-restore.sh --download 20241201_143022
cd backups/workflows_20241201_143022
./restore_workflows.sh
```

#### 3. Point-in-Time Recovery
```bash
# Restore to specific backup
./restore-n8n.sh 20241201_143022
```

## 🎛️ Monitoring

### Health Checks

```bash
# System status
./backup-service.sh status

# Cloud connection
./cloud-backup.sh --status

# Recent backups
ls -la backups/ | head -10

# Log analysis
grep "ERROR\|WARN" logs/backup.log
```

### Backup Verification

```bash
# Test restore (safe)
./restore-n8n.sh --list
./cloud-restore.sh --list

# Verify backup integrity
./backup-n8n.sh --verify 20241201_143022

# Check cloud sync status
./cloud-backup.sh --sync --dry-run
```

### Alerts & Notifications

Set up monitoring alerts:

```bash
# Add to crontab for email alerts
0 3 * * * /path/to/check-backup-status.sh || mail -s "Backup Failed" admin@domain.com
```

## 🔧 Advanced Configuration

### Custom Backup Retention

```bash
# Edit backup-n8n.sh
# Change retention from 7 to 30 days
find "$BACKUP_DIR" -name "n8n_*" -type f -mtime +30 -delete
```

### Bandwidth Optimization

```bash
# Edit cloud-backup.conf
BANDWIDTH_LIMIT="1M"        # Limit to 1MB/s
PARALLEL_UPLOADS=4          # Increase parallel transfers
ENABLE_COMPRESSION=true     # Enable compression
```

### Security Hardening

```bash
# Enable GPG encryption
ENABLE_ENCRYPTION=true
ENCRYPTION_PASSWORD="your-secure-password"

# Use application-specific passwords
# Never use main account credentials
```

## 🐳 Docker Configuration

### Docker Compose Structure

```yaml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - db
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://127.0.0.1:5678/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3

  db:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  n8n_data:
  postgres_data:
```

### Custom Images

Build your own image with backup tools pre-installed:

```dockerfile
FROM n8nio/n8n:latest

# Install backup tools
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    unzip \
    gpg \
    && rm -rf /var/lib/apt/lists/*

# Install rclone
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip rclone-current-linux-amd64.zip \
    && cp rclone-*/rclone /usr/local/bin/ \
    && chmod +x /usr/local/bin/rclone \
    && rm -rf rclone-*

# Copy backup scripts
COPY scripts/ /opt/backup/
RUN chmod +x /opt/backup/*.sh

USER node
```

## 🔍 Troubleshooting

### Common Issues

**Backup fails with permission error:**
```bash
# Fix file permissions
sudo chown -R $USER:$USER backups/
chmod +x *.sh
```

**Cloud upload fails:**
```bash
# Test connection
./setup-cloud-backup.sh --test mybackup

# Check credentials
cat .rclone/rclone.conf

# Verify bucket exists
rclone lsd mybackup:
```

**n8n won't start:**
```bash
# Check logs
docker compose logs n8n
docker compose logs db

# Verify environment
cat .env

# Reset database
docker compose down -v
docker compose up -d
```

**Restore fails:**
```bash
# Check backup integrity
tar -tzf backups/n8n_data_20241201_143022.tar.gz

# Verify PostgreSQL dump
gunzip -c backups/n8n_database_20241201_143022.sql.gz | head

# Check disk space
df -h
```

### Debug Mode

Enable verbose logging:

```bash
# Set debug mode
export DEBUG=1
./backup-n8n.sh

# Check detailed logs
tail -f logs/backup.log
tail -f logs/workflow-export.log
```

### Support

- 📧 **Issues**: [GitHub Issues](https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup/discussions)
- 📖 **Documentation**: [Wiki](https://github.com/blahkheart/n8n-self-hosted-plus-cloud-backup/wiki)
- 🆘 **Emergency**: Check [troubleshooting guide](docs/troubleshooting.md)

## 🤝 Contributing

We welcome contributions! This project aims to provide the best backup solution for the n8n community.

### Quick Contribution Guide

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/n8n-self-hosted-plus-cloud-backup.git
cd n8n-self-hosted-plus-cloud-backup

# Setup development environment
./dev-setup.sh

# Run tests
./run-tests.sh

# Submit PR
git push origin feature/your-feature
```

### Areas for Contribution

- 🌐 **Cloud Providers**: Add new backup destinations
- 🔐 **Security**: Enhance encryption and security features
- 📱 **Monitoring**: Improve alerting and notifications
- 🐳 **Containers**: Docker and Kubernetes improvements
- 📚 **Documentation**: Guides, tutorials, translations
- 🧪 **Testing**: Unit tests, integration tests
- 🎨 **UI/UX**: Web dashboard for backup management

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **n8n Team** - For building an amazing workflow automation platform
- **Backblaze** - For providing affordable cloud storage
- **rclone Project** - For excellent cloud storage integration
- **PostgreSQL Team** - For robust database technology
- **Docker Team** - For containerization platform
- **Community Contributors** - For testing, feedback, and improvements

## 📊 Project Statistics

![GitHub stars](https://img.shields.io/github/stars/blahkheart/n8n-self-hosted-plus-cloud-backup?style=social)
![GitHub forks](https://img.shields.io/github/forks/blahkheart/n8n-self-hosted-plus-cloud-backup?style=social)
![GitHub issues](https://img.shields.io/github/issues/blahkheart/n8n-self-hosted-plus-cloud-backup)
![GitHub license](https://img.shields.io/github/license/blahkheart/n8n-self-hosted-plus-cloud-backup)

---

**Made with ❤️ for the n8n community**

*If this project helps you, please consider giving it a ⭐ on GitHub!*