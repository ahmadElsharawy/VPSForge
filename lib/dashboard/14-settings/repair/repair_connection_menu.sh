#!/bin/bash

repair_connection_menu() {
  local n num ip saved_port preferred ok=0 failed=0
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
    num=$(get_num "$n")
    ip=$(get_ip "$n")
    preferred=$(vps_fixed_port "$num")
    if ! check_fixed_port_available "$n" "$ip" "$preferred"; then
      echo "FAILED: $n requires fixed port $preferred."
      failed=$((failed+1))
      echo
      continue
    fi
    set_vps_saved_port "$n" "$preferred"

    if repair_vps_connection "$n" "$preferred" </dev/null; then
      set_vps_saved_port "$n" "$preferred"
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
