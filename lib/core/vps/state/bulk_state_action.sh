#!/bin/bash
# VPSForge v1.0.0 — VPS bulk state action helper.

bulk_state_action() {
  local action="$1" n
  ask_vps_selection || return 1
  show_selection
  for n in "${SELECTED_VPS[@]}"; do
    echo "$action $n..."
    incus "$action" "$n" || echo "FAILED: $n"
  done
  # logins of tunnels deleted while a VPS was stopped are removed now that it runs
  [ "$action" = "stop" ] || tunnel_pending_cleanup
  pause
  return 0
}
