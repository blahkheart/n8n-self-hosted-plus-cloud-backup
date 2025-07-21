# n8n Backup and Restore Documentation

This directory contains a comprehensive backup and restore solution for your self-hosted n8n instance.

## 📁 Backup Scripts

| Script | Purpose | Schedule |
|--------|---------|----------|
| `backup-n8n.sh` | Full system backup (DB + data + config) | Daily at 2:00 AM |
| `export-workflows.sh` | Export workflows via API | Every 6 hours |
| `restore-n8n.sh` | Complete system restore | Manual |
| `setup-backup-cron.sh` | Automated scheduling setup | Manual |
| `setup-cloud-backup.sh` | Configure cloud storage providers | Manual |
| `cloud-backup.sh` | Upload backups to cloud storage | Automatic/Manual |
| `cloud-restore.sh` | Download and restore from cloud | Manual |
| `install-rclone.sh` | Install rclone for cloud integration | Manual |

## 🚀 Quick Start

### 1. Install Automated Backups
```bash
./setup-backup-cron.sh --install
```

### 2. Run Manual Backup
```bash
./backup-n8n.sh
```

### 3. Setup Cloud Backup (Recommended)
```bash
# Configure cloud storage provider
./setup-cloud-backup.sh --configure backblaze-b2

# Configure cloud backup settings
./cloud-backup.sh --configure

# Test upload
./cloud-backup.sh --upload-latest
```

### 4. Check Backup Status
```bash
./setup-backup-cron.sh --status
```

## 📋 What Gets Backed Up

### Full Backup (`backup-n8n.sh`)
- ✅ **PostgreSQL Database** - All workflows, executions, credentials metadata
- ✅ **n8n Data Volume** - User settings, encryption keys, file uploads
- ✅ **Configuration Files** - docker-compose.yml, .env, SSL certificates
- ✅ **Backup Manifest** - Restoration instructions and metadata

### Workflow Export (`export-workflows.sh`)
- ✅ **Individual Workflows** - Each workflow as separate JSON file
- ✅ **Combined Export** - All workflows in single file
- ✅ **Credentials Metadata** - Credential types and names (not actual secrets)
- ✅ **Restore Script** - Automated workflow import script

## 🔄 Restore Procedures

### Complete System Restore
```bash
# Interactive mode - choose from available backups
./restore-n8n.sh

# Restore specific backup
./restore-n8n.sh 20241201_143022

# List available backups
./restore-n8n.sh --list
```

### Workflow-Only Restore
```bash
# Extract workflow backup
tar xzf backups/n8n_workflows_20241201_143022.tar.gz
cd workflows_20241201_143022

# Run restore script
./restore_workflows.sh [host] [username] [password]
```

## 📊 Backup Schedule

| Type | Frequency | Time | Retention |
|------|-----------|------|-----------|
| Full Backup | Daily | 2:00 AM | 7 days |
| Workflow Export | Every 6 hours | 00:00, 06:00, 12:00, 18:00 | 7 days |

## 📁 Directory Structure

```
/home/blahkheart/Documents/projects/n8n/
├── backups/                          # Backup storage directory
│   ├── n8n_database_YYYYMMDD_HHMMSS.sql.gz
│   ├── n8n_data_YYYYMMDD_HHMMSS.tar.gz
│   ├── n8n_config_YYYYMMDD_HHMMSS.tar.gz
│   ├── n8n_workflows_YYYYMMDD_HHMMSS.tar.gz
│   ├── backup_manifest_YYYYMMDD_HHMMSS.txt
│   └── workflows/
│       └── workflows_YYYYMMDD_HHMMSS/
├── backup-n8n.sh                    # Main backup script
├── export-workflows.sh              # Workflow export script
├── restore-n8n.sh                   # Restore script
├── setup-backup-cron.sh             # Cron setup script
└── backup-service.sh                # Service management (auto-created)
```

## 🛠 Management Commands

### Cron Management
```bash
# Install automated backups
./setup-backup-cron.sh --install

# Remove automated backups
./setup-backup-cron.sh --remove

# Check status
./setup-backup-cron.sh --status

# View logs
./setup-backup-cron.sh --logs
```

### Service Management
```bash
# Run manual backup
./backup-service.sh run-backup

# Run manual workflow export
./backup-service.sh run-export

# Check cron service status
./backup-service.sh status
```

## 🔒 Security Considerations

### What's Protected
- Database encrypted at rest
- Workflow data and configurations
- SSL certificates and keys
- Environment variables (including auth credentials)

### What's NOT in Backups
- **Actual credential values** - Only metadata for security
- **Temporary files** - Cached data and logs
- **Running state** - Active executions (will restart on restore)

### Credential Recovery
After restore, you'll need to:
1. Re-enter credential values in n8n UI
2. Test all workflow connections
3. Update any changed API keys or passwords

## 🚨 Emergency Procedures

### Immediate Backup Before Changes
```bash
# Create emergency backup with timestamp
./backup-n8n.sh
```

### Quick Disaster Recovery
```bash
# 1. Stop containers
cd /home/blahkheart/Documents/projects/n8n
docker-compose down

# 2. Run restore (interactive)
./restore-n8n.sh

# 3. Verify restoration
curl -k https://blahkheart.localtest.me:5678/healthz
```

## 📈 Monitoring

### Log Locations
- **Backup logs**: `/var/log/n8n-backup.log`
- **Workflow logs**: `/var/log/n8n-workflow-export.log`
- **Docker logs**: `docker-compose logs`

### Health Checks
```bash
# Check backup files
ls -la backups/

# Check last backup
tail /var/log/n8n-backup.log

# Check services
docker-compose ps
```

## ☁️ Cloud Backup Integration

### Supported Cloud Providers

| Provider | Monthly Cost | Best For | Setup Command |
|----------|--------------|----------|---------------|
| **Backblaze B2** ⭐ | $5/TB | Most affordable, excellent rclone support | `./setup-cloud-backup.sh --configure backblaze-b2` |
| **AWS S3** | $23/TB | Enterprise, wide integration | `./setup-cloud-backup.sh --configure aws-s3` |
| **Google Drive** | $50/TB | Personal use, easy setup | `./setup-cloud-backup.sh --configure google-drive` |
| **DigitalOcean Spaces** | $5/TB | Simple pricing, S3-compatible | `./setup-cloud-backup.sh --configure digitalocean` |
| **Hetzner Storage** | €3.81/TB | European users, GDPR compliant | `./setup-cloud-backup.sh --configure hetzner` |

⭐ **Recommended**: Backblaze B2 offers the best value with free egress via Cloudflare

### Cloud Setup Process

#### 1. Install rclone
```bash
./install-rclone.sh
```

#### 2. Configure Cloud Provider
```bash
# For Backblaze B2 (recommended)
./setup-cloud-backup.sh --configure backblaze-b2

# List configured providers
./setup-cloud-backup.sh --list

# Test connection
./setup-cloud-backup.sh --test mybackup
```

#### 3. Configure Cloud Backup Settings
```bash
./cloud-backup.sh --configure
```

#### 4. Test Cloud Upload
```bash
# Upload latest backup
./cloud-backup.sh --upload-latest

# Check cloud status
./cloud-backup.sh --status
```

### Cloud Backup Features

✅ **Automatic Encryption** - GPG encryption with password protection  
✅ **Bandwidth Limiting** - Control upload/download speeds  
✅ **Parallel Transfers** - Faster uploads with multiple threads  
✅ **Retention Policies** - Automatic cleanup of old backups  
✅ **Compression** - Reduced storage costs  
✅ **Progress Monitoring** - Real-time upload/download progress  

### Cloud Management Commands

```bash
# Upload specific backup
./cloud-backup.sh --upload 20241201_143022

# Upload all local backups
./cloud-backup.sh --upload-all

# Sync local with cloud
./cloud-backup.sh --sync

# List cloud backups
./cloud-restore.sh --list

# Download backup from cloud
./cloud-restore.sh --download 20241201_143022

# Restore directly from cloud
./cloud-restore.sh --restore-latest
```

### Cloud Security

**Encrypted at Rest**: All backups encrypted with AES-256 before upload  
**Encrypted in Transit**: HTTPS/TLS for all transfers  
**Zero-Knowledge**: Cloud provider cannot decrypt your backups  
**Access Controls**: Provider-specific IAM and access policies  

### Cost Optimization Tips

1. **Use Backblaze B2 + Cloudflare** - Free egress bandwidth
2. **Enable compression** - Reduces storage by ~30-50%
3. **Set retention policies** - Auto-delete old backups
4. **Monitor usage** - Most providers have usage dashboards

## 🔧 Customization

### Modify Backup Schedule
Edit cron jobs:
```bash
crontab -e
```

### Change Retention Period
Edit the cleanup section in `backup-n8n.sh`:
```bash
# Keep last 14 days instead of 7
find "$BACKUP_DIR" -name "n8n_*" -type f -mtime +14 -delete
```

### Cloud Backup Configuration
Edit `cloud-backup.conf`:
```bash
# Cloud provider settings
CLOUD_REMOTE="mybackup"
CLOUD_BACKUP_PATH="n8n-backups"
CLOUD_RETENTION_DAYS=30
ENABLE_ENCRYPTION=true
BANDWIDTH_LIMIT="1M"
PARALLEL_UPLOADS=2
```

## 🆘 Troubleshooting

### Common Issues

**Container not running:**
```bash
docker-compose up -d
```

**Permission denied:**
```bash
chmod +x *.sh
```

**Database connection failed:**
```bash
docker-compose logs db
```

**Backup files missing:**
```bash
./setup-backup-cron.sh --status
```

### Support Commands
```bash
# Check container health
docker-compose ps

# View recent logs
docker-compose logs --tail=50

# Test n8n connectivity
curl -k https://blahkheart.localtest.me:5678/healthz

# Check disk space
df -h
```

## 📝 Best Practices

1. **Test restores regularly** - Monthly restore tests in safe environment
2. **Monitor backup logs** - Check for failures and storage space
3. **Keep offsite copies** - Use cloud storage for critical backups
4. **Document credential locations** - Maintain secure credential inventory
5. **Version control configurations** - Track docker-compose.yml changes
6. **Update backup scripts** - Keep scripts current with n8n updates

---

**Created**: $(date)  
**Version**: 1.0  
**Maintainer**: blahkheart  
**Contact**: Check logs in `/var/log/n8n-*.log`