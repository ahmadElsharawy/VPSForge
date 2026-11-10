#!/bin/bash
# Print the numbered VPS list used by every "select a VPS" prompt and fill AVAILABLE_VPS_LIST.
# One `incus list --format json` call gives every name, IP and state (no call per VPS).
list_available_vps() {
  local -a rows=()
  local idx=1 row n ip status
  AVAILABLE_VPS_LIST=()
  mapfile -t rows < <(incus list --format json 2>/dev/null | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    cfg = c.get("config") or {}
    ip = cfg.get("user.vpsforge.ip", "")
    if not ip:
        net = ((c.get("state") or {}).get("network") or {}).get("eth0") or {}
        ip = next((a.get("address", "") for a in net.get("addresses", []) if a.get("family") == "inet"), "")
    print("%s|%s|%s" % (c.get("name", ""), ip or "No-IP", (c.get("status") or "-").upper()))
' 2>/dev/null | sort -t'|' -k1,1V)
  for row in "${rows[@]}"; do
    [ -n "${row%%|*}" ] && AVAILABLE_VPS_LIST+=("${row%%|*}")
  done
  if [ "${#AVAILABLE_VPS_LIST[@]}" -eq 0 ]; then
    echo "No VPS containers found on this server."
    return 1
  fi

  echo "Available VPS Containers:"
  for row in "${rows[@]}"; do
    IFS='|' read -r n ip status <<< "$row"
    [ -n "$n" ] || continue
    printf "   %2d) %-15s (%-14s | %s)\n" "$idx" "$n" "$ip" "$status"
    idx=$((idx + 1))
  done
  echo "   A) All Containers"
  echo ""
  return 0
}
