#!/bin/bash
# VPSForge v1.0.0 — Domains & Reverse Proxy menu.

proxy_menu() {
  while true; do
    clear
    echo "================================================================"
    echo "                  DOMAINS & REVERSE PROXY (CADDY)"
    echo "================================================================"
    echo "0) Back to Main Menu"
    echo "1) List All Linked Domains & Paths"
    echo "2) Manage Paths for a VPS (Add/Delete/Edit)"
    echo "3) Test & Diagnose Domain Routing / SSL / Backend"
    echo "4) Configure Cloudflare Real-IP Support"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1) list_all_domains; pause ;;
      2) manage_vps_proxy ;;
      3) interactive_diagnose_domain_proxy; pause ;;
      4) configure_cloudflare_realip ;;
      *) echo "Invalid option." ; sleep 1 ;;
    esac
  done
}
