#!/bin/bash
reset_vps_traffic_limits() {
  local name="$1" orig_net
  incus config unset "$name" user.vpsforge.traffic.status 2>/dev/null || true
  orig_net=$(incus config get "$name" user.vpsforge.net_limit_orig 2>/dev/null || true)
  incus config unset "$name" user.vpsforge.net_limit_orig 2>/dev/null || true
  [ -n "$orig_net" ] || orig_net=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  [ "$orig_net" = "1" ] && orig_net=""
  if [ -n "$orig_net" ]; then
    set_network_mode_for_vps "$name" limited "$orig_net" >/dev/null 2>&1 || true
  else
    set_network_mode_for_vps "$name" unlimited >/dev/null 2>&1 || true
  fi
}
