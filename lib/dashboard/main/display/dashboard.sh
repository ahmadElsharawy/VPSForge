#!/bin/bash
dashboard() {
  local mode="${1:-full}"
  # Traffic quotas are enforced by the cron job (every 5 min), not on every redraw.

  local pool_path host_net_mbit
  # The storage pool path never changes while running: resolve it once.
  [ -n "${POOL_PATH_CACHE:-}" ] || POOL_PATH_CACHE=$(get_incus_pool_path)
  pool_path="$POOL_PATH_CACHE"
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
15) Exit
16) Clone a VPS (instant copy to experiment on)"

  if [ "$mode" = "refresh" ]; then
    printf "\033[H%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  else
    clear
    printf "%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  fi
}
