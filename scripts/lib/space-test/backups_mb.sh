#!/bin/bash
# Total size of the backup directory in megabytes.
backups_mb() { du -sm "$BACKUP_DIR" 2>/dev/null | cut -f1; }
