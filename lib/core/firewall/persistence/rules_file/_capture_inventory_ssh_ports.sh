#!/bin/bash
# Ensure SSH port forwarding rules from VPS inventory are recorded in the target file.
_capture_inventory_ssh_ports() {
  local target_file="$1"
  local inst inst_ip inst_port ssh_entry

  while IFS='|' read -r inst inst_ip inst_port; do
    [ -n "$inst" ] || continue
    [ -z "$inst_port" ] && inst_port=$(get_port "$inst_ip" 2>/dev/null || true)
    if [ -n "$inst_ip" ] && [ "$inst_ip" != "-" ] && [[ "$inst_port" =~ ^[0-9]+$ ]]; then
      ssh_entry="tcp|0.0.0.0|${inst_port}|${inst_ip}|22"
      if ! awk -F'|' -v port="$inst_port" -v ip="$inst_ip" '$1 == "tcp" && $3 == port && $4 == ip && $5 == "22" { f = 1; exit } END { exit !f }' "$target_file" 2>/dev/null; then
        echo "$ssh_entry" >> "$target_file"
      fi
    fi
  done < <(vps_inventory)
}
