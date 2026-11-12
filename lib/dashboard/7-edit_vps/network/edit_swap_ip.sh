#!/bin/bash
# Prompts for a target VPS to swap internal IP addresses and SSH ports with.
edit_swap_ip() {
  local name="${1:-}" target_other
  list_available_vps || true
  show_example "web2  (the other VPS: both swap IP address and SSH port)"
  read -r -p "Target VPS name to swap IP & Port with [0=Back]: " target_other
  { [ "$target_other" = "0" ] || [ -z "$target_other" ]; } && return
  target_other=$(_resolve_vps_token "$target_other")
  [ "$target_other" != "$name" ] && swap_vps_ips_and_ports "$name" "$target_other"
}
