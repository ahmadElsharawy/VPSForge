#!/bin/bash

# Repairs SSH and network connections across all detected VPS containers.
repair_connection_menu() {
  local n ok=0 failed=0
  local -a repair_list

  mapfile -t repair_list < <(
    incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true
  )

  [ "${#repair_list[@]}" -gt 0 ] || { echo "No VPS containers found."; return; }

  echo "Checking for IP conflicts..."
  resolve_ip_collisions
  echo
  echo "Repairing all VPS connections..."
  echo

  for n in "${repair_list[@]}"; do
    if _repair_single_vps "$n"; then
      ok=$((ok+1))
    else
      failed=$((failed+1))
    fi
    echo
  done

  cleanup_stale_rules
  echo
  echo "Repair summary: Success=$ok | Failed=$failed"
}
