#!/bin/bash
change_vps_port() {
  local name="$1" new_port="$2" ip
  [ -n "$name" ] && [ -n "$new_port" ] || return 1
  [[ "$new_port" =~ ^[0-9]+$ ]] || { echo "Invalid port."; return 1; }

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "ERROR: Could not get IP for $name."; return 1; }

  remove_ip "$ip"
  add_forward_rule "$ip" "$new_port"
  set_vps_saved_port "$name" "$new_port"
  echo "SSH port changed to $new_port for $name."
}
