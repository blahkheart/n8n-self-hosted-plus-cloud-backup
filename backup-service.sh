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
