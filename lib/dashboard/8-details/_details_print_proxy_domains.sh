#!/bin/bash
# Gathers and displays configured reverse proxy domain routes for a VPS.
_details_print_proxy_domains() {
  local name="$1" pd
  local -a proxy_domains=()
  local caddy_file="/etc/caddy/vpsforge/${name}.caddy"
  if [ -f "$caddy_file" ]; then
    local line_domain
    while read -r line_domain; do
      if [[ "$line_domain" =~ ^([a-zA-Z0-9_.*-]+([,[:space:]]+[a-zA-Z0-9_.*-]+)*)[[:space:]]*\{ ]]; then
        proxy_domains+=("${BASH_REMATCH[1]}")
      fi
    done < "$caddy_file"
  fi

  echo "── Reverse Proxy & Domains (${#proxy_domains[@]}) ─────────────────────────"
  if [ "${#proxy_domains[@]}" -gt 0 ]; then
    for pd in "${proxy_domains[@]}"; do
      echo "  • https://$pd"
    done
  else
    echo "  None"
  fi
  echo
}
