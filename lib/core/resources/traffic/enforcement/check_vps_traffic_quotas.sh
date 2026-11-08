#!/bin/bash
check_vps_traffic_quotas() {
  local name rx_lim_gb tx_lim_gb action status result orig_net
  while read -r name; do
    [ -n "$name" ] || continue
    rx_lim_gb=$(get_vps_traffic_rx_limit_gb "$name" 2>/dev/null || echo 0)
    tx_lim_gb=$(get_vps_traffic_tx_limit_gb "$name" 2>/dev/null || echo 0)

    if [ "$rx_lim_gb" -eq 0 ] && [ "$tx_lim_gb" -eq 0 ]; then
      status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)
      if [ -n "$status" ]; then
        reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      fi
      continue
    fi

    action=$(incus config get "$name" user.vpsforge.traffic.action 2>/dev/null || true)
    [ -n "$action" ] || action="throttle"

    result=$(incus query "/1.0/instances/$name/state" 2>/dev/null | python3 -c "
import sys, json

rx_lim_gb = int(sys.argv[1])
tx_lim_gb = int(sys.argv[2])

try:
    data = json.load(sys.stdin)
    eth0 = data.get('network', {}).get('eth0', {})
    counters = eth0.get('counters', {})
    rx_bytes = int(counters.get('bytes_received', 0))
    tx_bytes = int(counters.get('bytes_sent', 0))

    rx_exceeded = (rx_lim_gb > 0) and (rx_bytes >= rx_lim_gb * 1073741824)
    tx_exceeded = (tx_lim_gb > 0) and (tx_bytes >= tx_lim_gb * 1073741824)

    if rx_exceeded or tx_exceeded:
        print('EXCEEDED')
    else:
        print('OK')
except Exception:
    print('OK')
" "$rx_lim_gb" "$tx_lim_gb" 2>/dev/null || echo "OK")

    if [ "$result" = "EXCEEDED" ]; then
      if [ "$action" = "stop" ]; then
        incus config set "$name" user.vpsforge.traffic.status "STOPPED" 2>/dev/null || true
        incus stop "$name" --force 2>/dev/null || true
      elif [ "$action" = "warn" ]; then
        incus config set "$name" user.vpsforge.traffic.status "EXCEEDED" 2>/dev/null || true
      else
        ensure_device_override "$name" eth0 >/dev/null 2>&1 || true
        # Remember the real speed once, so it can be restored when the quota resets.
        if [ -z "$(incus config get "$name" user.vpsforge.net_limit_orig 2>/dev/null)" ]; then
          incus config set "$name" user.vpsforge.net_limit_orig "$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)" 2>/dev/null || true
        fi
        incus config device set "$name" eth0 limits.ingress "1Mbit" 2>/dev/null || true
        incus config device set "$name" eth0 limits.egress  "1Mbit" 2>/dev/null || true
        incus config set "$name" user.vpsforge.traffic.status "THROTTLED (1M)" 2>/dev/null || true
      fi
    else
      status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)
      if [ -n "$status" ]; then
        reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      fi
    fi
  done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
}
