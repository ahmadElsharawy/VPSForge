#!/bin/bash
# Returns configured monthly Rx (download) traffic limit in GB for a VPS container.
get_vps_traffic_rx_limit_gb() {
  local vps_name="$1" val
  val=$(incus config get "$vps_name" user.vpsforge.traffic.rx_limit_gb 2>/dev/null || true)
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ] && echo "$val" || echo 0
}
