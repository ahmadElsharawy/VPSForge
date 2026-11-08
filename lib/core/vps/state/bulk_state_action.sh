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
  pause
  return 0
}
