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
    elif [ -n "$status" ] && [ "$action" != "stop" ]; then
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
    fi
  done < <(incus list --format json 2>/dev/null | python3 -c '
import sys, json

def num(value):
    try:
        return max(0, int(float(value or 0)))
    except (TypeError, ValueError):
        return 0

try:
    instances = json.load(sys.stdin)
except Exception:
    instances = []
for inst in instances:
    cfg = inst.get("config") or {}
    eth0 = ((inst.get("state") or {}).get("network") or {}).get("eth0") or {}
    counters = eth0.get("counters") or {}
    fields = [
        inst.get("name", ""),
        num(cfg.get("user.vpsforge.traffic.rx_limit_gb")),
        num(cfg.get("user.vpsforge.traffic.tx_limit_gb")),
        (cfg.get("user.vpsforge.traffic.status") or "").replace("|", " "),
        (cfg.get("user.vpsforge.traffic.action") or "").replace("|", " "),
        num(cfg.get("user.vpsforge.traffic.used_rx")),
        num(cfg.get("user.vpsforge.traffic.used_tx")),
        num(cfg.get("user.vpsforge.traffic.last_rx")),
        num(cfg.get("user.vpsforge.traffic.last_tx")),
        (cfg.get("user.vpsforge.traffic.period") or ""),
        num(counters.get("bytes_received")),
        num(counters.get("bytes_sent")),
        1 if inst.get("status") == "Running" else 0,
    ]
    print("|".join(str(f) for f in fields))
' 2>/dev/null || true)
}
