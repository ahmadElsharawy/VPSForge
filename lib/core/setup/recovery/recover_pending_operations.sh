#!/bin/bash
# For every pending-operation record whose process is dead: cancel what Incus was still
# creating, remove the VPS completely (disk, IP, port, firewall) and delete the record.
recover_pending_operations() {
  local file name owner ip port
  [ -d "$PENDING_DIR" ] || return 0
  for file in "$PENDING_DIR"/*; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    IFS='|' read -r owner ip port < "$file"
    vps_state_owner_alive "$owner" && continue
    echo "Recovery: the creation of '$name' was interrupted. Removing everything it had reserved..."
    cleanup_failed_vps "$name" "$ip" "$port"
    pending_operation_clear "$name"
    echo "Recovery: '$name' removed completely."
  done
  return 0
}
