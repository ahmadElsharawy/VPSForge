#!/bin/bash
# Initialize or optimize the default Incus storage pool and root profile device.
_ensure_setup_storage() {
  # Optimize storage: recreate default dir pool as BTRFS for instant snapshots
  if [ -f /opt/vpsforge/.pool_migration_running ]; then
    migrate_default_pool_to_btrfs   # a migration was stopped half-way: finish it first
  elif incus storage show default >/dev/null 2>&1; then
    if incus storage show default | grep -q 'driver: dir'; then
      local used_by
      used_by=$(incus storage show default | grep -A 10 'used_by:' | grep -v 'used_by:' | grep -c '-' || true)
      if [ "$used_by" -eq 0 ]; then
        incus storage delete default >/dev/null 2>&1 || true
        create_storage_pool default || true
      else
        migrate_default_pool_to_btrfs
      fi
    fi
  else
    create_storage_pool default || true
  fi

  # Ensure default profile has root device pointing to default storage pool
  incus profile device add default root disk path=/ pool=default >/dev/null 2>&1 || true

  incus config set backups.compression_algorithm none >/dev/null 2>&1 || true

  ensure_host_swap 2>/dev/null || true
}
