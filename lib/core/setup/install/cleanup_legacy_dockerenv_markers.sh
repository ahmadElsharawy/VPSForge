#!/bin/bash
# Remove legacy /.dockerenv marker files from all Incus containers.
cleanup_legacy_dockerenv_markers() {
  local inst_list inst
  inst_list=$(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  [ -n "$inst_list" ] || return 0

  for inst in $inst_list; do
    # Remove /.dockerenv via incus file delete (supported for both running and stopped instances)
    incus file delete "$inst/.dockerenv" >/dev/null 2>&1 || true
    # Also verify via exec if container is running
    if is_vps_running "$inst"; then
      incus exec "$inst" -- sh -c 'test -e /.dockerenv && rm -f /.dockerenv' 2>/dev/null || true
    fi
  done
}
