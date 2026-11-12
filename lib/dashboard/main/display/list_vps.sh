#!/bin/bash
# Outputs the VPS table display without rendering the interactive menu.
list_vps() {
  local pool_path host_net_mbit
  [ -n "${POOL_PATH_CACHE:-}" ] || POOL_PATH_CACHE=$(get_incus_pool_path)
  pool_path="$POOL_PATH_CACHE"
  host_net_mbit=$(get_total_network_mbit 2>/dev/null || echo 10000)

  local draw=""; [ -t 1 ] && draw=dec   # VT100 line drawing only on a terminal
  incus list --format json 2>/dev/null | VPSFORGE_DRAW="$draw" python3 "$LIB_DIR/dashboard/dashboard_helper.py" \
    "$pool_path" "$host_net_mbit" "$AUTO_REFRESH" "$REFRESH_INTERVAL" "$PUBLIC_IP" "$VPSFORGE_VERSION" --only-table
}
