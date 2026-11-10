#!/bin/bash
# Remove one device from the VPN of a VPS: its link stops working at once.
#   vpn_remove_device <vps> <device_name>
vpn_remove_device() {
  local vps="${1:?vps}" name="${2:?name}"
  is_vps_running "$vps" || { echo "ERROR: $vps is not running."; return 1; }
  incus exec "$vps" --env D="$VPN_GUEST_DIR" --env NAME="$name" -- sh -c '
    cd "$D" || exit 1
    awk -F"|" -v n="$NAME" "\$1 != n" devices.txt > devices.txt.new && mv -f devices.txt.new devices.txt
    touch usage.txt
    awk -F"|" -v n="$NAME" "\$1 != n" usage.txt > usage.txt.new && mv -f usage.txt.new usage.txt
  ' </dev/null || return 1
  vpn_guest_apply "$vps"
}
