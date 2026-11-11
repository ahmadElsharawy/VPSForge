#!/bin/bash
# Change the external SSH port forward of a VPS.
change_vps_port() {
  local name="$1" new_port="$2" ip old_port
  [ -n "$name" ] && [ -n "$new_port" ] || return 1
  [[ "$new_port" =~ ^[0-9]+$ ]] || { echo "Invalid port."; return 1; }
  if [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ] || [ "$new_port" = "80" ] || [ "$new_port" = "443" ]; then
    echo "ERROR: Choose a port between 1024 and 65535 (22, 80 and 443 belong to the server)."
    return 1
  fi

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "ERROR: Could not get IP for $name."; return 1; }
  check_fixed_port_available "$name" "$ip" "$new_port" || return 1

  old_port=$(get_port "$ip" 2>/dev/null || true)
  remove_port "$old_port"   # only the old SSH forward; other forwards of this VPS stay
  vps_ssh_forward_enabled "$name" && add_forward_rule "$ip" "$new_port"
  set_vps_saved_port "$name" "$new_port"
  sync_vps_metadata "$name"
  echo "SSH port changed to $new_port for $name."
}
