#!/bin/bash
# Print the devices of the VPN on a VPS, one per line:
#   name|uuid|full|last_active_seconds_ago|used_bytes|limit_gb|expires_epoch|state
#   last_active empty = never used; limit 0 / expires 0 = unlimited; state on|off-data|off-time
# One `incus exec` for all devices (it also brings the usage up to date).
#   vpn_list_devices <vps>
vpn_list_devices() {
  local vps="${1:?vps}"
  is_vps_running "$vps" || return 0
  vpn_guest_check "$vps" collect >/dev/null 2>&1 || true
  incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c '
    [ -f "$D/devices.txt" ] || exit 0
    touch "$D/usage.txt"
    awk -F"|" -v now="$(date +%s)" -v us="$D/usage.txt" "
      BEGIN { while ((getline l < us) > 0) { split(l, u, \"|\"); used[u[1]] = u[2]; act[u[1]] = u[3] } }
      NF >= 2 {
        ago = \"\"
        if ((\$1 in act) && act[\$1] > 0) ago = now - act[\$1]
        print \$1 \"|\" \$2 \"|\" \$3 \"|\" ago \"|\" ((\$1 in used) ? used[\$1] : 0) \"|\" (\$6 == \"\" ? 0 : \$6) \"|\" (\$7 == \"\" ? 0 : \$7) \"|\" (\$8 == \"\" ? \"on\" : \$8)
      }
    " "$D/devices.txt"
  ' </dev/null 2>/dev/null
}
