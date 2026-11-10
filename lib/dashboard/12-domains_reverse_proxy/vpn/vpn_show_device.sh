#!/bin/bash
# Show how to connect one device: QR code (phone), the file (computer) or a short-lived link.
#   vpn_show_device <vps> <device>
vpn_show_device() {
  local vps="${1:?vps}" name="${2:?device}" c
  while :; do
    echo
    echo "Connect '$name' (free apps: v2rayNG on Android, Streisand or V2Box on iPhone, v2rayN on Windows):"
    echo "1) Show QR code       phone: in the app tap + > Scan QR code"
    echo "2) Show the link      copy it, then in the app: + > Import from clipboard"
    echo "3) Link (easiest)     a page with the QR code + download button, works for 10 minutes"
    echo "0) Done"
    read -r -p "Choice [0=Done, Enter=3]: " c </dev/tty
    c="${c:-3}"
    case "$c" in
      1) vpn_show_qr "$vps" "$name";;
      2) vpn_device_link "$vps" "$name"; echo;;
      3) if vpn_share_link "$vps" "$name" 10 >/dev/null; then
           echo "Open this page (works for 10 minutes; keep it private, anyone with the QR code or link can use this VPN):"
           echo "   $VPN_SHARE_URL"
         fi;;
      0) return 0;;
      *) echo "Invalid choice.";;
    esac
  done
}
