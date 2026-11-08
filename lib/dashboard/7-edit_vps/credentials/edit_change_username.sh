#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Username.
edit_change_username() {
  local name="${1:-}" user
  read -r -p "New username [0=Back]: " user
  [ "$user" = "0" ] || [ -z "$user" ] && return
  change_vps_username "$name" "$user"
}
