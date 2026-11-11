#!/bin/bash
# Enforces the configured quota action (stop, warn, or throttle to 1Mbit) on a VPS container.
_apply_traffic_quota_action() {
  local name="$1" action="$2" status="$3"

  if [ "$action" = "stop" ]; then
    incus config set "$name" user.vpsforge.traffic.status "STOPPED" 2>/dev/null || true
    incus stop "$name" --force 2>/dev/null || true
  elif [ "$action" = "warn" ]; then
    incus config set "$name" user.vpsforge.traffic.status "EXCEEDED" 2>/dev/null || true
  else
    ensure_device_override "$name" eth0 >/dev/null 2>&1 || true
    # Remember the real speed once, so it can be restored when the quota resets.
    # Saved only before the first throttle ("unlimited" when there was no limit), so a real
    # limit of 1 Mbit is kept as 1 and is never confused with the throttle itself.
    if [ -z "$status" ] && [ -z "$(incus config get "$name" user.vpsforge.net_limit_orig 2>/dev/null)" ]; then
      local real_net
      real_net=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
      incus config set "$name" user.vpsforge.net_limit_orig "${real_net:-unlimited}" 2>/dev/null || true
    fi
    incus config device set "$name" eth0 limits.ingress "1Mbit" 2>/dev/null || true
    incus config device set "$name" eth0 limits.egress  "1Mbit" 2>/dev/null || true
    incus config set "$name" user.vpsforge.traffic.status "THROTTLED (1M)" 2>/dev/null || true
  fi
}
