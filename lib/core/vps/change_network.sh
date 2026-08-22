#!/bin/bash
# VPSForge v1.0.0 — VPS network IP, port, and IP swapping.

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

change_vps_ip() {
  local name="$1" new_ip="$2" old_ip port
  [ -n "$name" ] && [ -n "$new_ip" ] || return 1

  old_ip=$(get_ip "$name")
  port=$(get_port "$old_ip" 2>/dev/null || true)
  [ -n "$port" ] || port=$(get_vps_saved_port "$name")

  incus config set "$name" user.vpsforge.ip "$new_ip" 2>/dev/null || true

  if is_vps_running "$name"; then
    apply_guest_static_network "$name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
    configure_guest_dns "$name" || true
  fi

  [ -n "$old_ip" ] && remove_ip "$old_ip"
  [ -n "$port" ] && add_forward_rule "$new_ip" "$port"

  sync_vps_metadata "$name"
  echo "Internal IP changed to $new_ip for $name."
}

swap_vps_ips_and_ports() {
  local name_a="$1" name_b="$2"
  local ip_a ip_b port_a port_b

  ip_a=$(get_ip "$name_a"); ip_b=$(get_ip "$name_b")
  port_a=$(get_port "$ip_a" 2>/dev/null || true); port_b=$(get_port "$ip_b" 2>/dev/null || true)
  [ -n "$port_a" ] || port_a=$(get_vps_saved_port "$name_a")
  [ -n "$port_b" ] || port_b=$(get_vps_saved_port "$name_b")

  [ -n "$ip_a" ] && [ -n "$ip_b" ] || { echo "ERROR: Both VPS must have IPs."; return 1; }

  echo "Swapping: $name_a ($ip_a:$port_a) <-> $name_b ($ip_b:$port_b)"

  [ -n "$ip_a" ] && remove_ip "$ip_a"
  [ -n "$ip_b" ] && remove_ip "$ip_b"

  incus config set "$name_a" user.vpsforge.ip "$ip_b" 2>/dev/null || true
  incus config set "$name_b" user.vpsforge.ip "$ip_a" 2>/dev/null || true

  if is_vps_running "$name_a"; then
    apply_guest_static_network "$name_a" "$ip_b" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
  fi
  if is_vps_running "$name_b"; then
    apply_guest_static_network "$name_b" "$ip_a" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
  fi

  [ -n "$port_a" ] && add_forward_rule "$ip_b" "$port_a"
  [ -n "$port_b" ] && add_forward_rule "$ip_a" "$port_b"

  set_vps_saved_port "$name_a" "$port_a"
  set_vps_saved_port "$name_b" "$port_b"
  sync_vps_metadata "$name_a"
  sync_vps_metadata "$name_b"

  echo "Swap complete."
}
