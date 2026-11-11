#!/bin/bash
# Enforce the monthly traffic quotas. One `incus list --format json` gives every VPS's limits and counters, so
# VPSs without a quota cost nothing. The counters of a VPS restart from zero when it restarts, so the usage is
# kept as a running total (used_rx/used_tx) that adds only what is new since the last check; it starts over each month.
check_vps_traffic_quotas() {
  local name rx_lim tx_lim status action used_rx used_tx last_rx last_tx period cur_rx cur_tx running
  local month delta
  month=$(date +%Y-%m)

  while IFS='|' read -r name rx_lim tx_lim status action used_rx used_tx last_rx last_tx period cur_rx cur_tx running; do
    [ -n "$name" ] || continue

    if [ "$rx_lim" -eq 0 ] && [ "$tx_lim" -eq 0 ]; then
      [ -n "$status" ] && { reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true; }
      continue
    fi
    # A stopped VPS has no counters: nothing is measured, nothing is reset.
    [ "$running" = "1" ] || continue
    [ -n "$action" ] || action="throttle"

    if [ "$period" != "$month" ]; then          # a new month: the quota starts over
      used_rx=0; used_tx=0
      [ -n "$status" ] && { reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true; status=""; }
    fi
    if [ "$cur_rx" -ge "$last_rx" ]; then delta=$((cur_rx - last_rx)); else delta=$cur_rx; fi
    used_rx=$((used_rx + delta))
    if [ "$cur_tx" -ge "$last_tx" ]; then delta=$((cur_tx - last_tx)); else delta=$cur_tx; fi
    used_tx=$((used_tx + delta))
    incus config set "$name" "user.vpsforge.traffic.used_rx=$used_rx" "user.vpsforge.traffic.used_tx=$used_tx" \
      "user.vpsforge.traffic.last_rx=$cur_rx" "user.vpsforge.traffic.last_tx=$cur_tx" "user.vpsforge.traffic.period=$month" 2>/dev/null || true

    if { [ "$rx_lim" -gt 0 ] && [ "$used_rx" -ge $((rx_lim * 1073741824)) ]; } || \
       { [ "$tx_lim" -gt 0 ] && [ "$used_tx" -ge $((tx_lim * 1073741824)) ]; }; then
      _apply_traffic_quota_action "$name" "$action" "$status"
    elif [ -n "$status" ] && [ "$action" != "stop" ]; then
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
    fi
  done < <(incus list --format json 2>/dev/null | _parse_vps_traffic_json)
}
