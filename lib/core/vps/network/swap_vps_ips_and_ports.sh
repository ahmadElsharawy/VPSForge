#!/bin/bash
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

  configure_vps_network_device "$name_a" "$ip_b" || true
  configure_vps_network_device "$name_b" "$ip_a" || true

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
  update_vps_proxy_ip "$name_a" "$ip_b"
  update_vps_proxy_ip "$name_b" "$ip_a"
  sync_vps_metadata "$name_a"
  sync_vps_metadata "$name_b"

  echo "Swap complete."
}
