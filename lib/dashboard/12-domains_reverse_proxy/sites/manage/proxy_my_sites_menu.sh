#!/bin/bash
# List every website on the server in one numbered table; pick one to test or remove it.
proxy_my_sites_menu() {
  local choice
  local -a routes=()

  if ! command -v caddy >/dev/null 2>&1; then
    echo "Caddy is not installed yet. Add your first domain (option 1) and it is installed for you."
    pause; return
  fi

  while true; do
    mapfile -t routes < <(list_proxy_routes)
    clear
    echo "================================================================"
    echo "                         MY DOMAINS"
    echo "================================================================"
    if [ "${#routes[@]}" -eq 0 ]; then
      echo "No domains yet. Go back and choose 1) Add a domain."
      pause; return
    fi

    _proxy_print_sites_table "${routes[@]}"
    echo
    read -r -p "Pick a number to test or remove it [0=Back]: " choice </dev/tty
    [ "${choice:-0}" = "0" ] && return
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#routes[@]}" ]; then
      proxy_site_actions "${routes[$((choice - 1))]}"
    else
      echo "Invalid number."; sleep 1
    fi
  done
}
