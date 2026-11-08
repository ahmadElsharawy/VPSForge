#!/bin/bash
# Delete every VPS created by VPSForge (with all its snapshots).
# Containers that VPSForge did not create are kept and counted.
uninstall_remove_containers() {
  local name
  UNINSTALL_FOREIGN_INSTANCES=0
  echo "[1/7] Removing VPS containers and their snapshots..."
  while read -r name; do
    [ -n "$name" ] || continue
    if [ -n "$(incus config get "$name" user.vpsforge.num 2>/dev/null)" ]; then
      uninstall_run incus delete "$name" --force
    else
      UNINSTALL_FOREIGN_INSTANCES=$((UNINSTALL_FOREIGN_INSTANCES + 1))
      echo "  ! '$name' was not created by VPSForge: kept"
    fi
  done < <(incus list -c n --format csv 2>/dev/null)
}
