#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Internal IP.
edit_change_ip() {
  local name="$1" new_ip
  read -r -p "New Internal IP (e.g. 10.82.200.12, 0=Back): " new_ip
  [ "$new_ip" = "0" ] || [ -z "$new_ip" ] && return
  change_vps_ip "$name" "$new_ip"
}
