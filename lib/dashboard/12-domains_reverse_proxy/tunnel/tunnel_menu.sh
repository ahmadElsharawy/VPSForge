#!/bin/bash
# Submenu of main menu 12 > 4: open a site that runs on YOUR computer, and manage those tunnels.
tunnel_menu() {
  local choice count
  while true; do
    count=$(tunnel_all_records 2>/dev/null | wc -l)
    clear
    echo "================================================================"
    echo "              SITES FROM MY COMPUTER (reverse tunnels)"
    echo "================================================================"
    echo "No router access needed: your computer connects OUT to a VPS, and the"
    echo "site on your computer is reachable from the internet. Tunnels: $count"
    echo "----------------------------------------------------------------"
    echo "1) Add a tunnel        e.g. my PC port 3000 -> https://test.mydomain.com"
    echo "2) My tunnels          list them, start / stop / edit / delete one or all"
    echo "0) Back"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1) tunnel_open_site_wizard ;;
      2) tunnel_my_tunnels_menu ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}
