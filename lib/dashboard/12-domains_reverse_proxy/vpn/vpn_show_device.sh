#!/bin/bash
# Show how to connect one device: QR code (phone), the file (computer) or a short-lived link.
#   vpn_show_device <vps> <device>
vpn_show_device() {
  local vps="${1:?vps}" name="${2:?device}" c url
  while :; do
    echo
    echo "Connect '$name' (free apps: v2rayNG on Android, Streisand or V2Box on iPhone, v2rayN on Windows):"
    echo "1) Show QR code       phone: in the app tap + > Scan QR code"
    echo "2) Show the links     3 links (Reality, Hysteria2, TLS); copy one, then in the app: + > Import from clipboard"
    echo "3) Page with QR       a page (10 minutes) with the QR code, the links and the subscription link"
    echo "4) Subscription link  permanent: add it once in the app; Update shows the days and GB left (easiest)"
    echo "0) Done"
    read -r -p "Choice [0=Done, Enter=4]: " c </dev/tty
    c="${c:-4}"
    case "$c" in
      1) vpn_show_qr "$vps" "$name";;
      2) vpn_device_sub "$vps" "$name";;
      3) if vpn_share_link "$vps" "$name" 10 >/dev/null; then
           echo "Open this page (works for 10 minutes; keep it private, anyone with the QR code or link can use this VPN):"
           echo "   $VPN_SHARE_URL"
           echo "Subscription link (keeps working):"
           echo "   $VPN_SUB_URL"
         fi;;
      4) if vpn_sub_refresh "$vps" && url=$(vpn_sub_url "$vps" "$name"); then
           echo "Subscription link of '$name' (keep it private: anyone with it can use this VPN):"
           echo "   $url"
           echo "v2rayNG: menu > Subscription group setting > + > paste it as the URL > save, then Update subscription."
           echo "Hiddify / v2rayN: + > Add from clipboard. Removing the device makes the link stop."
         else
           echo "ERROR: the subscription link could not be made (is $vps running?)."
         fi;;
      0) return 0;;
      *) echo "Invalid choice.";;
    esac
  done
}
