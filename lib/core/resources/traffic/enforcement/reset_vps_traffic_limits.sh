#!/bin/bash
# Undo the traffic-quota throttle: give the VPS back the speed it had before (saved in
# user.vpsforge.net_limit_orig as a number of Mbit, or "unlimited").
#   reset_vps_traffic_limits <vps>
reset_vps_traffic_limits() {
  local name="$1" orig_net status
  status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)
  incus config unset "$name" user.vpsforge.traffic.status 2>/dev/null || true
  orig_net=$(incus config get "$name" user.vpsforge.net_limit_orig 2>/dev/null || true)
  incus config unset "$name" user.vpsforge.net_limit_orig 2>/dev/null || true
  if [ -z "$orig_net" ]; then
    # older VPSForge did not save it: only a throttled VPS is changed, and then to unlimited
    [[ "$status" == THROTTLED* ]] || return 0
    orig_net=unlimited
  fi
  if [[ "$orig_net" =~ ^[0-9]+$ ]]; then
    set_network_mode_for_vps "$name" limited "$orig_net" >/dev/null 2>&1 || true
  else
    set_network_mode_for_vps "$name" unlimited >/dev/null 2>&1 || true
  fi
}
