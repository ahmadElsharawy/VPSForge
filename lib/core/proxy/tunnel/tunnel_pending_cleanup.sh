#!/bin/bash
# Remove the tunnel logins that were deleted while their VPS was stopped (noted in
# user.vpsforge.tunnel_cleanup) from every VPS that runs now. One `incus list` call;
# VPSs with nothing pending cost nothing. Run by the 5-minute cron and after a VPS starts.
tunnel_pending_cleanup() {
  local vps ports p
  while IFS='|' read -r vps ports; do
    [ -n "$vps" ] && [ -n "$ports" ] || continue
    for p in $ports; do
      [[ "$p" =~ ^[0-9]+$ ]] && tunnel_access_remove "$vps" "$p"
    done
    incus config unset "$vps" user.vpsforge.tunnel_cleanup >/dev/null 2>&1 || true
  done < <(incus list --format json 2>/dev/null | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    p = (c.get("config") or {}).get("user.vpsforge.tunnel_cleanup", "")
    if p and c.get("status") == "Running":
        print(c["name"] + "|" + p)
' 2>/dev/null)
  return 0
}
