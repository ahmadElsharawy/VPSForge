#!/bin/bash
# Select a single backup file by delegating to select_backup_files.
select_backup_file() {
  select_backup_files "$@"
}
