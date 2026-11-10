#!/bin/bash
# Give a device a new data limit and number of days, counted from now (a renewal):
# its usage starts again from zero and it is switched on again.
#   vpn_set_device_limits <vps> <device> <data_limit_gb> <days>    (0 = unlimited)
vpn_set_device_limits() {
  local vps="${1:?vps}" name="${2:?name}" limit="${3:?gb}" days="${4:?days}" expires=0
  [[ "$limit" =~ ^[0-9]+$ ]] && [[ "$days" =~ ^[0-9]+$ ]] || { echo "ERROR: use whole numbers (0 = unlimited)."; return 1; }
  [ "$days" -gt 0 ] && expires=$(( $(date +%s) + days * 86400 ))
  is_vps_running "$vps" || { echo "ERROR: $vps is not running."; return 1; }
  vpn_guest_check "$vps" >/dev/null 2>&1 || true   # count what was used so far first
  incus exec "$vps" --env D="$VPN_GUEST_DIR" --env NAME="$name" --env LIMIT="$limit" --env EXPIRES="$expires" -- sh -c '
    cd "$D" || exit 1
    awk -F"|" -v n="$NAME" "\$1 == n { f = 1 } END { exit !f }" devices.txt || exit 3
    awk -F"|" -v OFS="|" -v n="$NAME" -v l="$LIMIT" -v e="$EXPIRES" "\$1 == n { \$6 = l; \$7 = e; \$8 = \"on\" } { print }" devices.txt > devices.txt.new
    mv -f devices.txt.new devices.txt
    awk -F"|" -v OFS="|" -v n="$NAME" "\$1 == n { \$2 = 0 } { print }" usage.txt > usage.txt.new
    mv -f usage.txt.new usage.txt
  ' </dev/null || { echo "ERROR: device '$name' not found."; return 1; }
  vpn_guest_apply "$vps"
}
