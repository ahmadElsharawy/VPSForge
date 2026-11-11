#!/bin/bash
# Main menu 12: Domains & Reverse Proxy.
proxy_menu() {
  local choice count caddy_state
  while true; do
    count=$(list_proxy_routes 2>/dev/null | wc -l)
    caddy_state=$(_proxy_caddy_status)

    clear
    echo "================================================================"
    echo "                DOMAINS & REVERSE PROXY (HTTPS)"
    echo "================================================================"
    echo "Caddy: $caddy_state   |   Domains: $count"
    echo "What it does: people open https://your-domain and see the app that runs inside one of your VPSs."
    echo "Example: https://app.mydomain.com  ->  VPS web1, port 3000   (the HTTPS certificate is automatic)"
    echo "----------------------------------------------------------------"
    echo "1) Add a domain       e.g. app.mydomain.com -> VPS web1, port 3000"
    echo "2) My domains        see them all, test that they work, remove one"
    echo "3) Cloudflare real visitor IP   optional: show visitors' real IPs when you use Cloudflare"
    echo "4) Sites from MY computer   no router access needed: tunnels through a VPS (add, list, start, stop)"
    echo "5) VPN                 your phone / PC through a VPS (WireGuard): its IP and speed, or a private network"
    echo "0) Back"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1) proxy_add_site_wizard ;;
      2) proxy_my_sites_menu ;;
      3) configure_cloudflare_realip ;;
      4) tunnel_menu ;;
      5) vpn_menu ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}
