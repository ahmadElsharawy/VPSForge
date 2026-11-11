#!/bin/bash
# Swap the internal IP and SSH port of two VPSs (their forwards, websites and SSH ports follow).
#   swap_vps_ips_and_ports <vps_a> <vps_b>
swap_vps_ips_and_ports() {
  local name_a="$1" name_b="$2"
  local ip_a ip_b port_a port_b spare

  ip_a=$(get_ip "$name_a"); ip_b=$(get_ip "$name_b")
  port_a=$(get_port "$ip_a" 2>/dev/null || true); port_b=$(get_port "$ip_b" 2>/dev/null || true)
  [ -n "$port_a" ] || port_a=$(get_vps_saved_port "$name_a")
  [ -n "$port_b" ] || port_b=$(get_vps_saved_port "$name_b")

  [ -n "$ip_a" ] && [ -n "$ip_b" ] || { echo "ERROR: Both VPS must have IPs."; return 1; }
  [ "$ip_a" != "$ip_b" ] || { echo "ERROR: both VPSs have the same IP ($ip_a). Use Settings > Repair first."; return 1; }
  spare=$(free_vps_ip) || { echo "ERROR: no free address left in the VPS network for the swap."; return 1; }

  echo "Swapping: $name_a ($ip_a:$port_a) <-> $name_b ($ip_b:$port_b)"
  _swap_device_ips "$name_a" "$name_b" "$ip_a" "$ip_b" "$spare" || return 1

  remove_ip "$ip_a"
  remove_ip "$ip_b"
  incus config set "$name_a" user.vpsforge.ip "$ip_b"
  incus config set "$name_b" user.vpsforge.ip "$ip_a"

  if is_vps_running "$name_a"; then
    apply_guest_static_network "$name_a" "$ip_b" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || echo "WARNING: $name_a did not take $ip_b inside; restart it (main menu 5)."
  fi
  if is_vps_running "$name_b"; then
    apply_guest_static_network "$name_b" "$ip_a" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || echo "WARNING: $name_b did not take $ip_a inside; restart it (main menu 5)."
  fi

  remap_port_forwards_ip "$ip_a" "$ip_b" "$ip_b" "$ip_a"
  [ -n "$port_a" ] && vps_ssh_forward_enabled "$name_a" && add_forward_rule "$ip_b" "$port_a"
  [ -n "$port_b" ] && vps_ssh_forward_enabled "$name_b" && add_forward_rule "$ip_a" "$port_b"

  set_vps_saved_port "$name_a" "$port_a"
  set_vps_saved_port "$name_b" "$port_b"
  update_vps_proxy_ip "$name_a" "$ip_b"
  update_vps_proxy_ip "$name_b" "$ip_a"
  sync_vps_metadata "$name_a"
  sync_vps_metadata "$name_b"

  echo "Swap complete."
}
