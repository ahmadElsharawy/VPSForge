#!/bin/bash
# Switch off VPN devices that passed their data limit or whose days are over (run by the
# 5-minute quota cron). Only VPSs that have a VPN are visited; one `incus exec` each.
vpn_check_limits() {
  local row vps out
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    vps="${row%%|*}"
    is_vps_running "$vps" || continue
    out=$(vpn_guest_check "$vps" 2>/dev/null) || continue
    [ -n "$out" ] && logger -t vpsforge "VPN $vps: $out" 2>/dev/null
  done < <(vpn_all_vps)
  return 0
}
