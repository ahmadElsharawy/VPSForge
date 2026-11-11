#!/bin/bash
# Formats compact network I/O display (Rx/Tx) and traffic status for a VPS container.
get_vps_network_io_display() {
  local vps_name="$1" rx_lim tx_lim t_status
  rx_lim=$(get_vps_traffic_rx_limit_gb "$vps_name" 2>/dev/null || echo 0)
  tx_lim=$(get_vps_traffic_tx_limit_gb "$vps_name" 2>/dev/null || echo 0)
  t_status=$(incus config get "$vps_name" user.vpsforge.traffic.status 2>/dev/null || true)

  incus query "/1.0/instances/$vps_name/state" 2>/dev/null | \
    _format_instance_network_io "$rx_lim" "$tx_lim" "$t_status"
}
