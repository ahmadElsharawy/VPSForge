#!/bin/bash
# Displays the main VPSForge dashboard table and numbered action menu.
dashboard() {
  local mode="${1:-full}" pool_path host_net_mbit table_output

  # The storage pool path never changes while running: resolve it once.
  [ -n "${POOL_PATH_CACHE:-}" ] || POOL_PATH_CACHE=$(get_incus_pool_path)
  pool_path="$POOL_PATH_CACHE"
  host_net_mbit=$(get_total_network_mbit 2>/dev/null || echo 10000)

  # Generate table silently in memory
  # VT100 line drawing only when the table goes to a terminal (not to a file or a pipe).
  local draw=""; [ -t 1 ] && draw=dec
  table_output=$(incus list --format json 2>/dev/null | VPSFORGE_DRAW="$draw" python3 "$LIB_DIR/dashboard/dashboard_helper.py" \
    "$pool_path" "$host_net_mbit" "$AUTO_REFRESH" "$REFRESH_INTERVAL" "$PUBLIC_IP" "$VPSFORGE_VERSION")

  _dashboard_render "$table_output" "$mode"
}
