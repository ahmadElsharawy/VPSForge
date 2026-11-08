#!/bin/bash
get_vps_traffic_rx_limit_gb() {
  local val
  val=$(incus config get "$1" user.vpsforge.traffic.rx_limit_gb 2>/dev/null || true)
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ] && echo "$val" || echo 0
}
