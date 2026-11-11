#!/bin/bash
# Execute a state action (start, stop, restart) on all selected VPS containers.
bulk_state_action() {
  local action="$1" name
  ask_vps_selection || return 1
  show_selection
  for name in "${SELECTED_VPS[@]}"; do
    echo "$action $name..."
    incus "$action" "$name" || echo "FAILED: $name"
  done
  # logins of tunnels deleted while a VPS was stopped are removed now that it runs
  [ "$action" = "stop" ] || tunnel_pending_cleanup
  pause
  return 0
}
