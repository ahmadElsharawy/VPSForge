#!/bin/bash
# Delete every VPS created by VPSForge (with all its snapshots).
# Containers that VPSForge did not create are kept and counted.
uninstall_remove_containers() {
  local name
  UNINSTALL_FOREIGN_INSTANCES=0
  echo "[1/7] Removing VPS containers and their snapshots..."
  # If Incus cannot list instances, stop: we could not tell which containers are foreign.
  if ! incus list --all-projects -c n --format csv >/dev/null 2>&1; then
    echo "ERROR: Incus does not answer, so VPSForge cannot tell which containers exist. Nothing was removed."
    return 1
  fi
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
