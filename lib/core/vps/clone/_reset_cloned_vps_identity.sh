#!/bin/bash
# Reset network hardware addresses, metadata, and tunnels inherited from the clone source.
#   _reset_cloned_vps_identity <new_name> <num> <ip>
_reset_cloned_vps_identity() {
  local new="$1" num="$2" ip="$3"
  incus config unset "$new" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$new" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device unset "$new" eth0 hwaddr >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.proxy >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.tunnels >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.last_restore >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.count >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.summary >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.port_forwards.rules >/dev/null 2>&1 || true
  incus config unset "$new" user.vpsforge.vpn >/dev/null 2>&1 || true
  # The clone may be stopped (incus exec would fail): remove the service's boot link directly.
  incus file delete "$new/etc/systemd/system/multi-user.target.wants/vpsforge-vpn.service" >/dev/null 2>&1 || true
  incus config set "$new" user.vpsforge.ip "$ip" >/dev/null 2>&1 || true
  incus config set "$new" user.vpsforge.num "$num" >/dev/null 2>&1 || true
}
