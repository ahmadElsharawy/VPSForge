#!/bin/bash
# VPSForge v1.0.0 — Optimized Dashboard display.

list_vps() {
  local pool_path host_net_mbit
  pool_path=$(get_incus_pool_path)
  host_net_mbit=$(get_total_network_mbit 2>/dev/null || echo 10000)

  incus list --format json 2>/dev/null | python3 "$LIB_DIR/dashboard/dashboard_helper.py" \
    "$pool_path" "$host_net_mbit" "$AUTO_REFRESH" "$REFRESH_INTERVAL" "$PUBLIC_IP" "$VPSFORGE_VERSION" --only-table
}

dashboard() {
  local mode="${1:-full}"
  check_vps_traffic_quotas >/dev/null 2>&1 || true

  local pool_path host_net_mbit
  pool_path=$(get_incus_pool_path)
  host_net_mbit=$(get_total_network_mbit 2>/dev/null || echo 10000)

  # Generate table silently in memory
  local table_output
  table_output=$(incus list --format json 2>/dev/null | python3 "$LIB_DIR/dashboard/dashboard_helper.py" \
    "$pool_path" "$host_net_mbit" "$AUTO_REFRESH" "$REFRESH_INTERVAL" "$PUBLIC_IP" "$VPSFORGE_VERSION")

  # Classic vertical menu
  local menu="
1) Add
2) Delete
3) Start
4) Stop
5) Restart
6) Reinstall
7) Edit VPS
8) Details
9) Shell
10) Connection
11) Port Forward
12) Domains & Reverse Proxy
13) Snapshots & Backups
14) Settings
15) Exit"

  if [ "$mode" = "refresh" ]; then
    printf "\033[H%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  else
    clear
    printf "%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  fi
}
