#!/bin/bash
# Add a device to the VPN of a VPS. All its internet then goes out through the VPS.
#   vpn_add_device <vps> <device_name> [data_limit_gb] [days]     (0 or empty = unlimited)
vpn_add_device() {
  local vps="${1:?vps}" name="${2:?name}" limit="${3:-0}" days="${4:-0}" expires=0 out
  is_valid_vpn_device_name "$name" || { echo "ERROR: invalid device name '$name' (letters, digits, - or _, max 32)."; return 1; }
  [[ "$limit" =~ ^[0-9]+$ ]] || { echo "ERROR: the data limit must be a whole number of GB (0 = unlimited)."; return 1; }
  [[ "$days" =~ ^[0-9]+$ ]] || { echo "ERROR: the days must be a whole number (0 = unlimited)."; return 1; }
  [ -n "$(vpn_get_port "$vps")" ] || { echo "ERROR: $vps has no VPN. Create it first."; return 1; }
  is_vps_running "$vps" || { echo "ERROR: $vps is not running."; return 1; }
  [ "$days" -gt 0 ] && expires=$(( $(date +%s) + days * 86400 ))
  out=$(incus exec "$vps" --env D="$VPN_GUEST_DIR" --env NAME="$name" --env LIMIT="$limit" --env EXPIRES="$expires" -- sh -c '
    set -e
    umask 077
    cd "$D"
    touch devices.txt usage.txt
    if awk -F"|" -v n="$NAME" "\$1 == n { f = 1 } END { exit !f }" devices.txt; then echo "EXISTS"; exit 3; fi
    id=$(/usr/local/bin/xray uuid)
    echo "$NAME|$id|full|||$LIMIT|$EXPIRES|on" >> devices.txt
    awk -F"|" -v n="$NAME" "\$1 != n" usage.txt > usage.txt.new; mv -f usage.txt.new usage.txt
  ' </dev/null 2>&1)
  case "$out" in
    *EXISTS*) echo "ERROR: a device named '$name' already exists on this VPN."; return 1;;
  esac
  [ -z "$out" ] || { echo "ERROR: could not add the device: $out"; return 1; }
  vpn_guest_apply "$vps" || { vpn_remove_device "$vps" "$name" >/dev/null 2>&1; echo "ERROR: Xray refused the new device."; return 1; }
}
