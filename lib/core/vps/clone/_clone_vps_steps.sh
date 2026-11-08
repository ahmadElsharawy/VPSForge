#!/bin/bash
# The copy-and-reconfigure steps of clone_vps (always call clone_vps, which guards them).
#   _clone_vps_steps <source> <new_name> <num> <ip> <port>
_clone_vps_steps() {
  local src="$1" new="$2" num="$3" ip="$4" port="$5"

  check_fixed_port_available "$new" "$ip" "$port" || return 1
  echo "Cloning $src -> $new (IP $ip, SSH port $port)..."

  incus copy "$src" "$new" --instance-only || { echo "ERROR: incus could not copy $src (see message above)."; return 1; }
  mark_vps_state "$new" cloning

  # A fresh identity: new network address and none of the source's domains or port forwards.
  incus config unset "$new" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$new" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device unset "$new" eth0 hwaddr >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.proxy >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.last_restore >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.count >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.summary >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.rules >/dev/null 2>&1 || true
  incus config set "$new" user.vpsforge.ip "$ip" >/dev/null 2>&1 || true
  incus config set "$new" user.vpsforge.num "$num" >/dev/null 2>&1 || true
  configure_vps_network_device "$new" "$ip" || { echo "ERROR: could not give $new its network address."; return 1; }

  incus start "$new" || { echo "ERROR: the copy $new did not start."; return 1; }
  wait_ready "$new" || { echo "ERROR: the copy $new did not become ready."; return 1; }
  incus exec "$new" -- rm -f /.dockerenv >/dev/null 2>&1 || true
  wait_guest_eth0 "$new" || { echo "ERROR: the network of $new did not come up."; return 1; }

  apply_guest_static_network "$new" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || { echo "ERROR: could not set the IP inside $new."; return 1; }
  configure_guest_dns "$new" >/dev/null 2>&1 || true
  set_guest_hostname "$new" "$src"

  add_forward_rule "$ip" "$port"
  set_vps_saved_port "$new" "$port"
  sync_vps_metadata "$new"
  mark_vps_state "$new" ""
  echo "Done: $new is a copy of $src:  ssh $(get_vps_user "$new")@$PUBLIC_IP -p $port"
}
