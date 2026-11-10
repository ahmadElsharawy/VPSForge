#!/bin/bash
# Submenu of main menu 12 > 5: a VPN (Xray, VLESS + Reality) on one of your VPSs.
vpn_menu() {
  local choice answer
  while true; do
    clear
    echo "================================================================"
    echo "                 VPN (Xray, VLESS + Reality)"
    echo "================================================================"
    echo "Your phone / PC goes online through a VPS: its IP and its speed. It looks like"
    echo "normal HTTPS, so it is hard to block or slow down."
    echo "----------------------------------------------------------------"
    vpn_print_overview
    echo "----------------------------------------------------------------"
    echo "1) Create a VPN on a VPS"
    echo "2) Add a device              e.g. my-phone, with GB / days limits (or unlimited)"
    echo "3) Connect a device again    QR code / link / QR page"
    echo "4) Renew a device            new GB / days from today (usage starts again)"
    echo "5) Remove a device"
    echo "6) Remove a VPN              the VPS stays, only the VPN is removed"
    echo "0) Back"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=2]: " choice
    choice="${choice:-2}"
    case "$choice" in
      0) break ;;
      1) vpn_create_wizard ;;
      2) vpn_add_device_wizard ;;
      3) vpn_pick_vpn && vpn_pick_device "$VPN_VPS" && vpn_show_device "$VPN_VPS" "$VPN_DEVICE" || pause ;;
      4) if vpn_pick_vpn && vpn_pick_device "$VPN_VPS" "Device to renew"; then
           VW_VPS="$VPN_VPS"
           if vpn_wizard_step_device_limits; then
             vpn_set_device_limits "$VPN_VPS" "$VPN_DEVICE" "$VW_GB" "$VW_DAYS" && echo "Renewed: '$VPN_DEVICE' works again."
           fi
         fi
         pause ;;
      5) if vpn_pick_vpn && vpn_pick_device "$VPN_VPS" "Device to remove"; then
           read -r -p "Remove '$VPN_DEVICE' from the VPN of $VPN_VPS? [y/N]: " answer </dev/tty
           if [[ "${answer,,}" =~ ^y ]]; then vpn_remove_device "$VPN_VPS" "$VPN_DEVICE" && echo "Removed."; fi
         fi
         pause ;;
      6) if vpn_pick_vpn; then
           read -r -p "Remove the VPN from $VPN_VPS? All its devices stop working. [y/N]: " answer </dev/tty
           if [[ "${answer,,}" =~ ^y ]]; then vpn_remove "$VPN_VPS" && echo "VPN removed from $VPN_VPS."; fi
         fi
         pause ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}
