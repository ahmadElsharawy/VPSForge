#!/bin/bash
# Show the QR code of one device's link in the terminal (scan it with v2rayNG / Streisand / v2Box).
#   vpn_show_qr <vps> <device_name>
vpn_show_qr() {
  local vps="${1:?vps}" name="${2:?name}" link
  link=$(vpn_device_link "$vps" "$name") || { echo "ERROR: device '$name' not found."; return 1; }
  printf '%s' "$link" | incus exec "$vps" -- qrencode -t ansiutf8
}
