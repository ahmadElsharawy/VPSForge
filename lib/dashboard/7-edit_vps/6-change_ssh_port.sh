#!/bin/bash
# VPSForge v1.0.0 — Edit: Change SSH Port.
edit_change_port() {
  local name="$1" port
  read -r -p "New SSH port [0=Back]: " port
  [ "$port" = "0" ] || [ -z "$port" ] && return
  change_vps_port "$name" "$port"
}
