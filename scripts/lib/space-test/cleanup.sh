#!/bin/bash
# Clean up test container, backups, and temporary files created during space test.
cleanup() {
  incus delete "$T" --force >/dev/null 2>&1 || true
  rm -f "$BACKUP_DIR"/space-test-backup*.tar* 2>/dev/null
  rm -rf "${SPACE_TMP:?}"
}
