# Quick Start Guide

Get your n8n backup solution running in under 5 minutes! 🚀

## 🎯 One-Line Install

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/n8n-backup-solution/main/install.sh | bash
```

That's it! The installer will:
- ✅ Download the complete solution
- ✅ Start n8n with PostgreSQL
- ✅ Generate SSL certificates
- ✅ Set up automated backups
- ✅ Configure cloud storage (optional)

## 📋 Manual Setup (3 Steps)

### Step 1: Clone & Start

```bash
# Clone the repository
git clone https://github.com/yourusername/n8n-backup-solution.git
cd n8n-backup-solution

# Start n8n services
docker compose up -d
```

### Step 2: Setup Backups

```bash
# Run the interactive wizard
./backup-setup-wizard.sh
```

### Step 3: Access n8n

Open your browser and go to:
- **HTTPS**: https://localhost:5678
- **HTTP**: http://localhost:5678

## ⚡ Quick Commands

```bash
# Manual backup
./backup-n8n.sh

# Upload to cloud
./cloud-backup.sh --upload-latest

# List backups
./restore-n8n.sh --list

# Check status
./setup-backup-cron.sh --status
```

## 🔧 Customization

Edit `.env` file to customize:
- Passwords and credentials
- Timezone and localization
- SSL/TLS configuration
- Backup schedules

## 💰 Cloud Storage (Optional)

Choose your provider and costs:

| Provider | Cost/TB/Month | Free Tier |
|----------|---------------|-----------|
| **Backblaze B2** | $5 | No |
| **Google Drive** | $60 | 15GB |
| **AWS S3** | $23 | 5GB (12 months) |
| **Dropbox** | $120 | 2GB |

Setup command:
```bash
./setup-cloud-backup.sh --configure backblaze-b2
```

## 🆘 Need Help?

- **Issues**: [GitHub Issues](https://github.com/yourusername/n8n-backup-solution/issues)
- **Docs**: [Full Documentation](README.md)
- **Community**: [Discussions](https://github.com/yourusername/n8n-backup-solution/discussions)

---

**Next Steps**: Check out the [full README](README.md) for advanced configuration and features!