#!/bin/bash
# Print a formatted disk usage snapshot line for the space test.
report() {
  printf '%-34s host_free=%6sMB  pool_used=%6sMB  default.img_on_disk=%6sMB  backup_dir=%5sMB\n' \
    "$1" "$(host_free_mb)" "$(pool_used_mb)" "$(img_mb)" "$(backups_mb)"
}
