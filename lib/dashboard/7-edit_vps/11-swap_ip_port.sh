#!/bin/bash
# VPSForge v1.0.0 — Edit: Swap IP & Port with another VPS.
edit_swap_ip() {
  local name="$1" target_other
  list_available_vps || true
  read -r -p "Target VPS name to swap IP & Port with [0=Back]: " target_other
  [ "$target_other" = "0" ] || [ -z "$target_other" ] && return
  [ "$target_other" != "$name" ] && swap_vps_ips_and_ports "$name" "$target_other"
}
