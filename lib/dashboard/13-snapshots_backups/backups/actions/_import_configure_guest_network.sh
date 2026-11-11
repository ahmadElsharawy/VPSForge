#!/bin/bash
# Configure Incus compatibility profile, network device, static IP, DNS and hostname for imported container.
_import_configure_guest_network() {
  local target_name="$1" new_ip="$2" new_num="$3" new_port="$4"

  echo "[  75% ] Applying Incus compatibility & basic network..."
  incus config unset "$target_name" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$target_name" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device unset "$target_name" eth0 hwaddr >/dev/null 2>&1 || true
  apply_incus_compatibility_profile "$target_name" >/dev/null 2>&1 || true
  configure_vps_network_device "$target_name" "$new_ip" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ip "$new_ip" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.num "$new_num" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ssh_port "$new_port" >/dev/null 2>&1 || true

  echo "[  80% ] Starting container $target_name..."
  incus start "$target_name" 2>/dev/null || true
  wait_ready "$target_name" >/dev/null 2>&1 || true

  incus exec "$target_name" -- rm -f /.dockerenv >/dev/null 2>&1 || true   # backups from old versions may carry the Docker marker
  echo "[  85% ] Waiting for network interface (eth0)..."
  wait_guest_eth0 "$target_name" >/dev/null 2>&1 || true

  echo "[  90% ] Applying static IP ($new_ip) & DNS..."
  apply_guest_static_network "$target_name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
  configure_guest_dns "$target_name" >/dev/null 2>&1 || true
  set_guest_hostname "$target_name"
}
